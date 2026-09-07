import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/features/digital_twin/domain/twin_simulation_result.dart';
import 'package:sakan/features/digital_twin/domain/twin_simulation_scenario.dart';
import 'package:sakan/features/digital_twin/services/digital_twin_simulation_service.dart';
import 'package:sakan/features/digital_twin/services/simulation_moment_draft_service.dart';
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

  test('adding a participant to an early rhythm explains shared value', () {
    final report = _report(
      now: now,
      status: RhythmStatus.stillLearning,
      completedCount: 1,
    );
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'add-grandma-early',
        type: TwinSimulationType.addParticipant,
        targetMomentId: 'friday-lunch',
        participantIds: <String>['grandma'],
        scope: TwinSimulationScope.futureOccurrences,
      ),
    );
    final pattern = result.patternForMoment('friday-lunch')!;

    expect(pattern.summary, contains('shared meal'));
    expect(pattern.summary, contains('more shared Moment'));
    expect(result.shouldLeadWithDeterministicBenefit, isTrue);
    expect(result.shouldUseDeterministicNarrative, isTrue);
  });

  test('adding a participant with a known conflict is not promoted', () {
    final report = _report(
      now: now,
      status: RhythmStatus.stillLearning,
      completedCount: 1,
      includeGrandmaFridayConflict: true,
    );
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'add-busy-grandma',
        type: TwinSimulationType.addParticipant,
        targetMomentId: 'friday-lunch',
        participantIds: <String>['grandma'],
        scope: TwinSimulationScope.futureOccurrences,
      ),
    );
    final pattern = result.patternForMoment('friday-lunch')!;

    expect(pattern.currentConflictCount, isNull);
    expect(pattern.projectedConflictCount, greaterThan(0));
    expect(pattern.direction, SimulationDirection.increasedRisk);
    expect(pattern.summary, contains('recorded schedule conflict'));
    expect(pattern.summary, isNot(contains('more shared Moment')));
    expect(result.shouldLeadWithDeterministicBenefit, isFalse);
    expect(result.shouldUseDeterministicNarrative, isTrue);
  });

  test('a free added participant is not blamed for existing conflicts', () {
    final report = _report(
      now: now,
      status: RhythmStatus.stillLearning,
      completedCount: 1,
      includeFridayConflict: true,
      includeGrandmaClearSchedule: true,
    );
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'add-free-grandma',
        type: TwinSimulationType.addParticipant,
        targetMomentId: 'friday-lunch',
        participantIds: <String>['grandma'],
        scope: TwinSimulationScope.futureOccurrences,
      ),
    );
    final pattern = result.patternForMoment('friday-lunch')!;

    expect(pattern.currentConflictCount, greaterThan(0));
    expect(pattern.projectedConflictCount, pattern.currentConflictCount);
    expect(pattern.direction, SimulationDirection.unchanged);
    expect(pattern.summary, isNot(contains('review the time before adding them')));
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
        scope: TwinSimulationScope.futureOccurrences,
        assumedDurationMinutes: 60,
      ),
    );

    final newMoment = result.simulatedMoments.firstWhere(
      (moment) => moment.title == 'Family Walk',
    );
    final pattern = result.patternForMoment(newMoment.id)!;

    expect(result.hypotheticalMomentIds, contains(newMoment.id));
    expect(pattern.isHypothetical, isTrue);
    expect(pattern.isOneTimeProjection, isFalse);
    expect(pattern.projectedStatus, RhythmStatus.stillLearning);
    expect(pattern.summary, contains('family walk could add relaxed time'));
    expect(result.familySummary, contains('begins as Still Learning'));
    expect(result.familySummary, contains('add it as a Moment'));
    expect(result.familySummary, isNot(contains('cannot project')));
    expect(result.familyThemes, contains('Confirm family availability'));
    expect(result.shouldLeadWithDeterministicBenefit, isTrue);
    expect(report.snapshot.momentById(newMoment.id), isNull);
  });

  test('a useful Still Learning trial explains benefit before evidence', () {
    final report = _report(
      now: now,
      status: RhythmStatus.stillLearning,
      completedCount: 1,
    );

    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'complete-early-lunch',
        type: TwinSimulationType.assumeNextCompleted,
        targetMomentId: 'friday-lunch',
        assumedDurationMinutes: 60,
      ),
    );
    final pattern = result.patternForMoment('friday-lunch')!;

    expect(pattern.currentStatus, RhythmStatus.stillLearning);
    expect(pattern.projectedStatus, RhythmStatus.stillLearning);
    expect(pattern.summary, contains('shared meal'));
    expect(pattern.summary, contains('Completing and recording'));
    expect(pattern.summary, isNot(contains('toward Projected Still Learning')));
    expect(result.familySummary, contains('potential benefit'));
    expect(result.familyThemes, contains('Benefit can be tested'));
    expect(result.shouldLeadWithDeterministicBenefit, isTrue);
  });

  test('a missed early occurrence stays factual instead of persuasive', () {
    final report = _report(
      now: now,
      status: RhythmStatus.stillLearning,
      completedCount: 1,
    );

    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'miss-early-lunch',
        type: TwinSimulationType.assumeNextMissed,
        targetMomentId: 'friday-lunch',
      ),
    );
    final pattern = result.patternForMoment('friday-lunch')!;

    expect(pattern.summary, contains('add no completed evidence'));
    expect(result.familySummary, pattern.summary);
    expect(result.familyThemes, isNot(contains('Benefit can be tested')));
    expect(result.shouldLeadWithDeterministicBenefit, isFalse);
    expect(result.shouldUseDeterministicNarrative, isTrue);
  });

  test('a missed drifting occurrence cannot be replaced by AI copy', () {
    final report = _report(now: now, status: RhythmStatus.drifting);
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'miss-drifting-lunch',
        type: TwinSimulationType.assumeNextMissed,
        targetMomentId: 'friday-lunch',
      ),
    );
    final pattern = result.patternForMoment('friday-lunch')!;

    expect(pattern.projectedStatus, RhythmStatus.drifting);
    expect(pattern.direction, SimulationDirection.unchanged);
    expect(result.shouldLeadWithDeterministicBenefit, isFalse);
    expect(result.shouldUseDeterministicNarrative, isTrue);
  });

  test('a one-time simulation becomes a singular creation draft', () {
    final report = _report(now: now, status: RhythmStatus.stable);
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'picnic-this-weekend',
        type: TwinSimulationType.createMoment,
        newTitle: 'Family Picnic',
        newCategory: MomentCategory.familyTime,
        newIntervalDays: 7,
        newStartMinutes: 16 * 60,
        newWeekday: DateTime.saturday,
        participantIds: <String>['adult', 'child'],
        scope: TwinSimulationScope.nextOccurrence,
        assumedDurationMinutes: 90,
      ),
    );

    final simulated = result.creatableMoment!;
    final pattern = result.patternForMoment(simulated.id)!;
    final draft = SimulationMomentDraftService.build(result);

    expect(simulated.type, MomentType.recurring);
    expect(pattern.isOneTimeProjection, isTrue);
    expect(pattern.summary, contains('unhurried time away from routines'));
    expect(result.familySummary, contains('one planned experience'));
    expect(result.familySummary, isNot(contains('no real rhythm exists')));
    expect(result.shouldUseDeterministicNarrative, isTrue);
    expect(draft.type, MomentType.singular);
    expect(draft.startAt, simulated.startAt);
    expect(draft.endAt, simulated.endAt);
    expect(draft.expectedIntervalDays, isNull);
    expect(draft.preferredStartMinutes, isNull);
    expect(draft.preferredEndMinutes, isNull);
    expect(draft.preferredWeekday, isNull);
    expect(draft.preferredDayOfMonth, isNull);
    expect(draft.preferredMonth, isNull);
    expect(draft.isDayFlexible, isFalse);
  });

  test('a repeating simulation keeps an exact recurring creation draft', () {
    final report = _report(now: now, status: RhythmStatus.stable);
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'weekly-walk',
        type: TwinSimulationType.createMoment,
        newTitle: 'Family Walk',
        newCategory: MomentCategory.familyTime,
        newIntervalDays: 7,
        newStartMinutes: 18 * 60,
        newWeekday: DateTime.friday,
        participantIds: <String>['adult', 'child'],
        scope: TwinSimulationScope.futureOccurrences,
        assumedDurationMinutes: 60,
      ),
    );

    final draft = SimulationMomentDraftService.build(result);

    expect(draft.type, MomentType.recurring);
    expect(draft.expectedIntervalDays, 7);
    expect(draft.preferredStartMinutes, 18 * 60);
    expect(draft.preferredEndMinutes, 19 * 60);
    expect(draft.preferredWeekday, DateTime.friday);
    expect(draft.isDayFlexible, isFalse);
  });

  test('a useful idea with a recorded conflict recommends another time', () {
    final report = _report(
      now: now,
      status: RhythmStatus.stable,
      includeFridayConflict: true,
    );
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'conflicting-picnic',
        type: TwinSimulationType.createMoment,
        newTitle: 'Family Picnic',
        newCategory: MomentCategory.familyTime,
        newIntervalDays: 7,
        newStartMinutes: 18 * 60,
        newWeekday: DateTime.friday,
        participantIds: <String>['adult', 'child'],
        scope: TwinSimulationScope.nextOccurrence,
        assumedDurationMinutes: 60,
      ),
    );
    final pattern = result.patternForMoment(result.creatableMoment!.id)!;

    expect(pattern.projectedConflictCount, greaterThan(0));
    expect(pattern.summary, startsWith('This time has'));
    expect(pattern.cardSubtitle, 'New idea · choose another time');
    expect(pattern.summary, contains('unhurried time away from routines'));
    expect(result.familySummary, startsWith('This time has'));
    expect(result.familySummary, contains('Choose a clear time'));
    expect(result.familyThemes, contains('Schedule conflict · choose another time'));
    expect(result.shouldLeadWithDeterministicBenefit, isFalse);
    expect(result.shouldUseDeterministicNarrative, isTrue);
  });

  test('partial schedule coverage does not claim a conflict-free time', () {
    final report = _report(
      now: now,
      status: RhythmStatus.stable,
      includePartialClearSchedule: true,
    );
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'partially-covered-picnic',
        type: TwinSimulationType.createMoment,
        newTitle: 'Family Picnic',
        newCategory: MomentCategory.familyTime,
        newIntervalDays: 7,
        newStartMinutes: 18 * 60,
        newWeekday: DateTime.friday,
        participantIds: <String>['adult', 'child'],
        scope: TwinSimulationScope.nextOccurrence,
        assumedDurationMinutes: 60,
      ),
    );
    final pattern = result.patternForMoment(result.creatableMoment!.id)!;

    expect(pattern.projectedConflictCount, 0);
    expect(pattern.projectedScheduleCoverageComplete, isFalse);
    expect(result.familySummary, contains('Review the time with the family'));
    expect(result.familySummary, isNot(contains('worth trying as a Moment')));
    expect(result.familyThemes, contains('Confirm family availability'));
  });

  test('complete clear schedule coverage supports trying the Moment', () {
    final report = _report(
      now: now,
      status: RhythmStatus.stable,
      includeCompleteClearSchedule: true,
    );
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'covered-picnic',
        type: TwinSimulationType.createMoment,
        newTitle: 'Family Picnic',
        newCategory: MomentCategory.familyTime,
        newIntervalDays: 7,
        newStartMinutes: 18 * 60,
        newWeekday: DateTime.friday,
        participantIds: <String>['adult', 'child'],
        scope: TwinSimulationScope.nextOccurrence,
        assumedDurationMinutes: 60,
      ),
    );
    final pattern = result.patternForMoment(result.creatableMoment!.id)!;

    expect(pattern.projectedConflictCount, 0);
    expect(pattern.projectedScheduleCoverageComplete, isTrue);
    expect(result.familySummary, contains('worth trying as a Moment'));
    expect(result.familyThemes, contains('Early potential'));
  });

  test('overnight busy time is detected from the previous day', () {
    final report = _report(
      now: now,
      status: RhythmStatus.stable,
      includeOvernightConflict: true,
    );
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'late-family-talk',
        type: TwinSimulationType.createMoment,
        newTitle: 'Late Family Talk',
        newCategory: MomentCategory.familyTime,
        newIntervalDays: 7,
        newStartMinutes: 30,
        newWeekday: DateTime.tuesday,
        participantIds: <String>['adult', 'child'],
        scope: TwinSimulationScope.nextOccurrence,
        assumedDurationMinutes: 60,
      ),
    );
    final pattern = result.patternForMoment(result.creatableMoment!.id)!;

    expect(pattern.projectedConflictCount, greaterThan(0));
    expect(pattern.summary, contains('Choose a time without the recorded conflict'));
  });

  test('a one-person idea does not claim increased family time', () {
    final report = _report(now: now, status: RhythmStatus.stable);
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'personal-reading',
        type: TwinSimulationType.createMoment,
        newTitle: 'Personal Reading',
        newCategory: MomentCategory.familyTime,
        newIntervalDays: 7,
        newStartMinutes: 20 * 60,
        newWeekday: DateTime.thursday,
        participantIds: <String>['adult'],
        scope: TwinSimulationScope.nextOccurrence,
        assumedDurationMinutes: 30,
      ),
    );

    expect(result.familySummary, contains('make the next step clearer'));
    expect(result.familySummary, isNot(contains('more space to talk')));
  });

  test('a one-time tradition never claims it will repeat', () {
    final report = _report(now: now, status: RhythmStatus.stable);
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'one-family-tradition',
        type: TwinSimulationType.createMoment,
        newTitle: 'Family Gathering',
        newCategory: MomentCategory.tradition,
        newIntervalDays: 7,
        newStartMinutes: 17 * 60,
        newWeekday: DateTime.saturday,
        participantIds: <String>['adult', 'child'],
        scope: TwinSimulationScope.nextOccurrence,
        assumedDurationMinutes: 90,
      ),
    );

    expect(result.familySummary, contains('Sharing this tradition once'));
    expect(result.familySummary, isNot(contains('Repeating this tradition')));
  });

  test('event-like simulations default to external attendance', () {
    final report = _report(now: now, status: RhythmStatus.stable);
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'graduation',
        type: TwinSimulationType.createMoment,
        newTitle: 'Graduation',
        newCategory: MomentCategory.milestone,
        newIntervalDays: 365,
        newStartMinutes: 17 * 60,
        newDayOfMonth: 10,
        newMonth: DateTime.june,
        participantIds: <String>['adult', 'child'],
        scope: TwinSimulationScope.nextOccurrence,
        assumedDurationMinutes: 120,
      ),
    );

    final draft = SimulationMomentDraftService.build(result);

    expect(draft.type, MomentType.singular);
    expect(draft.format, MomentFormat.externalEvent);
    expect(
      result.familySummary,
      contains('recognize the person’s achievement'),
    );
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

  test('fewer but remaining conflicts stay caution-first', () {
    final report = _report(
      now: now,
      status: RhythmStatus.stillLearning,
      completedCount: 1,
      includePartiallyImprovedSchedule: true,
    );
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'move-lunch-with-remaining-conflicts',
        type: TwinSimulationType.changeTime,
        targetMomentId: 'friday-lunch',
        newStartMinutes: 20 * 60,
        scope: TwinSimulationScope.futureOccurrences,
      ),
    );
    final pattern = result.patternForMoment('friday-lunch')!;

    expect(pattern.currentConflictCount, 4);
    expect(pattern.projectedConflictCount, 2);
    expect(pattern.direction, SimulationDirection.improving);
    expect(pattern.summary, startsWith('Across the next 4 projected occurrences'));
    expect(pattern.summary, contains('change from 4 to 2'));
    expect(pattern.summary, isNot(contains('shared meal')));
    expect(result.familyThemes, contains('Fewer conflicts · time still needs review'));
    expect(result.shouldLeadWithDeterministicBenefit, isFalse);
    expect(result.shouldUseDeterministicNarrative, isTrue);
  });

  test('cadence improvement keeps its benefit with an availability caveat', () {
    final report = _report(
      now: now,
      status: RhythmStatus.stillLearning,
      expectedIntervalDays: 14,
    );
    final result = service.simulate(
      baseReport: report,
      scenario: const TwinSimulationScenario(
        id: 'match-recorded-weekly-cadence',
        type: TwinSimulationType.changeFrequency,
        targetMomentId: 'friday-lunch',
        newIntervalDays: 7,
        scope: TwinSimulationScope.futureOccurrences,
      ),
    );
    final pattern = result.patternForMoment('friday-lunch')!;

    expect(pattern.direction, SimulationDirection.improving);
    expect(pattern.projectedConflictCount, isNull);
    expect(pattern.summary, contains('shared meal'));
    expect(pattern.summary, contains('better matches the recorded cadence'));
    expect(pattern.summary, contains('Confirm the time with your family'));
    expect(result.familyThemes, contains('Benefit can be tested'));
    expect(result.shouldLeadWithDeterministicBenefit, isTrue);
    expect(result.shouldUseDeterministicNarrative, isTrue);
  });
}

FamilyInsightReport _report({
  required DateTime now,
  required RhythmStatus status,
  bool includeFridayConflict = false,
  bool includePartialClearSchedule = false,
  bool includeCompleteClearSchedule = false,
  bool includeOvernightConflict = false,
  bool includeGrandmaFridayConflict = false,
  bool includeGrandmaClearSchedule = false,
  bool includePartiallyImprovedSchedule = false,
  int completedCount = 3,
  int expectedIntervalDays = 7,
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
    expectedIntervalDays: expectedIntervalDays,
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
  ].take(completedCount).toList(growable: false);

  final rhythm = RhythmRecord(
    id: 'friday-lunch',
    familyId: 'family-1',
    momentId: 'friday-lunch',
    expectedIntervalDays: expectedIntervalDays,
    lastOccurrenceAt: completed.last.effectiveStartAt,
    currentGapDays: 4,
    occurrenceCount: completed.length,
    status: status,
    confidence: ConfidenceLevel.medium,
    updatedAt: now,
  );

  final availability = <AvailabilityBlock>[
    if (includeFridayConflict)
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
    if (includePartiallyImprovedSchedule)
      AvailabilityBlock(
        id: 'adult-current-time-conflict',
        familyId: 'family-1',
        memberId: 'adult',
        repeatDays: const <int>[DateTime.friday],
        startMinutes: 17 * 60 + 30,
        endMinutes: 19 * 60 + 30,
        isRecurring: true,
        updatedAt: now,
      ),
    if (includePartiallyImprovedSchedule)
      AvailabilityBlock(
        id: 'adult-first-projected-time-conflict',
        familyId: 'family-1',
        memberId: 'adult',
        repeatDays: const <int>[],
        scheduledDate: DateTime(2026, 9, 4),
        startMinutes: 19 * 60 + 45,
        endMinutes: 20 * 60 + 30,
        isRecurring: false,
        updatedAt: now,
      ),
    if (includePartiallyImprovedSchedule)
      AvailabilityBlock(
        id: 'adult-second-projected-time-conflict',
        familyId: 'family-1',
        memberId: 'adult',
        repeatDays: const <int>[],
        scheduledDate: DateTime(2026, 9, 11),
        startMinutes: 19 * 60 + 45,
        endMinutes: 20 * 60 + 30,
        isRecurring: false,
        updatedAt: now,
      ),
    if (includePartialClearSchedule || includeCompleteClearSchedule)
      AvailabilityBlock(
        id: 'adult-clear-schedule',
        familyId: 'family-1',
        memberId: 'adult',
        repeatDays: const <int>[DateTime.monday],
        startMinutes: 9 * 60,
        endMinutes: 10 * 60,
        isRecurring: true,
        updatedAt: now,
      ),
    if (includeCompleteClearSchedule)
      AvailabilityBlock(
        id: 'child-clear-schedule',
        familyId: 'family-1',
        memberId: 'child',
        repeatDays: const <int>[DateTime.monday],
        startMinutes: 9 * 60,
        endMinutes: 10 * 60,
        isRecurring: true,
        updatedAt: now,
      ),
    if (includeOvernightConflict)
      AvailabilityBlock(
        id: 'adult-overnight',
        familyId: 'family-1',
        memberId: 'adult',
        repeatDays: const <int>[DateTime.monday],
        startMinutes: 23 * 60,
        endMinutes: 60,
        isRecurring: true,
        updatedAt: now,
      ),
    if (includeGrandmaFridayConflict)
      AvailabilityBlock(
        id: 'grandma-friday-conflict',
        familyId: 'family-1',
        memberId: 'grandma',
        repeatDays: const <int>[DateTime.friday],
        startMinutes: 17 * 60 + 30,
        endMinutes: 19 * 60 + 30,
        isRecurring: true,
        updatedAt: now,
      ),
    if (includeGrandmaClearSchedule)
      AvailabilityBlock(
        id: 'grandma-clear-schedule',
        familyId: 'family-1',
        memberId: 'grandma',
        repeatDays: const <int>[DateTime.monday],
        startMinutes: 9 * 60,
        endMinutes: 10 * 60,
        isRecurring: true,
        updatedAt: now,
      ),
  ];

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
