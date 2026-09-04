import 'package:flutter/material.dart';

import '../../../../shared/models/family_moment.dart';
import '../../../../shared/models/model_enums.dart';
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

CalendarStatusStyle calendarOccurrenceStatusStyle(String label) {
  if (label == 'Live now') {
    return const CalendarStatusStyle(
      label: 'Live now',
      color: CalendarPalette.strengthening,
      softColor: CalendarPalette.strengtheningSoft,
    );
  }

  if (label.startsWith('Completed')) {
    return CalendarStatusStyle(
      label: label,
      color: CalendarPalette.stable,
      softColor: CalendarPalette.stableSoft,
    );
  }

  if (label.startsWith('Missed')) {
    return CalendarStatusStyle(
      label: label,
      color: CalendarPalette.missed,
      softColor: CalendarPalette.missedSoft,
    );
  }

  if (label.startsWith('Cancelled')) {
    return CalendarStatusStyle(
      label: label,
      color: CalendarPalette.slate,
      softColor: CalendarPalette.slateSoft,
    );
  }

  if (label == 'Getting ready') {
    return CalendarStatusStyle(
      label: label,
      color: CalendarPalette.forest,
      softColor: CalendarPalette.forestSoft,
    );
  }

  return CalendarStatusStyle(
    label: label,
    color: CalendarPalette.upcoming,
    softColor: CalendarPalette.upcomingSoft,
  );
}
