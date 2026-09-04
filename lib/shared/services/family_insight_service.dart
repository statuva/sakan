import 'dart:async';

import 'package:intl/intl.dart';

import '../models/availability_block.dart';
import '../models/care_action.dart';
import '../models/current_family_context.dart';
import '../models/family_insight_report.dart';
import '../models/family_insight_snapshot.dart';
import '../models/family_memory.dart';
import '../models/family_moment.dart';
import '../models/member.dart';
import '../models/model_enums.dart';
import '../models/moment_instance.dart';
import '../models/rhythm_record.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/care_action_repository.dart';
import '../repositories/memory_repository.dart';
import '../repositories/moment_instance_repository.dart';
import '../repositories/schedule_repository.dart';
import 'current_family_service.dart';
import 'moment_action_evaluator.dart';

class FamilyInsightService {
  const FamilyInsightService({
    required CurrentFamilyService currentFamilyService,
    required CalendarRepository calendarRepository,
    required MomentInstanceRepository momentInstanceRepository,
    required ScheduleRepository scheduleRepository,
    required CareActionRepository careActionRepository,
    required MemoryRepository memoryRepository,
  }) : _currentFamilyService = currentFamilyService,
       _calendarRepository = calendarRepository,
       _momentInstanceRepository = momentInstanceRepository,
       _scheduleRepository = scheduleRepository,
       _careActionRepository = careActionRepository,
       _memoryRepository = memoryRepository;

  final CurrentFamilyService _currentFamilyService;
  final CalendarRepository _calendarRepository;
  final MomentInstanceRepository _momentInstanceRepository;
  final ScheduleRepository _scheduleRepository;
  final CareActionRepository _careActionRepository;
  final MemoryRepository _memoryRepository;

  Future<FamilyInsightSnapshot> loadSnapshot() async {
    final context = await _currentFamilyService.load();

    final results = await Future.wait<Object>([
      _currentFamilyService.watchFamilyMembers(context.familyId).first,
      _calendarRepository.watchMoments(familyId: context.familyId).first,
      _momentInstanceRepository
          .watchInstances(familyId: context.familyId)
          .first,
      _calendarRepository.watchRhythms(familyId: context.familyId).first,
      _scheduleRepository
          .watchFamilyAvailability(familyId: context.familyId)
          .first,
      _remindersStreamFor(context).first,
      _memoryRepository.watchMemories(familyId: context.familyId).first,
    ]);

    return FamilyInsightSnapshot(
      familyId: context.familyId,
      currentUserId: context.userId,
      generatedAt: DateTime.now().toUtc(),
      members: results[0] as List<Member>,
      moments: results[1] as List<FamilyMoment>,
      instances: results[2] as List<MomentInstance>,
      rhythms: results[3] as List<RhythmRecord>,
      availability: results[4] as List<AvailabilityBlock>,
      reminders: results[5] as List<CareAction>,
      memories: results[6] as List<FamilyMemory>,
    );
  }

  Future<FamilyInsightReport> loadReport() async {
    final snapshot = await loadSnapshot();
    return analyze(snapshot);
  }

  /// Emits whenever Firestore data changes and once per minute so
  /// time-based facts stay current.
  Stream<FamilyInsightReport> watchReport() {
    late StreamController<FamilyInsightReport> controller;

    final subscriptions = <StreamSubscription<dynamic>>[];
    Timer? refreshTimer;
    var cancelled = false;

    Future<void> start() async {
      try {
        final context = await _currentFamilyService.load();

        if (cancelled) {
          return;
        }

        List<Member>? members;
        List<FamilyMoment>? moments;
        List<MomentInstance>? instances;
        List<RhythmRecord>? rhythms;
        List<AvailabilityBlock>? availability;
        List<CareAction>? reminders;
        List<FamilyMemory>? memories;

        void emitIfReady() {
          if (cancelled || controller.isClosed) {
            return;
          }

          if (members == null ||
              moments == null ||
              instances == null ||
              rhythms == null ||
              availability == null ||
              reminders == null ||
              memories == null) {
            return;
          }

          controller.add(
            analyze(
              FamilyInsightSnapshot(
                familyId: context.familyId,
                currentUserId: context.userId,
                generatedAt: DateTime.now().toUtc(),
                members: members!,
                moments: moments!,
                instances: instances!,
                rhythms: rhythms!,
                availability: availability!,
                reminders: reminders!,
                memories: memories!,
              ),
            ),
          );
        }

        void forwardError(Object error, StackTrace stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        }

        subscriptions.add(
          _currentFamilyService.watchFamilyMembers(context.familyId).listen((
            value,
          ) {
            members = value;
            emitIfReady();
          }, onError: forwardError),
        );

        subscriptions.add(
          _calendarRepository.watchMoments(familyId: context.familyId).listen((
            value,
          ) {
            moments = value;
            emitIfReady();
          }, onError: forwardError),
        );

        subscriptions.add(
          _momentInstanceRepository
              .watchInstances(familyId: context.familyId)
              .listen((value) {
                instances = value;
                emitIfReady();
              }, onError: forwardError),
        );

        subscriptions.add(
          _calendarRepository.watchRhythms(familyId: context.familyId).listen((
            value,
          ) {
            rhythms = value;
            emitIfReady();
          }, onError: forwardError),
        );

        subscriptions.add(
          _scheduleRepository
              .watchFamilyAvailability(familyId: context.familyId)
              .listen((value) {
                availability = value;
                emitIfReady();
              }, onError: forwardError),
        );

        subscriptions.add(
          _remindersStreamFor(context).listen((value) {
            reminders = value;
            emitIfReady();
          }, onError: forwardError),
        );

        subscriptions.add(
          _memoryRepository.watchMemories(familyId: context.familyId).listen((
            value,
          ) {
            memories = value;
            emitIfReady();
          }, onError: forwardError),
        );

        refreshTimer = Timer.periodic(
          const Duration(minutes: 1),
          (_) => emitIfReady(),
        );
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    Future<void> cancel() async {
      cancelled = true;
      refreshTimer?.cancel();

      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    }

    controller = StreamController<FamilyInsightReport>(
      onListen: start,
      onCancel: cancel,
    );

    return controller.stream;
  }

  Stream<List<CareAction>> _remindersStreamFor(CurrentFamilyContext context) {
    if (context.isAdult) {
      return _careActionRepository.watchCareActions(context.familyId);
    }

    return _careActionRepository.watchAssignedCareActions(
      familyId: context.familyId,
      memberId: context.userId,
    );
  }

  FamilyInsightReport analyze(FamilyInsightSnapshot snapshot) {
    return analyzeSnapshot(snapshot);
  }

  static FamilyInsightReport analyzeSnapshot(FamilyInsightSnapshot snapshot) {
    final bestSharedWindow = findBestSharedWindow(snapshot);
    final insights = _buildInsights(snapshot, bestSharedWindow);

    return FamilyInsightReport(
      snapshot: snapshot,
      overallState: _overallState(snapshot),
      overallConfidence: _overallConfidence(snapshot),
      primaryInsight: insights.isEmpty ? null : insights.first,
      secondaryInsights: insights.length <= 1
          ? const <FamilyInsightItem>[]
          : insights.skip(1).toList(),
      bestSharedWindow: bestSharedWindow,
    );
  }

  static FamilyAvailabilityWindow? findBestSharedWindow(
    FamilyInsightSnapshot snapshot, {
    int daysToSearch = 14,
    int dayStartMinutes = 16 * 60,
    int dayEndMinutes = 20 * 60,
    int durationMinutes = 120,
  }) {
    final activeMembers = snapshot.activeMembers;

    if (activeMembers.isEmpty || snapshot.availability.isEmpty) {
      return null;
    }

    final activeMemberIds = activeMembers.map((member) => member.id).toSet();

    final activeAvailability = snapshot.availability
        .where((block) => !block.isExpiredAt(snapshot.generatedAt))
        .toList(growable: false);

    final membersWithScheduleData = activeAvailability
        .map((block) => block.memberId)
        .toSet()
        .intersection(activeMemberIds);

    final reference = snapshot.generatedAt.toLocal();
    final today = _dateOnly(reference);

    FamilyAvailabilityWindow? best;

    for (var dayOffset = 0; dayOffset < daysToSearch; dayOffset++) {
      final date = today.add(Duration(days: dayOffset));

      for (
        var start = dayStartMinutes;
        start + durationMinutes <= dayEndMinutes;
        start += 30
      ) {
        final end = start + durationMinutes;

        final candidateStart = DateTime(
          date.year,
          date.month,
          date.day,
          start ~/ 60,
          start % 60,
        );

        if (!candidateStart.isAfter(reference)) {
          continue;
        }

        final busyMemberIds = activeAvailability
            .where((block) {
              return block.occursOn(date) &&
                  start < block.endMinutes &&
                  end > block.startMinutes;
            })
            .map((block) => block.memberId)
            .toSet()
            .intersection(activeMemberIds);

        final availableCount = activeMembers.length - busyMemberIds.length;

        final candidate = FamilyAvailabilityWindow(
          date: date,
          startMinutes: start,
          endMinutes: end,
          availableMemberCount: availableCount,
          totalMemberCount: activeMembers.length,
          membersWithScheduleDataCount: membersWithScheduleData.length,
        );

        if (best == null ||
            candidate.availableMemberCount > best.availableMemberCount) {
          best = candidate;
        }

        if (candidate.everyoneAvailable && candidate.hasFullScheduleCoverage) {
          return candidate;
        }
      }
    }

    return best;
  }

  static List<FamilyInsightItem> _buildInsights(
    FamilyInsightSnapshot snapshot,
    FamilyAvailabilityWindow? bestSharedWindow,
  ) {
    final insights = <FamilyInsightItem>[];
    final seenKeys = <String>{};

    void addInsight(FamilyInsightItem insight) {
      final key = insight.relatedInstanceId != null
          ? 'instance:${insight.relatedInstanceId}'
          : insight.relatedReminderId != null
          ? 'reminder:${insight.relatedReminderId}'
          : insight.relatedMomentId != null
          ? 'moment:${insight.relatedMomentId}'
          : insight.id;

      if (seenKeys.add(key)) {
        insights.add(insight);
      }
    }

    final active = snapshot.activeInstance;

    if (active != null) {
      addInsight(_activeMomentInsight(active));
    }

    final candidates = snapshot.actionablePlannedInstances;

    for (final instance in candidates) {
      final existingReminder = _reminderForOccurrence(snapshot, instance);
      final currentRole = snapshot.currentMember?.role;

      final canStart =
          snapshot.currentUserCanManageSharedMoments &&
          (currentRole == FamilyRole.admin ||
              snapshot.currentUserIsExpected(instance));

      final canCreateReminder =
          (currentRole == FamilyRole.admin ||
              currentRole == FamilyRole.adult) &&
          snapshot.currentUserIsExpected(instance);

      final decision = MomentActionEvaluator.evaluate(
        instance: instance,
        now: snapshot.generatedAt,
        activeInstance: active,
        canStartSharedMoment: canStart,
        canReviewSharedMoment: snapshot.currentUserCanManageSharedMoments,
        canCreatePersonalReminder: canCreateReminder,
        existingReminder: existingReminder,
      );

      if (existingReminder?.isFinished == true &&
          decision.actionType == FamilyInsightActionType.openReminders) {
        continue;
      }

      switch (decision.actionType) {
        case FamilyInsightActionType.startMomentNow:
          addInsight(_startNowInsight(snapshot, instance));
          break;
        case FamilyInsightActionType.addReminder:
        case FamilyInsightActionType.openReminders:
          addInsight(
            _sameDayReminderInsight(instance: instance, decision: decision),
          );
          break;
        case FamilyInsightActionType.reviewToday:
          addInsight(_reviewNeededInsight(instance, snapshot.generatedAt));
          break;
        default:
          break;
      }
    }

    for (final reminder in snapshot.overdueCurrentUserReminders.take(2)) {
      addInsight(_overdueReminderInsight(reminder));
    }

    for (final instance in snapshot.upcomingInstances) {
      final category = instance.categorySnapshot;
      final days = _daysUntil(snapshot.generatedAt, instance.scheduledStartAt);

      final isPreparation =
          category == MomentCategory.milestone ||
          category == MomentCategory.care ||
          category == MomentCategory.responsibility;

      if (isPreparation && days >= 0 && days <= 14) {
        final reminder = _reminderForOccurrence(snapshot, instance);
        if (reminder?.isFinished != true) {
          addInsight(_preparationInsight(snapshot, instance));
        }
      }
    }

    for (final rhythm in snapshot.driftingRhythms) {
      final moment = snapshot.momentById(rhythm.momentId);

      if (moment != null && !moment.isArchived) {
        addInsight(
          _driftingRhythmInsight(snapshot, moment, rhythm, bestSharedWindow),
        );
      }
    }

    if (insights.isEmpty && snapshot.upcomingInstances.isNotEmpty) {
      addInsight(
        _informationalUpcomingInsight(snapshot.upcomingInstances.first),
      );
    }

    insights.sort((first, second) {
      final priorityResult = first.priority.compareTo(second.priority);

      if (priorityResult != 0) {
        return priorityResult;
      }

      final importanceResult = _importanceForInsight(
        snapshot,
        second,
      ).compareTo(_importanceForInsight(snapshot, first));

      if (importanceResult != 0) {
        return importanceResult;
      }

      final firstTime = first.recommendedActionAt ?? DateTime(9999);
      final secondTime = second.recommendedActionAt ?? DateTime(9999);
      return firstTime.compareTo(secondTime);
    });

    return insights;
  }

  static int _importanceForInsight(
    FamilyInsightSnapshot snapshot,
    FamilyInsightItem insight,
  ) {
    final instanceId = insight.relatedInstanceId;

    if (instanceId != null) {
      final instance = snapshot.instanceById(instanceId);

      if (instance != null) {
        return instance.importanceLevelSnapshot;
      }
    }

    final momentId = insight.relatedMomentId;
    return momentId == null
        ? 0
        : snapshot.momentById(momentId)?.importanceLevel ?? 0;
  }

  static FamilyInsightItem _activeMomentInsight(MomentInstance instance) {
    final participantCount = instance.allRecordedParticipantIds.length;

    return FamilyInsightItem(
      id: 'active:${instance.id}',
      kind: FamilyInsightKind.activeMoment,
      actionType: FamilyInsightActionType.joinActiveMoment,
      priority: 0,
      headline: '${instance.titleSnapshot} is happening now',
      summary:
          'A family Moment is live. Open it to check in, see who is here, and follow the shared timer.',
      reasons: <String>[
        'The session has an active start time.',
        '$participantCount ${participantCount == 1 ? 'member has' : 'members have'} recorded participation so far.',
      ],
      suggestedActions: const <String>[
        'Open the live session.',
        'Check in from this phone if you are participating.',
      ],
      confidence: ConfidenceLevel.high,
      relatedMomentId: instance.momentId,
      relatedInstanceId: instance.id,
      recommendedActionAt: instance.actualStartAt ?? instance.scheduledStartAt,
    );
  }

  static FamilyInsightItem _startNowInsight(
    FamilyInsightSnapshot snapshot,
    MomentInstance instance,
  ) {
    return FamilyInsightItem(
      id: 'start:${instance.id}',
      kind: FamilyInsightKind.sharedMomentOpportunity,
      actionType: FamilyInsightActionType.startMomentNow,
      priority: 5,
      headline: '${instance.titleSnapshot} can start now',
      summary:
          'Its planned time has arrived and no other family session is active.',
      reasons: <String>[
        'The occurrence is inside its planned start window.',
        '${instance.expectedParticipantIds.length} family members are expected.',
        if (snapshot.momentById(instance.momentId)?.type ==
            MomentType.recurring)
          'It contributes to a recurring family rhythm.',
      ],
      suggestedActions: const <String>[
        'Start the shared timer.',
        'Let each participating member check in.',
        'End the Moment when the family is finished.',
      ],
      confidence: ConfidenceLevel.high,
      relatedMomentId: instance.momentId,
      relatedInstanceId: instance.id,
      recommendedActionAt: snapshot.generatedAt,
    );
  }

  static FamilyInsightItem _sameDayReminderInsight({
    required MomentInstance instance,
    required MomentActionDecision decision,
  }) {
    final hasReminder =
        decision.actionType == FamilyInsightActionType.openReminders;

    return FamilyInsightItem(
      id: 'today:${instance.id}',
      kind: FamilyInsightKind.upcomingMoment,
      actionType: decision.actionType,
      priority: 10,
      headline: '${instance.titleSnapshot} is later today',
      summary:
          'The Moment is planned for ${DateFormat('h:mm a').format(instance.scheduledStartAt.toLocal())}.',
      reasons: <String>[
        'The occurrence is scheduled today.',
        if (hasReminder)
          'A personal reminder is already linked to this occurrence.'
        else
          'No personal reminder is linked to this occurrence yet.',
      ],
      suggestedActions: hasReminder
          ? const <String>['Open your existing reminder.']
          : const <String>[
              'Add a reminder before the planned start time.',
              'Start the session when the planned time arrives.',
            ],
      confidence: ConfidenceLevel.high,
      relatedMomentId: instance.momentId,
      relatedInstanceId: instance.id,
      relatedReminderId: decision.relatedReminderId,
      recommendedActionAt: decision.recommendedActionAt,
    );
  }

  static FamilyInsightItem _reviewNeededInsight(
    MomentInstance instance,
    DateTime generatedAt,
  ) {
    return FamilyInsightItem(
      id: 'review:${instance.id}',
      kind: FamilyInsightKind.reviewNeeded,
      actionType: FamilyInsightActionType.reviewToday,
      priority: 15,
      headline: 'Did ${instance.titleSnapshot} happen?',
      summary:
          'Its planned time has passed, but Sakan has no completed, missed, or cancelled outcome yet.',
      reasons: const <String>[
        'The scheduled end time has passed.',
        'No live-session completion was recorded.',
        'A quick review keeps the rhythm history accurate.',
      ],
      suggestedActions: const <String>[
        'Record that it happened.',
        'Mark it missed.',
        'Reschedule it if the family still plans to do it.',
      ],
      confidence: ConfidenceLevel.high,
      relatedMomentId: instance.momentId,
      relatedInstanceId: instance.id,
      recommendedActionAt: generatedAt,
    );
  }

  static FamilyInsightItem _overdueReminderInsight(CareAction reminder) {
    return FamilyInsightItem(
      id: 'overdue:${reminder.id}',
      kind: FamilyInsightKind.overdueReminder,
      actionType: FamilyInsightActionType.openReminders,
      priority: 20,
      headline: '${reminder.title} is overdue',
      summary:
          'This personal reminder has passed its due time and still needs a decision.',
      reasons: <String>[
        'The reminder is still pending.',
        'Its due time has already passed.',
        if (reminder.reason.trim().isNotEmpty)
          'A note is attached to the reminder.',
      ],
      suggestedActions: const <String>[
        'Complete it if it is done.',
        'Choose a new due time if it is still needed.',
        'Delete it if it is no longer relevant.',
      ],
      confidence: ConfidenceLevel.high,
      relatedMomentId: reminder.momentId,
      relatedInstanceId: reminder.instanceId,
      relatedReminderId: reminder.id,
      recommendedActionAt: reminder.dueAt,
    );
  }

  static FamilyInsightItem _preparationInsight(
    FamilyInsightSnapshot snapshot,
    MomentInstance instance,
  ) {
    final existing = _reminderForOccurrence(snapshot, instance);
    final category = instance.categorySnapshot;
    final days = _daysUntil(snapshot.generatedAt, instance.scheduledStartAt);
    final reminderChoice = existing == null
        ? _findPersonalReminderTime(snapshot, instance)
        : null;

    return FamilyInsightItem(
      id: 'prepare:${instance.id}',
      kind: switch (category) {
        MomentCategory.milestone => FamilyInsightKind.upcomingMilestone,
        MomentCategory.care ||
        MomentCategory.responsibility => FamilyInsightKind.carePreparation,
        _ => FamilyInsightKind.upcomingMoment,
      },
      actionType: existing == null
          ? FamilyInsightActionType.addReminder
          : FamilyInsightActionType.openReminders,
      priority: 30,
      headline: _upcomingHeadline(instance.titleSnapshot, days),
      summary: _instanceSummary(category),
      reasons: <String>[
        _daysReason(days),
        'The Moment is marked ${instance.importanceLevelSnapshot}/5 importance.',
        if (existing == null)
          'No active personal preparation reminder is linked to this occurrence.'
        else
          'A personal reminder is already linked to this occurrence.',
        if (reminderChoice?.usesAvailability == true)
          'The suggested reminder time avoids your recorded busy periods.',
      ],
      suggestedActions: _actionsForCategory(category),
      confidence: ConfidenceLevel.high,
      relatedMomentId: instance.momentId,
      relatedInstanceId: instance.id,
      relatedReminderId: existing?.id,
      recommendedActionAt: existing?.dueAt ?? reminderChoice?.dateTime,
      recommendedActionUsesAvailability:
          reminderChoice?.usesAvailability ?? false,
    );
  }

  static CareAction? _reminderForOccurrence(
    FamilyInsightSnapshot snapshot,
    MomentInstance instance,
  ) {
    CareAction? finishedFallback;
    for (final reminder in snapshot.currentUserReminders) {
      final exact = reminder.instanceId == instance.id;
      final legacy = reminder.instanceId == null &&
          reminder.momentId == instance.momentId;
      if (!exact && !legacy) continue;
      if (!reminder.isFinished) return reminder;
      finishedFallback ??= reminder;
    }
    return finishedFallback;
  }

  static FamilyInsightItem _driftingRhythmInsight(
    FamilyInsightSnapshot snapshot,
    FamilyMoment moment,
    RhythmRecord rhythm,
    FamilyAvailabilityWindow? bestSharedWindow,
  ) {
    final openInstance = snapshot.openInstanceForMoment(moment.id);
    FamilyInsightActionType actionType = FamilyInsightActionType.scheduleMoment;
    DateTime? actionAt = bestSharedWindow?.startAt;
    String? relatedInstanceId = openInstance?.id;

    if (openInstance != null) {
      final role = snapshot.currentMember?.role;
      final canStart =
          snapshot.currentUserCanManageSharedMoments &&
          (role == FamilyRole.admin ||
              snapshot.currentUserIsExpected(openInstance));

      final decision = MomentActionEvaluator.evaluate(
        instance: openInstance,
        now: snapshot.generatedAt,
        activeInstance: snapshot.activeInstance,
        canStartSharedMoment: canStart,
        canReviewSharedMoment: snapshot.currentUserCanManageSharedMoments,
        canCreatePersonalReminder: false,
      );

      if (decision.actionType == FamilyInsightActionType.startMomentNow) {
        actionType = FamilyInsightActionType.startMomentNow;
        actionAt = snapshot.generatedAt;
      } else {
        actionAt = openInstance.scheduledStartAt;
      }
    }

    return FamilyInsightItem(
      id: 'rhythm:${rhythm.id}',
      kind: FamilyInsightKind.driftingRhythm,
      actionType: actionType,
      priority: 40,
      headline: '${moment.title} is drifting',
      summary: moment.isDayFlexible && openInstance == null
          ? 'This recurring Moment needs an exact date before the family can do it again.'
          : 'This recurring family Moment has moved beyond its usual confirmed pattern and may need a realistic next occurrence.',
      reasons: <String>[
        '${rhythm.currentGapDays} days have passed since its last confirmed occurrence.',
        'Its expected interval is ${rhythm.expectedIntervalDays} days.',
        'The current recorded rhythm status is Drifting.',
        if (bestSharedWindow != null)
          '${bestSharedWindow.availableMemberCount} of ${bestSharedWindow.totalMemberCount} active members have no recorded conflict in the best upcoming window.',
      ],
      suggestedActions: const <String>[
        'Review the next planned occurrence.',
        'Choose a realistic date and time.',
        'Confirm the expected participants.',
      ],
      confidence: rhythm.confidence,
      relatedMomentId: moment.id,
      relatedInstanceId: relatedInstanceId,
      recommendedActionAt: actionAt,
      recommendedActionUsesAvailability:
          actionType == FamilyInsightActionType.scheduleMoment &&
          bestSharedWindow != null,
    );
  }

  static FamilyInsightItem _informationalUpcomingInsight(
    MomentInstance instance,
  ) {
    return FamilyInsightItem(
      id: 'upcoming:${instance.id}',
      kind: FamilyInsightKind.upcomingMoment,
      actionType: FamilyInsightActionType.none,
      priority: 60,
      headline: '${instance.titleSnapshot} is coming up',
      summary:
          'It is already scheduled. Sakan will surface a reminder or start action when the time is closer.',
      reasons: <String>[
        'The occurrence is planned for ${DateFormat('EEE, d MMM · h:mm a').format(instance.scheduledStartAt.toLocal())}.',
      ],
      suggestedActions: const <String>[],
      confidence: ConfidenceLevel.high,
      relatedMomentId: instance.momentId,
      relatedInstanceId: instance.id,
      recommendedActionAt: instance.scheduledStartAt,
    );
  }

  static _ActionTimeChoice? _findPersonalReminderTime(
    FamilyInsightSnapshot snapshot,
    MomentInstance instance,
  ) {
    final reference = snapshot.generatedAt.toLocal();
    final event = instance.scheduledStartAt.toLocal();
    final eventDate = _dateOnly(event);
    final today = _dateOnly(reference);

    if (eventDate == today) {
      var candidate = event.subtract(const Duration(minutes: 30));
      final minimum = reference.add(const Duration(minutes: 1));

      if (candidate.isBefore(minimum)) {
        candidate = minimum;
      }

      return candidate.isAfter(event)
          ? null
          : _ActionTimeChoice(dateTime: candidate, usesAvailability: false);
    }

    if (!eventDate.isAfter(today)) {
      return null;
    }

    final personalBlocks = snapshot.availability
        .where(
          (block) =>
              block.memberId == snapshot.currentUserId &&
              !block.isExpiredAt(snapshot.generatedAt),
        )
        .toList();

    final lastPossibleDate = eventDate.subtract(const Duration(days: 1));

    for (var offset = 0; offset <= 7; offset++) {
      final candidateDate = today.add(Duration(days: offset));

      if (candidateDate.isAfter(lastPossibleDate)) {
        break;
      }

      for (final startMinutes in const <int>[
        16 * 60,
        17 * 60,
        18 * 60,
        19 * 60,
      ]) {
        final candidate = DateTime(
          candidateDate.year,
          candidateDate.month,
          candidateDate.day,
          startMinutes ~/ 60,
          startMinutes % 60,
        );

        if (!candidate.isAfter(reference)) {
          continue;
        }

        final endMinutes = startMinutes + 60;

        final overlaps = personalBlocks.any((block) {
          return block.occursOn(candidateDate) &&
              startMinutes < block.endMinutes &&
              endMinutes > block.startMinutes;
        });

        if (!overlaps) {
          return _ActionTimeChoice(
            dateTime: candidate,
            usesAvailability: personalBlocks.isNotEmpty,
          );
        }
      }
    }

    final fallback = event.subtract(const Duration(days: 1));

    if (!fallback.isAfter(reference)) {
      return null;
    }

    return _ActionTimeChoice(dateTime: fallback, usesAvailability: false);
  }

  static FamilyOverallState _overallState(FamilyInsightSnapshot snapshot) {
    if (snapshot.rhythms.isEmpty) {
      return FamilyOverallState.stillLearning;
    }

    if (snapshot.rhythms.any(
      (rhythm) => rhythm.status == RhythmStatus.drifting,
    )) {
      return FamilyOverallState.drifting;
    }

    if (snapshot.rhythms.any(
      (rhythm) => rhythm.status == RhythmStatus.recovering,
    )) {
      return FamilyOverallState.recovering;
    }

    if (snapshot.rhythms.any(
      (rhythm) => rhythm.status == RhythmStatus.strengthening,
    )) {
      return FamilyOverallState.strengthening;
    }

    final hasEnoughObservations = snapshot.rhythms.any(
      (rhythm) =>
          rhythm.occurrenceCount >= 3 &&
          rhythm.confidence != ConfidenceLevel.low,
    );

    return hasEnoughObservations
        ? FamilyOverallState.stable
        : FamilyOverallState.stillLearning;
  }

  static ConfidenceLevel _overallConfidence(FamilyInsightSnapshot snapshot) {
    if (snapshot.rhythms.isEmpty) {
      return ConfidenceLevel.low;
    }

    final highCount = snapshot.rhythms
        .where((rhythm) => rhythm.confidence == ConfidenceLevel.high)
        .length;

    final mediumOrHighCount = snapshot.rhythms
        .where(
          (rhythm) =>
              rhythm.confidence == ConfidenceLevel.medium ||
              rhythm.confidence == ConfidenceLevel.high,
        )
        .length;

    if (highCount * 2 >= snapshot.rhythms.length) {
      return ConfidenceLevel.high;
    }

    if (mediumOrHighCount * 2 >= snapshot.rhythms.length) {
      return ConfidenceLevel.medium;
    }

    return ConfidenceLevel.low;
  }

  static String _upcomingHeadline(String title, int days) {
    if (days == 0) {
      return '$title is today';
    }

    if (days == 1) {
      return '$title is tomorrow';
    }

    if (days <= 7) {
      return '$title is this week';
    }

    return '$title is coming up';
  }

  static String _instanceSummary(MomentCategory category) {
    return switch (category) {
      MomentCategory.milestone =>
        'A major family milestone is approaching and may need practical preparation.',
      MomentCategory.care =>
        'This care-related occurrence is approaching and may need a personal action.',
      MomentCategory.responsibility =>
        'A family responsibility is approaching and should have a clear owner.',
      _ => 'This planned family occurrence is approaching.',
    };
  }

  static List<String> _actionsForCategory(MomentCategory category) {
    return switch (category) {
      MomentCategory.milestone => const <String>[
        'Confirm the event time and location.',
        'Prepare a gift or family message.',
        'Confirm travel and expected participants.',
      ],
      MomentCategory.care => const <String>[
        'Confirm what support is needed.',
        'Prepare a message, visit, or gift.',
        'Create a personal reminder.',
      ],
      MomentCategory.responsibility => const <String>[
        'Confirm who owns the task.',
        'Prepare the required items.',
        'Create a deadline reminder.',
      ],
      _ => const <String>['Review the planned occurrence.'],
    };
  }

  static String _daysReason(int days) {
    if (days == 0) {
      return 'The occurrence is today.';
    }

    if (days == 1) {
      return 'The occurrence is tomorrow.';
    }

    return 'The occurrence is in $days days.';
  }

  static int _daysUntil(DateTime reference, DateTime target) {
    return _dateOnly(
      target.toLocal(),
    ).difference(_dateOnly(reference.toLocal())).inDays;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

class _ActionTimeChoice {
  const _ActionTimeChoice({
    required this.dateTime,
    required this.usesAvailability,
  });

  final DateTime dateTime;
  final bool usesAvailability;
}
