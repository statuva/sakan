import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/features/digital_twin/domain/twin_simulation_result.dart';
import 'package:sakan/features/digital_twin/domain/twin_simulation_scenario.dart';
import 'package:sakan/features/digital_twin/services/digital_twin_simulation_service.dart';
import 'package:sakan/shared/models/availability_block.dart';
import 'package:sakan/shared/models/family_insight_report.dart';
import 'package:sakan/shared/models/family_insight_snapshot.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_instance.dart';
import 'package:sakan/shared/models/rhythm_record.dart';

void main() {
  const service = DigitalTwinSimulationService();
  final now = DateTime(2026, 9, 1, 10);

  test('adding a participant changes only the simulated Moment', () {
    final report = _report(now: now, status: RhythmStatus.drifting);
    final original = report.snapshot.momentById('friday-lunch')!;

    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'add-grandma',
        type: TwinSimulationType.addParticipant,
        targetMomentId: 'friday-lunch',
        participantIds: <String>['grandma'],
        scope: TwinSimulationScope.futureOccurrences,
      ),
    );

    final simulated = result.momentById('friday-lunch')!;
    final pattern = result.patternForMoment('friday-lunch')!;

    expect(original.expectedParticipantIds, isNot(contains('grandma')));
    expect(simulated.expectedParticipantIds, contains('grandma'));
    expect(result.changedMemberIds, contains('grandma'));
    expect(pattern.currentStatus, RhythmStatus.drifting);
    expect(pattern.projectedStatus, RhythmStatus.drifting);
  });

  test('assuming a completed drifting occurrence projects recovery', () {
    final report = _report(now: now, status: RhythmStatus.drifting);

    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'completed-next',
        type: TwinSimulationType.assumeNextCompleted,
        targetMomentId: 'friday-lunch',
        assumedDurationMinutes: 60,
      ),
    );

    final pattern = result.patternForMoment('friday-lunch')!;

    expect(pattern.currentStatus, RhythmStatus.drifting);
    expect(pattern.projectedStatus, RhythmStatus.recovering);
    expect(pattern.direction, SimulationDirection.improving);
  });

  test('assuming a missed stable occurrence projects drifting', () {
    final report = _report(now: now, status: RhythmStatus.stable);

    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'missed-next',
        type: TwinSimulationType.assumeNextMissed,
        targetMomentId: 'friday-lunch',
      ),
    );

    final pattern = result.patternForMoment('friday-lunch')!;

    expect(pattern.currentStatus, RhythmStatus.stable);
    expect(pattern.projectedStatus, RhythmStatus.drifting);
    expect(pattern.direction, SimulationDirection.increasedRisk);
  });

  test('a structured new Moment appears as hypothetical Still Learning', () {
    final report = _report(now: now, status: RhythmStatus.stable);

    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'family-walk',
        type: TwinSimulationType.createMoment,
        newTitle: 'Family Walk',
        newCategory: MomentCategory.familyTime,
        newIntervalDays: 30,
        newStartMinutes: 18 * 60,
        newIsDayFlexible: true,
        participantIds: <String>['adult', 'child', 'grandma'],
        assumedDurationMinutes: 60,
      ),
    );

    final newMoment = result.simulatedMoments.firstWhere(
      (moment) => moment.title == 'Family Walk',
    );
    final pattern = result.patternForMoment(newMoment.id)!;

    expect(result.hypotheticalMomentIds, contains(newMoment.id));
    expect(pattern.isHypothetical, isTrue);
    expect(pattern.projectedStatus, RhythmStatus.stillLearning);
    expect(report.snapshot.momentById(newMoment.id), isNull);
  });

  test('moving a conflicting time projects an easier schedule', () {
    final report = _report(
      now: now,
      status: RhythmStatus.drifting,
      includeFridayConflict: true,
    );

    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'move-lunch',
        type: TwinSimulationType.changeTime,
        targetMomentId: 'friday-lunch',
        newStartMinutes: 20 * 60,
        scope: TwinSimulationScope.futureOccurrences,
      ),
    );

    final pattern = result.patternForMoment('friday-lunch')!;

    expect(pattern.direction, SimulationDirection.improving);
    expect(pattern.currentConflictCount, greaterThan(0));
    expect(pattern.projectedConflictCount, 0);
    expect(pattern.projectedStatus, RhythmStatus.recovering);
  });
}

FamilyInsightReport _report({
  required DateTime now,
  required RhythmStatus status,
  bool includeFridayConflict = false,
}) {
  final moment = FamilyMoment(
    id: 'friday-lunch',
    familyId: 'family-1',
    title: 'Friday Lunch',
    type: MomentType.recurring,
    category: MomentCategory.tradition,
    importanceLevel: 5,
    expectedParticipantIds: const <String>['adult', 'child'],
    startAt: DateTime(2026, 9, 4, 18),
    endAt: DateTime(2026, 9, 4, 19),
    expectedIntervalDays: 7,
    preferredStartMinutes: 18 * 60,
    preferredEndMinutes: 19 * 60,
    preferredWeekday: DateTime.friday,
    evidenceType: EvidenceType.manual,
    status: MomentStatus.scheduled,
    createdBy: 'adult',
    createdAt: now.subtract(const Duration(days: 60)),
    updatedAt: now,
  );

  final members = <Member>[
    Member(
      id: 'adult',
      familyId: 'family-1',
      displayName: 'Sara',
      role: FamilyRole.adult,
      ageGroup: AgeGroup.adult,
      interests: const <String>[],
      preferredDays: const <int>[],
      isActive: true,
      joinedAt: now.subtract(const Duration(days: 90)),
      updatedAt: now,
    ),
    Member(
      id: 'child',
      familyId: 'family-1',
      displayName: 'Ali',
      role: FamilyRole.child,
      ageGroup: AgeGroup.child,
      interests: const <String>[],
      preferredDays: const <int>[],
      isActive: true,
      joinedAt: now.subtract(const Duration(days: 80)),
      updatedAt: now,
    ),
    Member(
      id: 'grandma',
      familyId: 'family-1',
      displayName: 'Grandma',
      role: FamilyRole.adult,
      ageGroup: AgeGroup.senior,
      interests: const <String>[],
      preferredDays: const <int>[],
      isActive: true,
      joinedAt: now.subtract(const Duration(days: 70)),
      updatedAt: now,
    ),
  ];

  final completed = <MomentInstance>[
    _completedInstance(
      id: 'lunch-1',
      moment: moment,
      start: DateTime(2026, 8, 14, 18),
    ),
    _completedInstance(
      id: 'lunch-2',
      moment: moment,
      start: DateTime(2026, 8, 21, 18),
    ),
    _completedInstance(
      id: 'lunch-3',
      moment: moment,
      start: DateTime(2026, 8, 28, 18),
    ),
  ];

  final rhythm = RhythmRecord(
    id: 'friday-lunch',
    familyId: 'family-1',
    momentId: 'friday-lunch',
    expectedIntervalDays: 7,
    lastOccurrenceAt: completed.last.effectiveStartAt,
    currentGapDays: 4,
    occurrenceCount: completed.length,
    status: status,
    confidence: ConfidenceLevel.medium,
    updatedAt: now,
  );

  final availability = includeFridayConflict
      ? <AvailabilityBlock>[
          AvailabilityBlock(
            id: 'adult-work',
            familyId: 'family-1',
            memberId: 'adult',
            repeatDays: const <int>[DateTime.friday],
            startMinutes: 17 * 60 + 30,
            endMinutes: 19 * 60 + 30,
            isRecurring: true,
            updatedAt: now,
          ),
        ]
      : const <AvailabilityBlock>[];

  final snapshot = FamilyInsightSnapshot(
    familyId: 'family-1',
    currentUserId: 'adult',
    generatedAt: now,
    members: members,
    moments: <FamilyMoment>[moment],
    instances: completed,
    rhythms: <RhythmRecord>[rhythm],
    availability: availability,
    reminders: const [],
    memories: const [],
  );

  return FamilyInsightReport(
    snapshot: snapshot,
    overallState: FamilyOverallState.stable,
    overallConfidence: ConfidenceLevel.medium,
    primaryInsight: null,
    secondaryInsights: const [],
    bestSharedWindow: null,
  );
}

MomentInstance _completedInstance({
  required String id,
  required FamilyMoment moment,
  required DateTime start,
}) {
  return MomentInstance(
    id: id,
    familyId: moment.familyId,
    momentId: moment.id,
    titleSnapshot: moment.title,
    typeSnapshot: moment.type,
    categorySnapshot: moment.category,
    importanceLevelSnapshot: moment.importanceLevel,
    expectedParticipantIds: moment.expectedParticipantIds,
    source: MomentInstanceSource.calendar,
    status: MomentInstanceStatus.completed,
    scheduledStartAt: start,
    scheduledEndAt: start.add(const Duration(hours: 1)),
    actualStartAt: start,
    actualEndAt: start.add(const Duration(hours: 1)),
    actualDurationMinutes: 60,
    confirmedParticipantIds: const <String>['adult', 'child'],
    reportedParticipantIds: const <String>[],
    evidenceSignals: const <MomentEvidenceSignal>[
      MomentEvidenceSignal.manualCheckIn,
      MomentEvidenceSignal.durationRecorded,
    ],
    confirmationLevel: MomentConfirmationLevel.high,
    createdBy: 'adult',
    createdAt: start,
    updatedAt: start.add(const Duration(hours: 1)),
  );
}
