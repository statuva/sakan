import 'package:flutter/material.dart';

import '../../../shared/models/availability_block.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/rhythm_record.dart';
import '../presentation/calendar_types.dart';
import '../presentation/widgets/calendar_palette.dart';

class CalendarInsightService {
  const CalendarInsightService();

  CalendarRecommendation? buildRecommendation({
    required List<FamilyMoment> moments,
    required Map<String, RhythmRecord> rhythmsByMomentId,
    required List<AvailabilityBlock> availability,
    required List<Member> members,
    required String currentUserId,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final today = DateUtils.dateOnly(referenceNow);

    final upcoming = moments.where((moment) {
      final localStart = moment.startAt.toLocal();
      return !DateUtils.dateOnly(localStart).isBefore(today) &&
          moment.status != MomentStatus.cancelled &&
          moment.status != MomentStatus.completed;
    }).toList();

    upcoming.sort((first, second) {
      final firstRank = _recommendationRank(
        first,
        rhythmsByMomentId[first.id],
        today,
      );
      final secondRank = _recommendationRank(
        second,
        rhythmsByMomentId[second.id],
        today,
      );

      final rankComparison = firstRank.compareTo(secondRank);
      if (rankComparison != 0) {
        return rankComparison;
      }

      final dateComparison = first.startAt.compareTo(second.startAt);
      if (dateComparison != 0) {
        return dateComparison;
      }

      return second.importanceLevel.compareTo(first.importanceLevel);
    });

    FamilyMoment? selected;

    if (upcoming.isNotEmpty) {
      selected = upcoming.first;
    } else {
      final drifting =
          moments.where((moment) {
            final rhythm = rhythmsByMomentId[moment.id];
            return moment.type == MomentType.recurring &&
                rhythm?.status == RhythmStatus.drifting;
          }).toList()..sort(
            (first, second) =>
                second.importanceLevel.compareTo(first.importanceLevel),
          );

      if (drifting.isNotEmpty) {
        selected = drifting.first;
      }
    }

    if (selected == null) {
      return null;
    }

    final selectedMoment = selected;
    final localStart = selectedMoment.startAt.toLocal();
    final daysLeft = DateUtils.dateOnly(localStart).difference(today).inDays;
    final rhythm = rhythmsByMomentId[selectedMoment.id];

    final personalWindow = _findPersonalReminderWindow(
      moment: selectedMoment,
      availability: availability,
      currentUserId: currentUserId,
      now: referenceNow,
    );

    final status = _statusPresentation(moment: selectedMoment, rhythm: rhythm);

    final reasons = <String>[
      if (daysLeft >= 0)
        _daysReason(daysLeft)
      else
        'This recurring moment currently needs review.',
      'It is marked ${selectedMoment.importanceLevel}/5 importance.',
      if (selectedMoment.expectedParticipantIds.contains(currentUserId))
        'You are one of the expected participants.',
      if (personalWindow.usesAvailability)
        'A suitable reminder window was found from your recurring availability.',
      if (rhythm?.status == RhythmStatus.drifting)
        'Its current rhythm status is Drifting.',
    ];

    return CalendarRecommendation(
      moment: selectedMoment,
      title: _recommendationTitle(selectedMoment, daysLeft),
      description: _descriptionForMoment(selectedMoment, daysLeft),
      statusLabel: status.label,
      statusColor: status.color,
      statusSoftColor: status.softColor,
      daysLeft: daysLeft,
      reasons: reasons,
      preparationSteps: _preparationSteps(selectedMoment),
      recommendedReminderAt: personalWindow.dateTime,
      reminderTimeUsesAvailability: personalWindow.usesAvailability,
    );
  }

  CalendarAvailabilityWindow? findBestSharedWindow({
    required List<AvailabilityBlock> availability,
    required List<Member> members,
    DateTime? now,
  }) {
    final activeMembers = members.where((member) => member.isActive).toList();
    if (activeMembers.isEmpty || availability.isEmpty) {
      return null;
    }

    final referenceNow = now ?? DateTime.now();
    final today = DateUtils.dateOnly(referenceNow);
    CalendarAvailabilityWindow? best;

    for (var dayOffset = 0; dayOffset < 10; dayOffset++) {
      final date = today.add(Duration(days: dayOffset));

      for (var start = 16 * 60; start <= 19 * 60; start += 30) {
        final end = start + 120;
        final busyMemberIds = availability
            .where((block) {
              return block.dayOfWeek == date.weekday &&
                  start < block.endMinutes &&
                  end > block.startMinutes;
            })
            .map((block) => block.memberId)
            .toSet();

        final activeIds = activeMembers.map((member) => member.id).toSet();
        final unavailableActiveIds = busyMemberIds.intersection(activeIds);
        final availableCount =
            activeMembers.length - unavailableActiveIds.length;

        final candidate = CalendarAvailabilityWindow(
          date: date,
          startMinutes: start,
          endMinutes: end,
          availableMemberCount: availableCount,
          totalMemberCount: activeMembers.length,
        );

        if (best == null ||
            candidate.availableMemberCount > best.availableMemberCount) {
          best = candidate;
        }

        if (availableCount == activeMembers.length) {
          return candidate;
        }
      }
    }

    return best;
  }

  int _recommendationRank(
    FamilyMoment moment,
    RhythmRecord? rhythm,
    DateTime today,
  ) {
    final days = DateUtils.dateOnly(
      moment.startAt.toLocal(),
    ).difference(today).inDays;

    if ((moment.category == MomentCategory.milestone ||
            moment.category == MomentCategory.care) &&
        days >= 0 &&
        days <= 14) {
      return 0;
    }

    if (rhythm?.status == RhythmStatus.drifting) {
      return 1;
    }

    if (moment.importanceLevel >= 4 && days >= 0 && days <= 21) {
      return 2;
    }

    return 3;
  }

  _ReminderWindow _findPersonalReminderWindow({
    required FamilyMoment moment,
    required List<AvailabilityBlock> availability,
    required String currentUserId,
    required DateTime now,
  }) {
    final today = DateUtils.dateOnly(now);
    final eventDate = DateUtils.dateOnly(moment.startAt.toLocal());

    if (!eventDate.isAfter(today)) {
      return _ReminderWindow(
        dateTime: now.add(const Duration(minutes: 30)),
        usesAvailability: false,
      );
    }

    if (eventDate.difference(today).inDays == 1) {
      var reminder = DateTime(today.year, today.month, today.day, 18);
      if (!reminder.isAfter(now)) {
        reminder = now.add(const Duration(minutes: 30));
      }
      return _ReminderWindow(dateTime: reminder, usesAvailability: false);
    }

    final personalBlocks = availability
        .where((block) => block.memberId == currentUserId)
        .toList();

    final lastSearchDate = eventDate.subtract(const Duration(days: 1));
    final maxSearchDate = today.add(const Duration(days: 7));
    final searchEnd = lastSearchDate.isBefore(maxSearchDate)
        ? lastSearchDate
        : maxSearchDate;

    for (var offset = 1; offset <= 7; offset++) {
      final candidateDate = today.add(Duration(days: offset));
      if (candidateDate.isAfter(searchEnd)) {
        break;
      }

      for (final startMinutes in const <int>[
        16 * 60,
        17 * 60,
        18 * 60,
        19 * 60,
      ]) {
        final endMinutes = startMinutes + 60;
        final overlaps = personalBlocks.any((block) {
          return block.dayOfWeek == candidateDate.weekday &&
              startMinutes < block.endMinutes &&
              endMinutes > block.startMinutes;
        });

        if (!overlaps) {
          return _ReminderWindow(
            dateTime: DateTime(
              candidateDate.year,
              candidateDate.month,
              candidateDate.day,
              startMinutes ~/ 60,
              startMinutes % 60,
            ),
            usesAvailability: personalBlocks.isNotEmpty,
          );
        }
      }
    }

    var fallbackDate = eventDate.subtract(const Duration(days: 2));
    if (!fallbackDate.isAfter(today)) {
      fallbackDate = today.add(const Duration(days: 1));
    }

    return _ReminderWindow(
      dateTime: DateTime(
        fallbackDate.year,
        fallbackDate.month,
        fallbackDate.day,
        18,
      ),
      usesAvailability: false,
    );
  }

  String _recommendationTitle(FamilyMoment moment, int daysLeft) {
    if (daysLeft < 0) {
      return '${moment.title} needs attention';
    }
    if (daysLeft == 0) {
      return '${moment.title} is today';
    }
    if (daysLeft == 1) {
      return '${moment.title} is tomorrow';
    }
    if (daysLeft > 1 && daysLeft <= 7) {
      return '${moment.title} is this week';
    }
    if (daysLeft > 7 && daysLeft <= 14) {
      return '${moment.title} is next week';
    }
    return '${moment.title} is coming up';
  }

  String _descriptionForMoment(FamilyMoment moment, int daysLeft) {
    return switch (moment.category) {
      MomentCategory.milestone =>
        'A major family milestone is approaching. Review the practical preparations while there is still time.',
      MomentCategory.care =>
        'This care-related moment is approaching and may need a personal reminder or preparation action.',
      MomentCategory.responsibility =>
        'A family responsibility is approaching. Confirm the owner, required items, and timing.',
      MomentCategory.tradition =>
        'This recurring family tradition is coming up. Confirm the time and expected participants.',
      MomentCategory.familyTime =>
        'This shared family moment is coming up. A small preparation step can make it easier to follow through.',
      MomentCategory.memory =>
        'This memory-related moment is coming up. Prepare any photos, notes, or family stories you want to preserve.',
    };
  }

  List<String> _preparationSteps(FamilyMoment moment) {
    return switch (moment.category) {
      MomentCategory.milestone => const <String>[
        'Choose or buy the gift.',
        'Prepare a short family message.',
        'Confirm travel and arrival time.',
      ],
      MomentCategory.care => const <String>[
        'Confirm what the person needs.',
        'Prepare a message or gift.',
        'Set a reminder before the event.',
      ],
      MomentCategory.responsibility => const <String>[
        'Confirm who owns the task.',
        'Prepare the required items or documents.',
        'Set a reminder before the deadline.',
      ],
      MomentCategory.tradition => const <String>[
        'Confirm the expected participants.',
        'Check the location and needed items.',
        'Send a family reminder.',
      ],
      MomentCategory.familyTime => const <String>[
        'Confirm the time with the family.',
        'Prepare the activity or location.',
        'Send a reminder to participants.',
      ],
      MomentCategory.memory => const <String>[
        'Choose the photos or keepsakes.',
        'Write a short note about the moment.',
        'Confirm who should be included.',
      ],
    };
  }

  String _daysReason(int daysLeft) {
    if (daysLeft == 0) return 'The moment is today.';
    if (daysLeft == 1) return 'The moment is tomorrow.';
    return 'The moment is in $daysLeft days.';
  }

  _StatusPresentation _statusPresentation({
    required FamilyMoment moment,
    required RhythmRecord? rhythm,
  }) {
    if (moment.type == MomentType.recurring && rhythm != null) {
      return switch (rhythm.status) {
        RhythmStatus.stillLearning => const _StatusPresentation(
          label: 'Still Learning',
          color: CalendarPalette.slate,
          softColor: CalendarPalette.slateSoft,
        ),
        RhythmStatus.stable => const _StatusPresentation(
          label: 'Stable',
          color: CalendarPalette.stable,
          softColor: CalendarPalette.stableSoft,
        ),
        RhythmStatus.drifting => const _StatusPresentation(
          label: 'Drifting',
          color: CalendarPalette.drifting,
          softColor: CalendarPalette.driftingSoft,
        ),
        RhythmStatus.recovering => const _StatusPresentation(
          label: 'Recovering',
          color: CalendarPalette.recovering,
          softColor: CalendarPalette.recoveringSoft,
        ),
        RhythmStatus.strengthening => const _StatusPresentation(
          label: 'Strengthening',
          color: CalendarPalette.strengthening,
          softColor: CalendarPalette.strengtheningSoft,
        ),
      };
    }

    return switch (moment.status) {
      MomentStatus.scheduled => const _StatusPresentation(
        label: 'Upcoming',
        color: CalendarPalette.upcoming,
        softColor: CalendarPalette.upcomingSoft,
      ),
      MomentStatus.active => const _StatusPresentation(
        label: 'Active',
        color: CalendarPalette.strengthening,
        softColor: CalendarPalette.strengtheningSoft,
      ),
      MomentStatus.completed => const _StatusPresentation(
        label: 'Completed',
        color: CalendarPalette.stable,
        softColor: CalendarPalette.stableSoft,
      ),
      MomentStatus.cancelled => const _StatusPresentation(
        label: 'Cancelled',
        color: CalendarPalette.slate,
        softColor: CalendarPalette.slateSoft,
      ),
      MomentStatus.missed => const _StatusPresentation(
        label: 'Missed',
        color: CalendarPalette.missed,
        softColor: CalendarPalette.missedSoft,
      ),
    };
  }
}

class _ReminderWindow {
  const _ReminderWindow({
    required this.dateTime,
    required this.usesAvailability,
  });

  final DateTime dateTime;
  final bool usesAvailability;
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.label,
    required this.color,
    required this.softColor,
  });

  final String label;
  final Color color;
  final Color softColor;
}
