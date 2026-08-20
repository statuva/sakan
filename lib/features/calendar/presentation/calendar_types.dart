import 'package:flutter/material.dart';

import '../../../shared/models/family_moment.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/rhythm_record.dart';

import 'widgets/calendar_palette.dart';

enum CalendarViewMode { month, week, agenda }

enum CalendarFilter { tradition, milestone, care, mine }

class CalendarFilterDefinition {
  const CalendarFilterDefinition({
    required this.filter,
    required this.label,
    required this.icon,
    required this.color,
    required this.softColor,
  });

  final CalendarFilter filter;
  final String label;
  final IconData icon;
  final Color color;
  final Color softColor;
}

const calendarFilterDefinitions = <CalendarFilterDefinition>[
  CalendarFilterDefinition(
    filter: CalendarFilter.tradition,
    label: 'Tradition',
    icon: Icons.eco_outlined,
    color: CalendarPalette.forest,
    softColor: CalendarPalette.forestSoft,
  ),
  CalendarFilterDefinition(
    filter: CalendarFilter.milestone,
    label: 'Milestone',
    icon: Icons.star_border_rounded,
    color: CalendarPalette.milestone,
    softColor: CalendarPalette.milestoneSoft,
  ),
  CalendarFilterDefinition(
    filter: CalendarFilter.care,
    label: 'Care',
    icon: Icons.favorite_border_rounded,
    color: CalendarPalette.care,
    softColor: CalendarPalette.careSoft,
  ),
  CalendarFilterDefinition(
    filter: CalendarFilter.mine,
    label: 'My Moments',
    icon: Icons.person_outline_rounded,
    color: CalendarPalette.mine,
    softColor: CalendarPalette.mineSoft,
  ),
];

class CalendarAvailabilityWindow {
  const CalendarAvailabilityWindow({
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.availableMemberCount,
    required this.totalMemberCount,
  });

  final DateTime date;
  final int startMinutes;
  final int endMinutes;
  final int availableMemberCount;
  final int totalMemberCount;
}

class CalendarRecommendation {
  const CalendarRecommendation({
    required this.moment,
    required this.title,
    required this.description,
    required this.statusLabel,
    required this.statusColor,
    required this.statusSoftColor,
    required this.daysLeft,
    required this.reasons,
    required this.preparationSteps,
    required this.recommendedReminderAt,
    required this.reminderTimeUsesAvailability,
  });

  final FamilyMoment moment;
  final String title;
  final String description;
  final String statusLabel;
  final Color statusColor;
  final Color statusSoftColor;
  final int daysLeft;
  final List<String> reasons;
  final List<String> preparationSteps;
  final DateTime recommendedReminderAt;
  final bool reminderTimeUsesAvailability;
}

class CalendarDataSnapshot {
  const CalendarDataSnapshot({
    required this.moments,
    required this.rhythmsByMomentId,
    required this.members,
  });

  final List<FamilyMoment> moments;
  final Map<String, RhythmRecord> rhythmsByMomentId;
  final List<Member> members;
}
