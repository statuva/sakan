import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/family_moment.dart';
import '../../../../shared/models/model_enums.dart';
import '../../../../shared/models/moment_instance.dart';

IconData momentSessionCategoryIcon(MomentCategory category) {
  return switch (category) {
    MomentCategory.tradition => Icons.eco_outlined,
    MomentCategory.milestone => Icons.star_border_rounded,
    MomentCategory.responsibility => Icons.task_alt_outlined,
    MomentCategory.care => Icons.favorite_border_rounded,
    MomentCategory.familyTime => Icons.groups_2_outlined,
    MomentCategory.memory => Icons.auto_stories_outlined,
  };
}

Color momentSessionCategoryColor(MomentCategory category) {
  return switch (category) {
    MomentCategory.tradition => AppColors.primary,
    MomentCategory.milestone => AppColors.accent,
    MomentCategory.responsibility => AppColors.info,
    MomentCategory.care => AppColors.secondary,
    MomentCategory.familyTime => const Color(0xFF8B6255),
    MomentCategory.memory => AppColors.upcoming,
  };
}

String momentSessionFrequencyLabel(FamilyMoment moment) {
  if (moment.type == MomentType.singular) {
    return 'One-time Moment';
  }

  return switch (moment.expectedIntervalDays) {
    1 => 'Daily',
    7 => 'Weekly',
    14 => 'Every 2 weeks',
    30 => 'Monthly',
    90 => 'Every 3 months',
    365 => 'Yearly',
    final days? => 'Every $days days',
    null => 'Recurring',
  };
}

int momentSessionPlannedDurationMinutes({
  required FamilyMoment moment,
  MomentInstance? instance,
}) {
  final occurrenceStart = instance?.scheduledStartAt.toLocal();
  final occurrenceEnd = instance?.scheduledEndAt?.toLocal();

  if (occurrenceStart != null && occurrenceEnd != null) {
    final minutes = occurrenceEnd.difference(occurrenceStart).inMinutes;

    if (minutes > 0 && minutes <= 8 * 60) {
      return minutes;
    }
  }

  final startMinutes = moment.resolvedPreferredStartMinutes;
  final endMinutes = moment.resolvedPreferredEndMinutes;

  if (endMinutes != null) {
    var minutes = endMinutes - startMinutes;

    if (minutes <= 0) {
      minutes += 24 * 60;
    }

    if (minutes > 0 && minutes <= 8 * 60) {
      return minutes;
    }
  }

  return 60;
}

DateTime momentSessionPlannedStart({
  required FamilyMoment moment,
  MomentInstance? instance,
}) {
  return (instance?.scheduledStartAt ?? moment.startAt).toLocal();
}

DateTime momentSessionPlannedEnd({
  required FamilyMoment moment,
  MomentInstance? instance,
}) {
  final start = momentSessionPlannedStart(moment: moment, instance: instance);
  final occurrenceEnd = instance?.scheduledEndAt?.toLocal();

  if (occurrenceEnd != null && occurrenceEnd.isAfter(start)) {
    return occurrenceEnd;
  }

  return start.add(
    Duration(
      minutes: momentSessionPlannedDurationMinutes(
        moment: moment,
        instance: instance,
      ),
    ),
  );
}

String momentSessionDurationLabel(int minutes) {
  if (minutes < 60) {
    return '$minutes min';
  }

  final hours = minutes ~/ 60;
  final remaining = minutes % 60;

  if (remaining == 0) {
    return hours == 1 ? '1 hour' : '$hours hours';
  }

  return '$hours h $remaining min';
}

String momentSessionDateLabel(DateTime date) {
  final now = DateTime.now();
  final local = date.toLocal();

  if (_sameDate(local, now)) {
    return local.hour >= 17 ? 'Tonight’s' : 'Today’s';
  }

  final tomorrow = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(const Duration(days: 1));

  if (_sameDate(local, tomorrow)) {
    return 'Tomorrow’s';
  }

  return '${DateFormat('EEEE').format(local)}’s';
}

String momentSessionConfirmationLabel(MomentConfirmationLevel level) {
  return switch (level) {
    MomentConfirmationLevel.low => 'Low',
    MomentConfirmationLevel.medium => 'Medium',
    MomentConfirmationLevel.high => 'High',
  };
}

String momentSessionRhythmLabel(RhythmStatus status) {
  return switch (status) {
    RhythmStatus.stillLearning => 'Still Learning',
    RhythmStatus.stable => 'Stable',
    RhythmStatus.drifting => 'Drifting',
    RhythmStatus.recovering => 'Recovering',
    RhythmStatus.strengthening => 'Strengthening',
  };
}

bool _sameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
