import 'package:flutter/material.dart';

import '../../../shared/models/model_enums.dart';
import '../../calendar/presentation/widgets/calendar_palette.dart';

class TwinStatusVisual {
  const TwinStatusVisual({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;
}

class TwinCategoryVisual {
  const TwinCategoryVisual({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
}

TwinStatusVisual twinRhythmVisual(RhythmStatus status) {
  return switch (status) {
    RhythmStatus.stillLearning => const TwinStatusVisual(
        label: 'Still Learning',
        color: CalendarPalette.slate,
        background: CalendarPalette.slateSoft,
      ),
    RhythmStatus.stable => const TwinStatusVisual(
        label: 'Stable',
        color: CalendarPalette.stable,
        background: CalendarPalette.stableSoft,
      ),
    RhythmStatus.drifting => const TwinStatusVisual(
        label: 'Drifting',
        color: CalendarPalette.drifting,
        background: CalendarPalette.driftingSoft,
      ),
    RhythmStatus.recovering => const TwinStatusVisual(
        label: 'Recovering',
        color: CalendarPalette.recovering,
        background: CalendarPalette.recoveringSoft,
      ),
    RhythmStatus.strengthening => const TwinStatusVisual(
        label: 'Strengthening',
        color: CalendarPalette.strengthening,
        background: CalendarPalette.strengtheningSoft,
      ),
  };
}

TwinCategoryVisual twinCategoryVisual(MomentCategory category) {
  return switch (category) {
    MomentCategory.tradition => const TwinCategoryVisual(
        label: 'Tradition',
        icon: Icons.eco_outlined,
        color: CalendarPalette.forest,
        background: CalendarPalette.forestSoft,
      ),
    MomentCategory.milestone => const TwinCategoryVisual(
        label: 'Milestone',
        icon: Icons.star_border_rounded,
        color: CalendarPalette.milestone,
        background: CalendarPalette.milestoneSoft,
      ),
    MomentCategory.responsibility => const TwinCategoryVisual(
        label: 'Responsibility',
        icon: Icons.task_alt_outlined,
        color: CalendarPalette.mine,
        background: CalendarPalette.mineSoft,
      ),
    MomentCategory.care => const TwinCategoryVisual(
        label: 'Care',
        icon: Icons.favorite_border_rounded,
        color: CalendarPalette.care,
        background: CalendarPalette.careSoft,
      ),
    MomentCategory.familyTime => const TwinCategoryVisual(
        label: 'Family Time',
        icon: Icons.groups_2_outlined,
        color: CalendarPalette.mine,
        background: CalendarPalette.mineSoft,
      ),
    MomentCategory.memory => const TwinCategoryVisual(
        label: 'Memory',
        icon: Icons.auto_stories_outlined,
        color: CalendarPalette.upcoming,
        background: CalendarPalette.upcomingSoft,
      ),
  };
}

String twinConfidenceLabel(ConfidenceLevel confidence) {
  return switch (confidence) {
    ConfidenceLevel.low => 'Low confidence',
    ConfidenceLevel.medium => 'Medium confidence',
    ConfidenceLevel.high => 'High confidence',
  };
}

String twinCategoryLabel(MomentCategory category) {
  return twinCategoryVisual(category).label;
}

IconData twinCategoryIcon(MomentCategory category) {
  return twinCategoryVisual(category).icon;
}

String twinFrequencyLabel(int? days) {
  return switch (days) {
    null => 'Frequency not configured',
    1 => 'Daily',
    7 => 'Weekly',
    14 => 'Every 2 weeks',
    30 => 'Monthly',
    90 => 'Every 3 months',
    365 => 'Yearly',
    _ => 'Every $days days',
  };
}
