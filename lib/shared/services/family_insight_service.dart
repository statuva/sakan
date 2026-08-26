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
import '../models/rhythm_record.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/care_action_repository.dart';
import '../repositories/memory_repository.dart';
import '../repositories/schedule_repository.dart';
import 'current_family_service.dart';

class FamilyInsightService {
  const FamilyInsightService({
    required CurrentFamilyService currentFamilyService,
    required CalendarRepository calendarRepository,
    required ScheduleRepository scheduleRepository,
    required CareActionRepository careActionRepository,
    required MemoryRepository memoryRepository,
  }) : _currentFamilyService = currentFamilyService,
       _calendarRepository = calendarRepository,
       _scheduleRepository = scheduleRepository,
       _careActionRepository = careActionRepository,
       _memoryRepository = memoryRepository;

  final CurrentFamilyService _currentFamilyService;
  final CalendarRepository _calendarRepository;
  final ScheduleRepository _scheduleRepository;
  final CareActionRepository _careActionRepository;
  final MemoryRepository _memoryRepository;

  Future<FamilyInsightSnapshot> loadSnapshot() async {
    final context = await _currentFamilyService.load();

    final remindersFuture = _remindersStreamFor(context).first;

    final results = await Future.wait<Object>([
      _currentFamilyService.watchFamilyMembers(context.familyId).first,
      _calendarRepository.watchMoments(familyId: context.familyId).first,
      _calendarRepository.watchRhythms(familyId: context.familyId).first,
      _scheduleRepository
          .watchFamilyAvailability(familyId: context.familyId)
          .first,
      remindersFuture,
      _memoryRepository.watchMemories(familyId: context.familyId).first,
    ]);

    return FamilyInsightSnapshot(
      familyId: context.familyId,
      currentUserId: context.userId,
      generatedAt: DateTime.now().toUtc(),
      members: results[0] as List<Member>,
      moments: results[1] as List<FamilyMoment>,
      rhythms: results[2] as List<RhythmRecord>,
      availability: results[3] as List<AvailabilityBlock>,
      reminders: results[4] as List<CareAction>,
      memories: results[5] as List<FamilyMemory>,
    );
  }

  Future<FamilyInsightReport> loadReport() async {
    final snapshot = await loadSnapshot();
    return analyze(snapshot);
  }

  /// Watches all data sources and emits a new report whenever
  /// one of them changes.
  Stream<FamilyInsightReport> watchReport() {
    late StreamController<FamilyInsightReport> controller;

    final subscriptions = <StreamSubscription<dynamic>>[];
    var cancelled = false;

    Future<void> start() async {
      try {
        final context = await _currentFamilyService.load();

        if (cancelled) {
          return;
        }

        List<Member>? members;
        List<FamilyMoment>? moments;
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
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    Future<void> cancel() async {
      cancelled = true;

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

  FamilyAvailabilityWindow? findBestSharedWindow(
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

  List<FamilyInsightItem> _buildInsights(
    FamilyInsightSnapshot snapshot,
    FamilyAvailabilityWindow? bestSharedWindow,
  ) {
    final insights = <FamilyInsightItem>[];
    final seenKeys = <String>{};

    void addInsight(FamilyInsightItem insight) {
      final key = insight.relatedMomentId != null
          ? 'moment:${insight.relatedMomentId}'
          : insight.relatedReminderId != null
          ? 'reminder:${insight.relatedReminderId}'
          : insight.id;

      if (seenKeys.add(key)) {
        insights.add(insight);
      }
    }

    for (final reminder in snapshot.overdueCurrentUserReminders.take(2)) {
      addInsight(_overdueReminderInsight(reminder));
    }

    final priorityMoments = List<FamilyMoment>.from(snapshot.upcomingMoments)
      ..sort((first, second) {
        final firstRank = _momentPriority(snapshot, first);
        final secondRank = _momentPriority(snapshot, second);

        final rankResult = firstRank.compareTo(secondRank);

        if (rankResult != 0) {
          return rankResult;
        }

        final dateResult = first.startAt.compareTo(second.startAt);

        if (dateResult != 0) {
          return dateResult;
        }

        return second.importanceLevel.compareTo(first.importanceLevel);
      });

    for (final moment in priorityMoments) {
      if (_momentPriority(snapshot, moment) > 2) {
        break;
      }

      addInsight(_upcomingMomentInsight(snapshot, moment));
    }

    for (final rhythm in snapshot.driftingRhythms) {
      final moment = snapshot.momentById(rhythm.momentId);

      if (moment != null) {
        addInsight(_driftingRhythmInsight(moment, rhythm, bestSharedWindow));
      }
    }

    if (priorityMoments.isNotEmpty) {
      addInsight(_upcomingMomentInsight(snapshot, priorityMoments.first));
    }

    insights.sort((first, second) => first.priority.compareTo(second.priority));

    return insights;
  }

  int _momentPriority(FamilyInsightSnapshot snapshot, FamilyMoment moment) {
    final days = _daysUntil(snapshot.generatedAt, moment.startAt);

    if ((moment.category == MomentCategory.milestone ||
            moment.category == MomentCategory.care) &&
        days >= 0 &&
        days <= 14) {
      return 0;
    }

    final rhythm = snapshot.rhythmForMoment(moment.id);

    if (rhythm?.status == RhythmStatus.drifting) {
      return 1;
    }

    if (moment.importanceLevel >= 4 && days >= 0 && days <= 21) {
      return 2;
    }

    return 3;
  }

  FamilyInsightItem _overdueReminderInsight(CareAction reminder) {
    return FamilyInsightItem(
      id: 'overdue:${reminder.id}',
      kind: FamilyInsightKind.overdueReminder,
      priority: 0,
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
        'Complete the reminder if it is done.',
        'Choose a new due time if it is still needed.',
        'Delete it if it is no longer relevant.',
      ],
      confidence: ConfidenceLevel.high,
      relatedReminderId: reminder.id,
    );
  }

  FamilyInsightItem _upcomingMomentInsight(
    FamilyInsightSnapshot snapshot,
    FamilyMoment moment,
  ) {
    final days = _daysUntil(snapshot.generatedAt, moment.startAt);

    final existingReminder = snapshot.activeReminderForMoment(moment.id);

    final reminderChoice = existingReminder == null
        ? _findPersonalReminderTime(snapshot, moment)
        : _ReminderChoice(
            dateTime: existingReminder.dueAt.toLocal(),
            usesAvailability: false,
          );

    return FamilyInsightItem(
      id: 'moment:${moment.id}',
      kind: switch (moment.category) {
        MomentCategory.milestone => FamilyInsightKind.upcomingMilestone,
        MomentCategory.care => FamilyInsightKind.carePreparation,
        _ => FamilyInsightKind.upcomingMoment,
      },
      priority: switch (moment.category) {
        MomentCategory.milestone => 10,
        MomentCategory.care => 10,
        _ => moment.importanceLevel >= 4 ? 30 : 40,
      },
      headline: _upcomingHeadline(moment, days),
      summary: _momentSummary(moment),
      reasons: <String>[
        _daysReason(days),
        'The Moment is marked ${moment.importanceLevel}/5 importance.',
        '${moment.expectedParticipantIds.length} expected '
            '${moment.expectedParticipantIds.length == 1 ? 'participant is' : 'participants are'} connected to it.',
        if (existingReminder == null)
          'No active personal reminder is linked to this Moment.'
        else
          'A personal reminder is already linked to this Moment.',
        if (reminderChoice?.usesAvailability == true)
          'The recommended time avoids your recorded busy periods.',
      ],
      suggestedActions: _actionsForCategory(moment.category),
      confidence: ConfidenceLevel.high,
      relatedMomentId: moment.id,
      relatedReminderId: existingReminder?.id,
      recommendedReminderAt: reminderChoice?.dateTime,
      recommendedReminderUsesAvailability:
          reminderChoice?.usesAvailability ?? false,
    );
  }

  FamilyInsightItem _driftingRhythmInsight(
    FamilyMoment moment,
    RhythmRecord rhythm,
    FamilyAvailabilityWindow? bestSharedWindow,
  ) {
    return FamilyInsightItem(
      id: 'rhythm:${rhythm.id}',
      kind: FamilyInsightKind.driftingRhythm,
      priority: 20,
      headline: '${moment.title} is drifting',
      summary:
          'This recurring family Moment has moved beyond its usual recorded pattern and may need review.',
      reasons: <String>[
        '${rhythm.currentGapDays} days have passed since its last recorded occurrence.',
        'Its usual interval is ${rhythm.expectedIntervalDays} days.',
        'The current rhythm status is Drifting.',
        if (bestSharedWindow != null)
          '${bestSharedWindow.availableMemberCount} of '
              '${bestSharedWindow.totalMemberCount} active members have no recorded conflict in the best upcoming window.',
        if (bestSharedWindow != null &&
            !bestSharedWindow.hasFullScheduleCoverage)
          'Availability is based on '
              '${bestSharedWindow.membersWithScheduleDataCount} of '
              '${bestSharedWindow.totalMemberCount} members with recorded schedule data.',
      ],
      suggestedActions: const <String>[
        'Review whether this tradition still matters to the family.',
        'Choose a realistic next date.',
        'Confirm the expected participants.',
      ],
      confidence: rhythm.confidence,
      relatedMomentId: moment.id,
      recommendedReminderAt: bestSharedWindow?.startAt,
      recommendedReminderUsesAvailability: bestSharedWindow != null,
    );
  }

  _ReminderChoice? _findPersonalReminderTime(
    FamilyInsightSnapshot snapshot,
    FamilyMoment moment,
  ) {
    final reference = snapshot.generatedAt.toLocal();
    final eventDate = _dateOnly(moment.startAt.toLocal());
    final today = _dateOnly(reference);

    if (!eventDate.isAfter(today)) {
      final candidate = reference.add(const Duration(minutes: 30));

      return candidate.isBefore(moment.startAt.toLocal())
          ? _ReminderChoice(dateTime: candidate, usesAvailability: false)
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
          return _ReminderChoice(
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

    if (!fallback.isBefore(moment.startAt.toLocal())) {
      return null;
    }

    return _ReminderChoice(dateTime: fallback, usesAvailability: false);
  }

  FamilyOverallState _overallState(FamilyInsightSnapshot snapshot) {
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

  ConfidenceLevel _overallConfidence(FamilyInsightSnapshot snapshot) {
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

  String _upcomingHeadline(FamilyMoment moment, int days) {
    if (days < 0) {
      return '${moment.title} needs review';
    }

    if (days == 0) {
      return '${moment.title} is today';
    }

    if (days == 1) {
      return '${moment.title} is tomorrow';
    }

    if (days <= 7) {
      return '${moment.title} is this week';
    }

    if (days <= 14) {
      return '${moment.title} is next week';
    }

    return '${moment.title} is coming up';
  }

  String _momentSummary(FamilyMoment moment) {
    return switch (moment.category) {
      MomentCategory.milestone =>
        'A major family milestone is approaching and may need practical preparation.',
      MomentCategory.care =>
        'This care-related Moment is approaching and may need a personal action.',
      MomentCategory.responsibility =>
        'A family responsibility is approaching and should have a clear owner.',
      MomentCategory.tradition =>
        'This recurring family tradition is approaching.',
      MomentCategory.familyTime => 'This shared family Moment is approaching.',
      MomentCategory.memory => 'This memory-related Moment is approaching.',
    };
  }

  List<String> _actionsForCategory(MomentCategory category) {
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
        'Confirm the next date.',
        'Check the expected participants.',
        'Prepare any required items.',
      ],
      MomentCategory.familyTime => const <String>[
        'Confirm a shared time.',
        'Choose the activity or location.',
        'Send a reminder to participants.',
      ],
      MomentCategory.memory => const <String>[
        'Choose the family note to preserve.',
        'Confirm who was involved.',
        'Review any related saved Memory.',
      ],
    };
  }

  String _daysReason(int days) {
    if (days < 0) {
      return 'The recorded date has passed.';
    }

    if (days == 0) {
      return 'The Moment is today.';
    }

    if (days == 1) {
      return 'The Moment is tomorrow.';
    }

    return 'The Moment is in $days days.';
  }

  int _daysUntil(DateTime reference, DateTime target) {
    return _dateOnly(
      target.toLocal(),
    ).difference(_dateOnly(reference.toLocal())).inDays;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

class _ReminderChoice {
  const _ReminderChoice({
    required this.dateTime,
    required this.usesAvailability,
  });

  final DateTime dateTime;
  final bool usesAvailability;
}
