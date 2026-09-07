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
      final candidateMoment = snapshot.momentById(instance.momentId);

      final canStart =
          snapshot.currentUserCanManageSharedMoments &&
          (currentRole == FamilyRole.admin ||
              snapshot.currentUserIsExpected(instance));

      final canCreateReminder =
          snapshot.currentUserCanManageSharedMoments ||
          snapshot.currentUserIsExpected(instance) ||
          (candidateMoment?.isSubject(snapshot.currentUserId) ?? false);

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
            _sameDayReminderInsight(
              snapshot: snapshot,
              instance: instance,
              decision: decision,
            ),
          );
          break;
        case FamilyInsightActionType.reviewToday:
          addInsight(_reviewNeededInsight(instance, snapshot.generatedAt));
          break;
        default:
          if (active == null && _shouldShowParticipantReady(snapshot, instance)) {
            addInsight(_participantReadyInsight(snapshot, instance));
          }
          break;
      }
    }

    for (final reminder in snapshot.overdueCurrentUserReminders.take(2)) {
      addInsight(_overdueReminderInsight(reminder));
    }

    for (final instance in snapshot.upcomingInstances) {
      final category = instance.categorySnapshot;
      final days = _daysUntil(snapshot.generatedAt, instance.scheduledStartAt);

      if (category != MomentCategory.memory && days >= 0 && days <= 14) {
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
    required FamilyInsightSnapshot snapshot,
    required MomentInstance instance,
    required MomentActionDecision decision,
  }) {
    final hasReminder =
        decision.actionType == FamilyInsightActionType.openReminders;
    final reminderChoice = hasReminder
        ? null
        : _findPersonalReminderTime(snapshot, instance);
    final canUseSimulation =
        _currentMemberCanUseSimulation(snapshot) &&
        _hasCurrentUserScheduleData(snapshot) &&
        snapshot.momentById(instance.momentId)?.type == MomentType.recurring;
    final actionType = hasReminder
        ? FamilyInsightActionType.openReminders
        : reminderChoice != null
        ? FamilyInsightActionType.addReminder
        : canUseSimulation
        ? FamilyInsightActionType.openSimulation
        : FamilyInsightActionType.none;

    return FamilyInsightItem(
      id: 'today:${instance.id}',
      kind: FamilyInsightKind.upcomingMoment,
      actionType: actionType,
      priority: 10,
      headline: '${instance.titleSnapshot} is later today',
      summary: _instanceSummary(
        instance.titleSnapshot,
        instance.categorySnapshot,
      ),
      reasons: <String>[
        'The occurrence is scheduled today.',
        if (hasReminder)
          'A personal reminder is already linked to this occurrence.'
        else
          'No personal reminder is linked to this occurrence yet.',
      ],
      suggestedActions: hasReminder
          ? <String>['Open your ${instance.titleSnapshot} reminder.']
          : <String>[
              _preparationAction(
                instance.titleSnapshot,
                instance.categorySnapshot,
              ),
            ],
      confidence: ConfidenceLevel.high,
      relatedMomentId: instance.momentId,
      relatedInstanceId: instance.id,
      relatedReminderId: decision.relatedReminderId,
      recommendedActionAt:
          hasReminder ? decision.recommendedActionAt : reminderChoice?.dateTime,
      recommendedActionUsesAvailability:
          reminderChoice?.usesAvailability ?? false,
      recommendsSimulation:
          actionType == FamilyInsightActionType.openSimulation,
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
    final canUseSimulation =
        _currentMemberCanUseSimulation(snapshot) &&
        _hasCurrentUserScheduleData(snapshot) &&
        snapshot.momentById(instance.momentId)?.type == MomentType.recurring;
    final actionType = existing != null
        ? FamilyInsightActionType.openReminders
        : reminderChoice != null
        ? FamilyInsightActionType.addReminder
        : canUseSimulation
        ? FamilyInsightActionType.openSimulation
        : FamilyInsightActionType.none;

    return FamilyInsightItem(
      id: 'prepare:${instance.id}',
      kind: switch (category) {
        MomentCategory.milestone => FamilyInsightKind.upcomingMilestone,
        MomentCategory.care ||
        MomentCategory.responsibility => FamilyInsightKind.carePreparation,
        _ => FamilyInsightKind.upcomingMoment,
      },
      actionType: actionType,
      priority: 20 + days.clamp(0, 14).toInt(),
      headline: _upcomingHeadline(instance.titleSnapshot, days),
      summary: _instanceSummary(instance.titleSnapshot, category),
      reasons: <String>[
        _daysReason(days),
        'The Moment is marked ${instance.importanceLevelSnapshot}/5 importance.',
        if (existing == null)
          'No active personal preparation reminder is linked to this occurrence.'
        else
          'A personal reminder is already linked to this occurrence.',
        if (reminderChoice?.usesAvailability == true)
          'The suggested reminder time avoids your recorded busy periods.',
        if (existing == null && reminderChoice == null)
          'No conflict-free preparation time was found in your recorded schedule.',
      ],
      suggestedActions: <String>[
        _preparationAction(instance.titleSnapshot, category),
      ],
      confidence: ConfidenceLevel.high,
      relatedMomentId: instance.momentId,
      relatedInstanceId: instance.id,
      relatedReminderId: existing?.id,
      recommendedActionAt: existing?.dueAt ?? reminderChoice?.dateTime,
      recommendedActionUsesAvailability:
          reminderChoice?.usesAvailability ?? false,
      recommendsSimulation:
          actionType == FamilyInsightActionType.openSimulation,
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

  static bool _shouldShowParticipantReady(
    FamilyInsightSnapshot snapshot,
    MomentInstance instance,
  ) {
    final member = snapshot.currentMember;
    if (member == null ||
        (member.ageGroup != AgeGroup.child &&
            member.ageGroup != AgeGroup.teen) ||
        !snapshot.currentUserIsExpected(instance) ||
        instance.isFinished) {
      return false;
    }

    final now = snapshot.generatedAt.toLocal();
    final start = instance.scheduledStartAt.toLocal();
    final end = (instance.scheduledEndAt ??
            instance.scheduledStartAt.add(const Duration(minutes: 90)))
        .toLocal();
    final isShared = instance.categorySnapshot == MomentCategory.tradition ||
        instance.categorySnapshot == MomentCategory.familyTime;
    return isShared && !now.isBefore(start) && !now.isAfter(end);
  }

  static FamilyInsightItem _participantReadyInsight(
    FamilyInsightSnapshot snapshot,
    MomentInstance instance,
  ) {
    final isTeen = snapshot.currentMember?.ageGroup == AgeGroup.teen;
    return FamilyInsightItem(
      id: 'ready:${instance.id}:${snapshot.currentUserId}',
      kind: FamilyInsightKind.sharedMomentOpportunity,
      actionType: FamilyInsightActionType.none,
      priority: 5,
      headline: '${instance.titleSnapshot} is ready to begin',
      summary: 'An adult starts the shared Moment; your part is to be ready to join.',
      reasons: const <String>[
        'The Moment is inside its planned start window.',
        'You are an expected participant.',
      ],
      suggestedActions: <String>[
        isTeen
            ? 'Be ready to join ${instance.titleSnapshot} when an adult starts it.'
            : 'Stay with an adult and be ready for ${instance.titleSnapshot}.',
        isTeen
            ? 'Bring the part or item you prepared.'
            : 'Bring one small item you prepared with an adult.',
      ],
      confidence: ConfidenceLevel.high,
      relatedMomentId: instance.momentId,
      relatedInstanceId: instance.id,
      recommendedActionAt: instance.scheduledStartAt,
    );
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
          bestSharedWindow != null &&
          bestSharedWindow.everyoneAvailable &&
          bestSharedWindow.hasFullScheduleCoverage,
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
    final personalBlocks = snapshot.availability
        .where(
          (block) =>
              block.memberId == snapshot.currentUserId &&
              !block.isExpiredAt(snapshot.generatedAt),
        )
        .toList();

    if (eventDate == today) {
      var candidate = event.subtract(const Duration(minutes: 30));
      final minimum = reference.add(const Duration(minutes: 1));

      if (candidate.isBefore(minimum)) {
        candidate = minimum;
      }

      if (candidate.add(const Duration(minutes: 30)).isAfter(event)) {
        return null;
      }

      if (!_overlapsPersonalBlocks(
        candidate: candidate,
        durationMinutes: 30,
        blocks: personalBlocks,
      )) {
        return _ActionTimeChoice(
          dateTime: candidate,
          usesAvailability: personalBlocks.isNotEmpty,
        );
      }

      var search = minimum;
      while (search.add(const Duration(minutes: 30)).isBefore(event) ||
          search.add(const Duration(minutes: 30)).isAtSameMomentAs(event)) {
        if (!_overlapsPersonalBlocks(
          candidate: search,
          durationMinutes: 30,
          blocks: personalBlocks,
        )) {
          return _ActionTimeChoice(
            dateTime: search,
            usesAvailability: personalBlocks.isNotEmpty,
          );
        }
        search = search.add(const Duration(minutes: 15));
      }

      return null;
    }

    if (!eventDate.isAfter(today)) {
      return null;
    }

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

        if (!_overlapsPersonalBlocks(
          candidate: candidate,
          durationMinutes: 60,
          blocks: personalBlocks,
        )) {
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

    if (personalBlocks.isNotEmpty &&
        _overlapsPersonalBlocks(
          candidate: fallback,
          durationMinutes: 60,
          blocks: personalBlocks,
        )) {
      return null;
    }

    return _ActionTimeChoice(
      dateTime: fallback,
      usesAvailability: personalBlocks.isNotEmpty,
    );
  }

  static bool _overlapsPersonalBlocks({
    required DateTime candidate,
    required int durationMinutes,
    required List<AvailabilityBlock> blocks,
  }) {
    final windowStart = candidate.toLocal();
    final windowEnd = windowStart.add(Duration(minutes: durationMinutes));
    final date = _dateOnly(windowStart);
    final previousDate = date.subtract(const Duration(days: 1));

    return blocks.any((block) {
      return _blockOverlapsWindow(
            block: block,
            blockDate: date,
            windowStart: windowStart,
            windowEnd: windowEnd,
          ) ||
          _blockOverlapsWindow(
            block: block,
            blockDate: previousDate,
            windowStart: windowStart,
            windowEnd: windowEnd,
          );
    });
  }

  static bool _blockOverlapsWindow({
    required AvailabilityBlock block,
    required DateTime blockDate,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    if (!block.occursOn(blockDate)) return false;

    final busyStart = blockDate.add(Duration(minutes: block.startMinutes));
    var busyEnd = blockDate.add(Duration(minutes: block.endMinutes));
    if (!busyEnd.isAfter(busyStart)) {
      busyEnd = busyEnd.add(const Duration(days: 1));
    }

    return windowStart.isBefore(busyEnd) && windowEnd.isAfter(busyStart);
  }

  static bool _hasCurrentUserScheduleData(FamilyInsightSnapshot snapshot) {
    return snapshot.availability.any(
      (block) =>
          block.memberId == snapshot.currentUserId &&
          !block.isExpiredAt(snapshot.generatedAt),
    );
  }

  static bool _currentMemberCanUseSimulation(
    FamilyInsightSnapshot snapshot,
  ) {
    final member = snapshot.currentMember;
    if (member == null) return false;
    final hasAdultRole =
        member.role == FamilyRole.admin || member.role == FamilyRole.adult;
    final hasAdultAge =
        member.ageGroup == AgeGroup.adult ||
        member.ageGroup == AgeGroup.senior;
    return hasAdultRole && hasAdultAge;
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

  static String _instanceSummary(String title, MomentCategory category) {
    final normalized = title.toLowerCase();

    if (_containsAny(normalized, const <String>[
      'lunch',
      'lynch',
      'dinner',
      'breakfast',
      'brunch',
      'meal',
      'غداء',
      'عشاء',
      'فطور',
    ])) {
      return 'Choose the meal and check the ingredients before $title.';
    }
    if (_containsAny(normalized, const <String>[
      'birthday',
      'عيد ميلاد',
      'ميلاد',
    ])) {
      return 'Choose a gift or write a card before $title.';
    }
    if (_containsAny(normalized, const <String>[
      'graduation',
      'graduate',
      'تخرج',
      'تخرّج',
    ])) {
      return 'Prepare a congratulatory message for $title.';
    }
    if (_containsAny(normalized, const <String>['picnic', 'نزهة'])) {
      return 'Choose the picnic spot and pack the shared essentials.';
    }

    return switch (category) {
      MomentCategory.milestone =>
        'Choose one personal way to mark $title before it arrives.',
      MomentCategory.care =>
        'Decide what support or item will be useful for $title.',
      MomentCategory.responsibility =>
        'Gather the main item needed for $title before it begins.',
      MomentCategory.tradition =>
        'Set aside the main item the family uses for $title.',
      MomentCategory.familyTime =>
        'Choose the shared activity or item needed for $title.',
      _ => 'Choose one practical item the family will need for $title.',
    };
  }

  static String _preparationAction(String title, MomentCategory category) {
    final normalized = title.toLowerCase();

    if (_containsAny(normalized, const <String>[
      'lunch',
      'lynch',
      'dinner',
      'breakfast',
      'brunch',
      'meal',
      'غداء',
      'عشاء',
      'فطور',
    ])) {
      return 'Choose the menu and check ingredients.';
    }
    if (_containsAny(normalized, const <String>[
      'birthday',
      'عيد ميلاد',
      'ميلاد',
    ])) {
      return 'Choose a gift or write a birthday card.';
    }
    if (_containsAny(normalized, const <String>[
      'graduation',
      'graduate',
      'تخرج',
      'تخرّج',
    ])) {
      return 'Write a short congratulatory message.';
    }
    if (_containsAny(normalized, const <String>['picnic', 'نزهة'])) {
      return 'Choose the spot and pack the picnic essentials.';
    }
    if (_containsAny(normalized, const <String>[
      'appointment',
      'doctor',
      'clinic',
      'موعد',
      'طبيب',
    ])) {
      return 'Gather the documents and questions to bring.';
    }
    if (_containsAny(normalized, const <String>[
      'wedding',
      'زفاف',
      'عرس',
    ])) {
      return 'Choose a gift and write a short message.';
    }

    return switch (category) {
      MomentCategory.milestone => 'Choose a gift, card, or family message.',
      MomentCategory.care => 'Choose the support or item you will bring.',
      MomentCategory.responsibility => 'Gather the main item needed for it.',
      MomentCategory.tradition => 'Set aside the main item used for it.',
      MomentCategory.familyTime => 'Choose the shared activity or item.',
      _ => 'Choose one practical item needed for it.',
    };
  }

  static bool _containsAny(String value, List<String> terms) {
    return terms.any(value.contains);
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
