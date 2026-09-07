import 'package:flutter_test/flutter_test.dart';
import 'package:sakan/features/weekly_report/domain/family_weekly_report.dart';
import 'package:sakan/features/weekly_report/services/family_weekly_report_builder.dart';
import 'package:sakan/shared/models/family_insight_snapshot.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_instance.dart';
import 'package:sakan/shared/models/rhythm_record.dart';

void main() {
  test('reconciles every occurrence status in the completed week', () {
    final now = DateTime(2026, 9, 7, 9);
    final statuses = MomentInstanceStatus.values;
    final instances = statuses.indexed.map((entry) {
      return _instance(
        id: 'instance-${entry.$1}',
        start: DateTime(2026, 8, 31 + entry.$1, 10),
        status: entry.$2,
        updatedAt: now,
      );
    }).toList();

    final report = FamilyWeeklyReportBuilder.buildLatestCompletedWeek(
      _snapshot(now: now, instances: instances),
      now: now,
    );

    expect(report.weekStart, DateTime(2026, 8, 31));
    expect(report.weekEndExclusive, DateTime(2026, 9, 7));
    expect(report.occurrenceCount, statuses.length);
    expect(report.completedCount, 1);
    expect(report.missedCount, 1);
    expect(report.pendingReviewCount, 4);
    expect(report.cancelledCount, 1);
    expect(report.totalDurationMinutes, isNull);
    expect(report.dailyActivity.last.occurrenceCount, 1);
    expect(
      report.dailyActivity.fold<int>(
        0,
        (total, day) => total + day.occurrenceCount,
      ),
      report.occurrenceCount,
    );
    expect(
      report.dailyActivity.every(
        (day) =>
            day.occurrenceCount ==
            day.completedCount +
                day.missedCount +
                day.pendingReviewCount +
                day.cancelledCount,
      ),
      isTrue,
    );
  });

  test('deduplicates instances and measures only expected participants', () {
    final now = DateTime(2026, 9, 7, 9);
    final start = DateTime(2026, 9, 2, 18);
    final older = _instance(
      id: 'same-id',
      start: start,
      status: MomentInstanceStatus.scheduled,
      updatedAt: DateTime(2026, 9, 2, 12),
    );
    final latest = _instance(
      id: 'same-id',
      start: start,
      status: MomentInstanceStatus.completed,
      updatedAt: DateTime(2026, 9, 2, 20),
      expectedParticipantIds: const ['adult', 'child'],
      confirmedParticipantIds: const ['adult', 'unexpected', 'adult'],
      actualDurationMinutes: 60,
    );

    final report = FamilyWeeklyReportBuilder.buildLatestCompletedWeek(
      _snapshot(now: now, instances: [older, latest]),
      now: now,
    );

    expect(report.occurrenceCount, 1);
    expect(report.completedCount, 1);
    expect(report.participationRate, 0.5);
    expect(report.totalDurationMinutes, 60);
  });

  test('uses actual date for completed occurrences at the week boundary', () {
    final now = DateTime(2026, 9, 7, 9);
    final lateCompletion = _instance(
      id: 'late',
      start: DateTime(2026, 9, 6, 23),
      actualStartAt: DateTime(2026, 9, 7, 0, 5),
      status: MomentInstanceStatus.completed,
      updatedAt: now,
    );

    final report = FamilyWeeklyReportBuilder.buildLatestCompletedWeek(
      _snapshot(now: now, instances: [lateCompletion]),
      now: now,
    );

    expect(report.hasActivity, isFalse);
  });

  test('keeps weekly evidence separate from the current rhythm state', () {
    final now = DateTime(2026, 9, 7, 9);
    final completed = _instance(
      id: 'dinner',
      start: DateTime(2026, 9, 4, 18),
      status: MomentInstanceStatus.completed,
      updatedAt: now,
      actualDurationMinutes: 45,
    );
    final rhythm = RhythmRecord(
      id: 'rhythm-dinner',
      familyId: 'family-1',
      momentId: 'moment-1',
      expectedIntervalDays: 7,
      currentGapDays: 10,
      occurrenceCount: 4,
      status: RhythmStatus.drifting,
      confidence: ConfidenceLevel.medium,
      updatedAt: now,
    );

    final report = FamilyWeeklyReportBuilder.buildLatestCompletedWeek(
      _snapshot(now: now, instances: [completed], rhythms: [rhythm]),
      now: now,
    );
    final pattern = report.momentPatterns.single;

    expect(pattern.effect, WeeklyPatternEffect.supported);
    expect(pattern.rhythmStatus, RhythmStatus.drifting);
    expect(pattern.explanation, contains('current rhythm is drifting'));
    expect(pattern.explanation, isNot(contains('became stable')));
  });

  test('does not create a recurring pattern for a one-time Moment', () {
    final now = DateTime(2026, 9, 7, 9);
    final instance = _instance(
      id: 'graduation',
      start: DateTime(2026, 9, 1, 12),
      status: MomentInstanceStatus.completed,
      updatedAt: now,
      type: MomentType.singular,
    );

    final report = FamilyWeeklyReportBuilder.buildLatestCompletedWeek(
      _snapshot(now: now, instances: [instance]),
      now: now,
    );

    expect(report.completedCount, 1);
    expect(report.momentPatterns, isEmpty);
  });
}

FamilyInsightSnapshot _snapshot({
  required DateTime now,
  required List<MomentInstance> instances,
  List<RhythmRecord> rhythms = const [],
}) {
  return FamilyInsightSnapshot(
    familyId: 'family-1',
    currentUserId: 'adult',
    generatedAt: now,
    members: const [],
    moments: const [],
    instances: instances,
    rhythms: rhythms,
    availability: const [],
    reminders: const [],
    memories: const [],
  );
}

MomentInstance _instance({
  required String id,
  required DateTime start,
  required MomentInstanceStatus status,
  required DateTime updatedAt,
  MomentType type = MomentType.recurring,
  DateTime? actualStartAt,
  int? actualDurationMinutes,
  List<String> expectedParticipantIds = const ['adult'],
  List<String> confirmedParticipantIds = const [],
}) {
  return MomentInstance(
    id: id,
    familyId: 'family-1',
    momentId: 'moment-1',
    titleSnapshot: 'Family Dinner',
    typeSnapshot: type,
    categorySnapshot: MomentCategory.tradition,
    importanceLevelSnapshot: 4,
    expectedParticipantIds: expectedParticipantIds,
    source: MomentInstanceSource.calendar,
    status: status,
    scheduledStartAt: start,
    actualStartAt: actualStartAt,
    actualDurationMinutes: actualDurationMinutes,
    confirmedParticipantIds: confirmedParticipantIds,
    reportedParticipantIds: const [],
    evidenceSignals: const [],
    confirmationLevel: MomentConfirmationLevel.medium,
    createdBy: 'adult',
    createdAt: start,
    updatedAt: updatedAt,
  );
}
