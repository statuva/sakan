import '../../../shared/models/model_enums.dart';

enum WeeklyPatternEffect { supported, mixed, underPressure, noNewEvidence }

class WeeklyDayActivity {
  const WeeklyDayActivity({
    required this.date,
    required this.occurrenceCount,
    required this.completedCount,
    required this.missedCount,
    required this.pendingReviewCount,
    required this.cancelledCount,
  });

  final DateTime date;
  final int occurrenceCount;
  final int completedCount;
  final int missedCount;
  final int pendingReviewCount;
  final int cancelledCount;
}

class WeeklyMomentPattern {
  WeeklyMomentPattern({
    required this.momentId,
    required this.title,
    required this.completedCount,
    required this.missedCount,
    required this.pendingReviewCount,
    required this.cancelledCount,
    required this.actualDurationMinutes,
    required this.effect,
    required this.explanation,
    this.rhythmStatus,
    this.rhythmConfidence,
    this.currentGapDays,
    this.expectedIntervalDays,
  });

  final String momentId;
  final String title;
  final int completedCount;
  final int missedCount;
  final int pendingReviewCount;
  final int cancelledCount;
  final int actualDurationMinutes;
  final RhythmStatus? rhythmStatus;
  final ConfidenceLevel? rhythmConfidence;
  final int? currentGapDays;
  final int? expectedIntervalDays;
  final WeeklyPatternEffect effect;
  final String explanation;

  int get resolvedCount => completedCount + missedCount;

  double? get completionRate {
    if (resolvedCount == 0) {
      return null;
    }

    return completedCount / resolvedCount;
  }

}

class FamilyWeeklyReport {
  FamilyWeeklyReport({
    required this.familyId,
    required this.weekStart,
    required this.weekEndExclusive,
    required this.generatedAt,
    required this.occurrenceCount,
    required this.completedCount,
    required this.missedCount,
    required this.pendingReviewCount,
    required this.cancelledCount,
    required this.totalDurationMinutes,
    required this.participationRate,
    required this.headline,
    required this.interpretation,
    required List<WeeklyDayActivity> dailyActivity,
    required List<WeeklyMomentPattern> momentPatterns,
  }) : dailyActivity = List<WeeklyDayActivity>.unmodifiable(dailyActivity),
       momentPatterns = List<WeeklyMomentPattern>.unmodifiable(momentPatterns);

  final String familyId;
  final DateTime weekStart;
  final DateTime weekEndExclusive;
  final DateTime generatedAt;

  final int occurrenceCount;
  final int completedCount;
  final int missedCount;
  final int pendingReviewCount;
  final int cancelledCount;
  final int? totalDurationMinutes;
  final double? participationRate;

  final String headline;
  final String interpretation;

  final List<WeeklyDayActivity> dailyActivity;
  final List<WeeklyMomentPattern> momentPatterns;

  int get resolvedCount => completedCount + missedCount;

  bool get hasActivity => occurrenceCount > 0;

  double? get completionRate {
    if (resolvedCount == 0) {
      return null;
    }

    return completedCount / resolvedCount;
  }

  Map<String, dynamic> toAiPayload() {
    final boundedPatterns = momentPatterns.take(12).toList(growable: false);
    return <String, dynamic>{
      'weekStart': weekStart.toUtc().toIso8601String(),
      'weekEndExclusive': weekEndExclusive.toUtc().toIso8601String(),
      'occurrenceCount': occurrenceCount,
      'completedCount': completedCount,
      'missedCount': missedCount,
      'pendingReviewCount': pendingReviewCount,
      'cancelledCount': cancelledCount,
      'totalDurationMinutes': totalDurationMinutes,
      'participationRate': participationRate,
      'completionRate': completionRate,
      'baselineHeadline': headline,
      'baselineInterpretation': interpretation,
      'dailyActivity': dailyActivity
          .map(
            (day) => <String, dynamic>{
              'date': day.date.toIso8601String(),
              'occurrenceCount': day.occurrenceCount,
              'completedCount': day.completedCount,
              'missedCount': day.missedCount,
              'pendingReviewCount': day.pendingReviewCount,
              'cancelledCount': day.cancelledCount,
            },
          )
          .toList(growable: false),
      'momentPatterns': boundedPatterns
          .map(
            (pattern) => <String, dynamic>{
              'momentId': pattern.momentId,
              'title': pattern.title,
              'completedCount': pattern.completedCount,
              'missedCount': pattern.missedCount,
              'pendingReviewCount': pattern.pendingReviewCount,
              'cancelledCount': pattern.cancelledCount,
              'recordedDurationMinutes': pattern.actualDurationMinutes > 0
                  ? pattern.actualDurationMinutes
                  : null,
              'completionRate': pattern.completionRate,
              'currentRhythmStatus': pattern.rhythmStatus?.name,
              'rhythmConfidence': pattern.rhythmConfidence?.name,
              'currentGapDays': pattern.currentGapDays,
              'expectedIntervalDays': pattern.expectedIntervalDays,
              'weeklyEffect': pattern.effect.name,
              'baselineExplanation': pattern.explanation,
            },
          )
          .toList(growable: false),
      'omittedPatternCount': momentPatterns.length - boundedPatterns.length,
      'limitations': const <String>[
        'Unresolved occurrences are not missed occurrences.',
        'Null duration or participation means not recorded, not zero.',
        'Weekly evidence and the current all-history rhythm are separate facts.',
        'Projected recurring occurrences are expectations, not observed events.',
      ],
    };
  }
}
