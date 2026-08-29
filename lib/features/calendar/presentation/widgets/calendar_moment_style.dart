import 'package:flutter/material.dart';

import '../../../../shared/models/family_moment.dart';
import '../../../../shared/models/model_enums.dart';
import '../../../../shared/models/rhythm_record.dart';
import 'calendar_palette.dart';

class CalendarMomentStyle {
  const CalendarMomentStyle({
    required this.color,
    required this.softColor,
    required this.icon,
    required this.label,
  });

  final Color color;
  final Color softColor;
  final IconData icon;
  final String label;
}

CalendarMomentStyle calendarMomentStyle(
  FamilyMoment moment, {
  required String currentUserId,
}) {
  if (moment.expectedParticipantIds.length == 1 &&
      moment.expectedParticipantIds.contains(currentUserId)) {
    return const CalendarMomentStyle(
      color: CalendarPalette.mine,
      softColor: CalendarPalette.mineSoft,
      icon: Icons.person_outline_rounded,
      label: 'My Moment',
    );
  }

  if (moment.category == MomentCategory.milestone) {
    return const CalendarMomentStyle(
      color: CalendarPalette.milestone,
      softColor: CalendarPalette.milestoneSoft,
      icon: Icons.star_border_rounded,
      label: 'Milestone',
    );
  }

  if (moment.category == MomentCategory.care ||
      moment.category == MomentCategory.responsibility) {
    return const CalendarMomentStyle(
      color: CalendarPalette.care,
      softColor: CalendarPalette.careSoft,
      icon: Icons.favorite_border_rounded,
      label: 'Care',
    );
  }

  return const CalendarMomentStyle(
    color: CalendarPalette.forest,
    softColor: CalendarPalette.forestSoft,
    icon: Icons.eco_outlined,
    label: 'Tradition',
  );
}

class CalendarStatusStyle {
  const CalendarStatusStyle({
    required this.label,
    required this.color,
    required this.softColor,
  });

  final String label;
  final Color color;
  final Color softColor;
}

CalendarStatusStyle calendarStatusStyle({
  required FamilyMoment moment,
  RhythmRecord? rhythm,
}) {
  // Concrete occurrence outcomes always outrank the reusable rhythm label.
  // This prevents a completed recurring occurrence from appearing merely as
  // "Stable" instead of "Completed" on the Calendar.
  if (moment.status != MomentStatus.scheduled) {
    return switch (moment.status) {
      MomentStatus.active => const CalendarStatusStyle(
        label: 'Live',
        color: CalendarPalette.strengthening,
        softColor: CalendarPalette.strengtheningSoft,
      ),
      MomentStatus.completed => const CalendarStatusStyle(
        label: 'Completed',
        color: CalendarPalette.stable,
        softColor: CalendarPalette.stableSoft,
      ),
      MomentStatus.cancelled => const CalendarStatusStyle(
        label: 'Cancelled',
        color: CalendarPalette.slate,
        softColor: CalendarPalette.slateSoft,
      ),
      MomentStatus.missed => const CalendarStatusStyle(
        label: 'Missed',
        color: CalendarPalette.missed,
        softColor: CalendarPalette.missedSoft,
      ),
      MomentStatus.scheduled => throw StateError('Unreachable status.'),
    };
  }

  if (moment.type == MomentType.recurring && rhythm != null) {
    return switch (rhythm.status) {
      RhythmStatus.stillLearning => const CalendarStatusStyle(
        label: 'Still Learning',
        color: CalendarPalette.slate,
        softColor: CalendarPalette.slateSoft,
      ),
      RhythmStatus.stable => const CalendarStatusStyle(
        label: 'Stable',
        color: CalendarPalette.stable,
        softColor: CalendarPalette.stableSoft,
      ),
      RhythmStatus.drifting => const CalendarStatusStyle(
        label: 'Drifting',
        color: CalendarPalette.drifting,
        softColor: CalendarPalette.driftingSoft,
      ),
      RhythmStatus.recovering => const CalendarStatusStyle(
        label: 'Recovering',
        color: CalendarPalette.recovering,
        softColor: CalendarPalette.recoveringSoft,
      ),
      RhythmStatus.strengthening => const CalendarStatusStyle(
        label: 'Strengthening',
        color: CalendarPalette.strengthening,
        softColor: CalendarPalette.strengtheningSoft,
      ),
    };
  }

  return const CalendarStatusStyle(
    label: 'Upcoming',
    color: CalendarPalette.upcoming,
    softColor: CalendarPalette.upcomingSoft,
  );
}
