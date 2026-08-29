import 'dart:async';

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
  /// time-based facts such as overdue reminders stay current.
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

          final snapshot = FamilyInsightSnapshot(
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
          );

          controller.add(analyze(snapshot));
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

  /// Public pure entry point used by automated tests and future
  /// server-side validation.
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
          : insights.skip(1).take(3).toList(),
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

    if (snapshot.currentUserCanManageSharedMoments &&
        snapshot.reviewableInstances.isNotEmpty) {
      addInsight(_reviewNeededInsight(snapshot.reviewableInstances.first));
    }

    final startable = _startableInstances(snapshot);

    if (startable.isNotEmpty) {
      addInsight(_startNowInsight(snapshot, startable.first));
    }

    for (final reminder in snapshot.overdueCurrentUserReminders.take(2)) {
      addInsight(_overdueReminderInsight(reminder));
    }

    final upcoming = List<MomentInstance>.from(snapshot.upcomingInstances)
      ..sort((first, second) {
        final firstRank = _instancePriority(snapshot, first);
        final secondRank = _instancePriority(snapshot, second);

        final rankResult = firstRank.compareTo(secondRank);

        if (rankResult != 0) {
          return rankResult;
        }

        return first.scheduledStartAt.compareTo(second.scheduledStartAt);
      });

    for (final instance in upcoming) {
      final rank = _instancePriority(snapshot, instance);

      // Rank 1 belongs to a Drifting rhythm and is intentionally handled
      // by the dedicated rhythm insight below so the explanation does not
      // degrade into a generic upcoming-event message.
      if (rank == 0 || rank == 2) {
        addInsight(_upcomingInstanceInsight(snapshot, instance));
      }
    }

    for (final rhythm in snapshot.driftingRhythms) {
      final moment = snapshot.momentById(rhythm.momentId);

      if (moment != null) {
        addInsight(
          _driftingRhythmInsight(snapshot, moment, rhythm, bestSharedWindow),
        );
      }
    }

    if (upcoming.isNotEmpty) {
      addInsight(_upcomingInstanceInsight(snapshot, upcoming.first));
    }

    insights.sort((first, second) => first.priority.compareTo(second.priority));

    return insights;
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

  static FamilyInsightItem _reviewNeededInsight(MomentInstance instance) {
    return FamilyInsightItem(
      id: 'review:${instance.id}',
      kind: FamilyInsightKind.reviewNeeded,
      actionType: FamilyInsightActionType.reviewToday,
      priority: 5,
      headline: 'Did ${instance.titleSnapshot} happen?',
      summary:
          'Its planned time has passed, but Sakan has no completed, missed, or cancelled outcome yet.',
      reasons: <String>[
        'The scheduled time has passed.',
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
      recommendedActionAt: DateTime.now(),
    );
  }

  static FamilyInsightItem _startNowInsight(
    FamilyInsightSnapshot snapshot,
    MomentInstance instance,
  ) {
    final definition = snapshot.momentById(instance.momentId);

    return FamilyInsightItem(
      id: 'start:${instance.id}',
      kind: FamilyInsightKind.sharedMomentOpportunity,
      actionType: FamilyInsightActionType.startMomentNow,
      priority: 10,
      headline: '${instance.titleSnapshot} can start now',
      summary:
          'This shared Moment is close to its planned time and no other family session is active.',
      reasons: <String>[
        'The occurrence is scheduled around the current time.',
        '${instance.expectedParticipantIds.length} family members are expected.',
        if (definition?.type == MomentType.recurring)
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
      recommendedActionAt: DateTime.now(),
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
      relatedReminderId: reminder.id,
    );
  }

  static FamilyInsightItem _upcomingInstanceInsight(
    FamilyInsightSnapshot snapshot,
    MomentInstance instance,
  ) {
    final moment = snapshot.momentById(instance.momentId);
    final category = moment?.category ?? instance.categorySnapshot;
    final importance =
        moment?.importanceLevel ?? instance.importanceLevelSnapshot;
    final days = _daysUntil(snapshot.generatedAt, instance.scheduledStartAt);

    final existingReminder = snapshot.activeReminderForMoment(
      instance.momentId,
    );

    final isPreparation =
        category == MomentCategory.milestone ||
        category == MomentCategory.care ||
        category == MomentCategory.responsibility;

    final actionType = existingReminder != null
        ? FamilyInsightActionType.openReminders
        : isPreparation
        ? FamilyInsightActionType.addReminder
        : _canStartNow(snapshot, instance)
        ? FamilyInsightActionType.startMomentNow
        : FamilyInsightActionType.scheduleMoment;

    final reminderChoice = actionType == FamilyInsightActionType.addReminder
        ? _findPersonalReminderTime(snapshot, instance)
        : null;

    return FamilyInsightItem(
      id: 'instance:${instance.id}',
      kind: switch (category) {
        MomentCategory.milestone => FamilyInsightKind.upcomingMilestone,
        MomentCategory.care ||
        MomentCategory.responsibility => FamilyInsightKind.carePreparation,
        _ => FamilyInsightKind.upcomingMoment,
      },
      actionType: actionType,
      priority: switch (category) {
        MomentCategory.milestone => 30,
        MomentCategory.care || MomentCategory.responsibility => 30,
        _ => importance >= 4 ? 50 : 60,
      },
      headline: _upcomingHeadline(instance.titleSnapshot, days),
      summary: _instanceSummary(category),
      reasons: <String>[
        _daysReason(days),
        'The Moment is marked $importance/5 importance.',
        '${instance.expectedParticipantIds.length} expected '
            '${instance.expectedParticipantIds.length == 1 ? 'participant is' : 'participants are'} connected to it.',
        if (existingReminder == null && isPreparation)
          'No active personal preparation reminder is linked to it.'
        else if (existingReminder != null)
          'A personal reminder is already linked to it.',
        if (reminderChoice?.usesAvailability == true)
          'The suggested reminder time avoids your recorded busy periods.',
      ],
      suggestedActions: _actionsForCategory(category),
      confidence: ConfidenceLevel.high,
      relatedMomentId: instance.momentId,
      relatedInstanceId: instance.id,
      relatedReminderId: existingReminder?.id,
      recommendedActionAt: switch (actionType) {
        FamilyInsightActionType.addReminder => reminderChoice?.dateTime,
        FamilyInsightActionType.startMomentNow => DateTime.now(),
        FamilyInsightActionType.scheduleMoment => instance.scheduledStartAt,
        _ => existingReminder?.dueAt,
      },
      recommendedActionUsesAvailability:
          reminderChoice?.usesAvailability ?? false,
    );
  }

  static FamilyInsightItem _driftingRhythmInsight(
    FamilyInsightSnapshot snapshot,
    FamilyMoment moment,
    RhythmRecord rhythm,
    FamilyAvailabilityWindow? bestSharedWindow,
  ) {
    final openInstance = snapshot.openInstanceForMoment(moment.id);
    final canStart =
        openInstance != null && _canStartNow(snapshot, openInstance);

    final actionType = canStart
        ? FamilyInsightActionType.startMomentNow
        : FamilyInsightActionType.scheduleMoment;

    return FamilyInsightItem(
      id: 'rhythm:${rhythm.id}',
      kind: FamilyInsightKind.driftingRhythm,
      actionType: actionType,
      priority: 40,
      headline: '${moment.title} is drifting',
      summary:
          'This recurring family Moment has moved beyond its usual confirmed pattern and may need a realistic next occurrence.',
      reasons: <String>[
        '${rhythm.currentGapDays} days have passed since its last confirmed occurrence.',
        'Its expected interval is ${rhythm.expectedIntervalDays} days.',
        'The current recorded rhythm status is Drifting.',
        if (bestSharedWindow != null)
          '${bestSharedWindow.availableMemberCount} of '
              '${bestSharedWindow.totalMemberCount} active members have no recorded conflict in the best upcoming window.',
        if (bestSharedWindow != null &&
            !bestSharedWindow.hasFullScheduleCoverage)
          'Availability is based on '
              '${bestSharedWindow.membersWithScheduleDataCount} of '
              '${bestSharedWindow.totalMemberCount} members with schedule data.',
      ],
      suggestedActions: const <String>[
        'Review the next planned occurrence.',
        'Choose a realistic date and time.',
        'Confirm the expected participants.',
      ],
      confidence: rhythm.confidence,
      relatedMomentId: moment.id,
      relatedInstanceId: openInstance?.id,
      recommendedActionAt: canStart
          ? DateTime.now()
          : openInstance?.scheduledStartAt ?? bestSharedWindow?.startAt,
      recommendedActionUsesAvailability: !canStart && bestSharedWindow != null,
    );
  }

  static List<MomentInstance> _startableInstances(
    FamilyInsightSnapshot snapshot,
  ) {
    if (!snapshot.currentUserCanManageSharedMoments ||
        snapshot.activeInstance != null) {
      return const <MomentInstance>[];
    }

    final result = snapshot.instances
        .where((instance) => _canStartNow(snapshot, instance))
        .toList();

    final now = snapshot.generatedAt.toLocal();

    result.sort((first, second) {
      final firstDistance = first.scheduledStartAt
          .toLocal()
          .difference(now)
          .inMinutes
          .abs();

      final secondDistance = second.scheduledStartAt
          .toLocal()
          .difference(now)
          .inMinutes
          .abs();

      return firstDistance.compareTo(secondDistance);
    });

    return result;
  }

  static bool _canStartNow(
    FamilyInsightSnapshot snapshot,
    MomentInstance instance,
  ) {
    if (!snapshot.currentUserCanManageSharedMoments ||
        snapshot.activeInstance != null) {
      return false;
    }

    final isPlanned =
        instance.status == MomentInstanceStatus.proposed ||
        instance.status == MomentInstanceStatus.scheduled ||
        instance.status == MomentInstanceStatus.inviting;

    if (!isPlanned || instance.expectedParticipantIds.length < 2) {
      return false;
    }

    final category = instance.categorySnapshot;

    if (category != MomentCategory.tradition &&
        category != MomentCategory.familyTime) {
      return false;
    }

    final member = snapshot.currentMember;
    final isAdmin = member?.role == FamilyRole.admin;

    if (!isAdmin && !snapshot.currentUserIsExpected(instance)) {
      return false;
    }

    final now = snapshot.generatedAt.toLocal();
    final scheduled = instance.scheduledStartAt.toLocal();
    final minutes = scheduled.difference(now).inMinutes;

    return minutes >= -120 && minutes <= 180;
  }

  static int _instancePriority(
    FamilyInsightSnapshot snapshot,
    MomentInstance instance,
  ) {
    final category = instance.categorySnapshot;
    final days = _daysUntil(snapshot.generatedAt, instance.scheduledStartAt);

    if ((category == MomentCategory.milestone ||
            category == MomentCategory.care ||
            category == MomentCategory.responsibility) &&
        days >= 0 &&
        days <= 14) {
      return 0;
    }

    final rhythm = snapshot.rhythmForMoment(instance.momentId);

    if (rhythm?.status == RhythmStatus.drifting) {
      return 1;
    }

    if (instance.importanceLevelSnapshot >= 4 && days >= 0 && days <= 21) {
      return 2;
    }

    return 3;
  }

  static _ActionTimeChoice? _findPersonalReminderTime(
    FamilyInsightSnapshot snapshot,
    MomentInstance instance,
  ) {
    final reference = snapshot.generatedAt.toLocal();
    final eventDate = _dateOnly(instance.scheduledStartAt.toLocal());
    final today = _dateOnly(reference);

    if (!eventDate.isAfter(today)) {
      final candidate = reference.add(const Duration(minutes: 30));

      return candidate.isBefore(instance.scheduledStartAt.toLocal())
          ? _ActionTimeChoice(dateTime: candidate, usesAvailability: false)
          : null;
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

    var fallbackDate = eventDate.subtract(const Duration(days: 2));

    if (!fallbackDate.isAfter(today)) {
      fallbackDate = today.add(const Duration(days: 1));
    }

    final fallback = DateTime(
      fallbackDate.year,
      fallbackDate.month,
      fallbackDate.day,
      18,
    );

    if (!fallback.isBefore(instance.scheduledStartAt.toLocal())) {
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
    if (days < 0) {
      return '$title needs review';
    }

    if (days == 0) {
      return '$title is today';
    }

    if (days == 1) {
      return '$title is tomorrow';
    }

    if (days <= 7) {
      return '$title is this week';
    }

    if (days <= 14) {
      return '$title is next week';
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
      MomentCategory.tradition =>
        'A concrete occurrence of this family tradition is approaching.',
      MomentCategory.familyTime =>
        'This planned shared family occurrence is approaching.',
      MomentCategory.memory => 'This memory-related occurrence is approaching.',
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
      MomentCategory.tradition => const <String>[
        'Review the planned occurrence.',
        'Confirm the expected participants.',
        'Start the Moment when the family gathers.',
      ],
      MomentCategory.familyTime => const <String>[
        'Confirm the shared time.',
        'Choose the activity or location.',
        'Start the Moment when everyone is ready.',
      ],
      MomentCategory.memory => const <String>[
        'Review the related family history.',
        'Confirm who is involved.',
        'Preserve a note after completion.',
      ],
    };
  }

  static String _daysReason(int days) {
    if (days < 0) {
      return 'The planned date has passed.';
    }

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
