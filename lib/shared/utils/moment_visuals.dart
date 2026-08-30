import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_colors.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/rhythm_record.dart';

Color momentTypeColor(MomentType type) {
  return switch (type) {
    MomentType.recurring => AppColors.primary,

    MomentType.singular => AppColors.upcoming,
  };
}

Color momentCategoryColor(MomentCategory category) {
  return switch (category) {
    MomentCategory.tradition => AppColors.primary,

    MomentCategory.milestone => AppColors.upcoming,

    MomentCategory.responsibility => AppColors.accent,

    MomentCategory.care => AppColors.secondary,

    MomentCategory.familyTime => AppColors.info,

    MomentCategory.memory => AppColors.recovering,
  };
}

Color momentStatusColor(MomentStatus status) {
  return switch (status) {
    MomentStatus.scheduled => AppColors.upcoming,

    MomentStatus.active => AppColors.strengthening,

    MomentStatus.completed => AppColors.stable,

    MomentStatus.cancelled => AppColors.stillLearning,

    MomentStatus.missed => AppColors.error,
  };
}

Color rhythmStatusColor(RhythmStatus status) {
  return switch (status) {
    RhythmStatus.stillLearning => AppColors.stillLearning,

    RhythmStatus.stable => AppColors.stable,

    RhythmStatus.drifting => AppColors.drifting,

    RhythmStatus.recovering => AppColors.recovering,

    RhythmStatus.strengthening => AppColors.strengthening,
  };
}

String momentTypeLabel(MomentType type) {
  return switch (type) {
    MomentType.recurring => 'Recurring',

    MomentType.singular => 'One-time',
  };
}

String momentCategoryLabel(MomentCategory category) {
  return switch (category) {
    MomentCategory.tradition => 'Tradition',

    MomentCategory.milestone => 'Milestone',

    MomentCategory.responsibility => 'Responsibility',

    MomentCategory.care => 'Care',

    MomentCategory.familyTime => 'Family Time',

    MomentCategory.memory => 'Memory',
  };
}

String momentStatusLabel(MomentStatus status) {
  return switch (status) {
    MomentStatus.scheduled => 'Upcoming',

    MomentStatus.active => 'Active',

    MomentStatus.completed => 'Completed',

    MomentStatus.cancelled => 'Cancelled',

    MomentStatus.missed => 'Missed',
  };
}

String rhythmStatusLabel(RhythmStatus status) {
  return switch (status) {
    RhythmStatus.stillLearning => 'Still Learning',

    RhythmStatus.stable => 'Stable',

    RhythmStatus.drifting => 'Drifting',

    RhythmStatus.recovering => 'Recovering',

    RhythmStatus.strengthening => 'Strengthening',
  };
}

String evidenceTypeLabel(EvidenceType evidenceType) {
  return switch (evidenceType) {
    EvidenceType.scheduledOnly => 'Scheduled only',

    EvidenceType.userConfirmed => 'User confirmation',

    EvidenceType.photoAttached => 'Photo or memory',

    EvidenceType.manual => 'Manual confirmation',
  };
}

String momentOverviewStatusLabel({
  required FamilyMoment moment,

  RhythmRecord? rhythm,
}) {
  if (moment.type == MomentType.recurring && rhythm != null) {
    return rhythmStatusLabel(rhythm.status);
  }

  return momentStatusLabel(moment.status);
}

Color momentOverviewStatusColor({
  required FamilyMoment moment,

  RhythmRecord? rhythm,
}) {
  if (moment.type == MomentType.recurring && rhythm != null) {
    return rhythmStatusColor(rhythm.status);
  }

  return momentStatusColor(moment.status);
}
