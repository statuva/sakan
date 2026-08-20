import 'package:flutter/material.dart';

import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';

enum CalendarViewMode { month, week, agenda }

enum CalendarMomentFilter { all, traditions, milestones, care, mine }

abstract final class CalendarPalette {
  static const Color background = Color(0xFFF6F1E6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFFBF6EC);

  static const Color ink = Color(0xFF2B241C);
  static const Color inkSoft = Color(0xFF746A5C);

  static const Color forest = Color(0xFF3E5C43);
  static const Color forestDark = Color(0xFF2E4433);
  static const Color forestSoft = Color(0xFFE3EAD9);

  static const Color milestone = Color(0xFFB8863E);
  static const Color milestoneSoft = Color(0xFFF4E8D3);
  static const Color milestoneText = Color(0xFF8C6329);

  static const Color care = Color(0xFFA15F52);
  static const Color careSoft = Color(0xFFF1E0D9);
  static const Color careText = Color(0xFF7C4A40);

  static const Color personal = Color(0xFF5C6B79);
  static const Color personalSoft = Color(0xFFE3E8EB);
  static const Color personalText = Color(0xFF3E4A56);

  static const List<BoxShadow> softShadow = <BoxShadow>[
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> mediumShadow = <BoxShadow>[
    BoxShadow(color: Color(0x1A000000), blurRadius: 28, offset: Offset(0, 10)),
  ];
}

class CalendarCategoryStyle {
  const CalendarCategoryStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.softColor,
    required this.textColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color softColor;
  final Color textColor;
}

CalendarCategoryStyle categoryStyleForMoment(FamilyMoment moment) {
  return categoryStyleForCategory(moment.category);
}

CalendarCategoryStyle categoryStyleForCategory(MomentCategory category) {
  return switch (category) {
    MomentCategory.tradition ||
    MomentCategory.familyTime => const CalendarCategoryStyle(
      label: 'Traditions',
      icon: Icons.eco_outlined,
      color: CalendarPalette.forest,
      softColor: CalendarPalette.forestSoft,
      textColor: CalendarPalette.forestDark,
    ),
    MomentCategory.milestone ||
    MomentCategory.memory => const CalendarCategoryStyle(
      label: 'Milestones',
      icon: Icons.star_border_rounded,
      color: CalendarPalette.milestone,
      softColor: CalendarPalette.milestoneSoft,
      textColor: CalendarPalette.milestoneText,
    ),
    MomentCategory.care => const CalendarCategoryStyle(
      label: 'Care',
      icon: Icons.favorite_border_rounded,
      color: CalendarPalette.care,
      softColor: CalendarPalette.careSoft,
      textColor: CalendarPalette.careText,
    ),
    MomentCategory.responsibility => const CalendarCategoryStyle(
      label: 'Personal',
      icon: Icons.person_outline_rounded,
      color: CalendarPalette.personal,
      softColor: CalendarPalette.personalSoft,
      textColor: CalendarPalette.personalText,
    ),
  };
}

Color filterColor(CalendarMomentFilter filter) {
  return switch (filter) {
    CalendarMomentFilter.all => CalendarPalette.forest,
    CalendarMomentFilter.traditions => CalendarPalette.forest,
    CalendarMomentFilter.milestones => CalendarPalette.milestone,
    CalendarMomentFilter.care => CalendarPalette.care,
    CalendarMomentFilter.mine => CalendarPalette.personal,
  };
}

Color filterSoftColor(CalendarMomentFilter filter) {
  return switch (filter) {
    CalendarMomentFilter.all => CalendarPalette.forestSoft,
    CalendarMomentFilter.traditions => CalendarPalette.forestSoft,
    CalendarMomentFilter.milestones => CalendarPalette.milestoneSoft,
    CalendarMomentFilter.care => CalendarPalette.careSoft,
    CalendarMomentFilter.mine => CalendarPalette.personalSoft,
  };
}

IconData filterIcon(CalendarMomentFilter filter) {
  return switch (filter) {
    CalendarMomentFilter.all => Icons.apps_rounded,
    CalendarMomentFilter.traditions => Icons.eco_outlined,
    CalendarMomentFilter.milestones => Icons.star_border_rounded,
    CalendarMomentFilter.care => Icons.favorite_border_rounded,
    CalendarMomentFilter.mine => Icons.person_outline_rounded,
  };
}

String filterLabel(CalendarMomentFilter filter) {
  return switch (filter) {
    CalendarMomentFilter.all => 'All',
    CalendarMomentFilter.traditions => 'Traditions',
    CalendarMomentFilter.milestones => 'Milestones',
    CalendarMomentFilter.care => 'Care',
    CalendarMomentFilter.mine => 'My Moments',
  };
}

bool matchesCalendarFilter({
  required FamilyMoment moment,
  required CalendarMomentFilter filter,
  required String currentUserId,
}) {
  return switch (filter) {
    CalendarMomentFilter.all => true,
    CalendarMomentFilter.traditions =>
      moment.category == MomentCategory.tradition ||
          moment.category == MomentCategory.familyTime,
    CalendarMomentFilter.milestones =>
      moment.category == MomentCategory.milestone ||
          moment.category == MomentCategory.memory,
    CalendarMomentFilter.care => moment.category == MomentCategory.care,
    CalendarMomentFilter.mine => moment.expectedParticipantIds.contains(
      currentUserId,
    ),
  };
}
