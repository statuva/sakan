import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/shared/models/care_action.dart';
import 'package:sakan/shared/models/family_insight_report.dart';
import 'package:sakan/shared/models/family_insight_snapshot.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_instance.dart';
import 'package:sakan/shared/models/rhythm_record.dart';
import 'package:sakan/shared/services/family_insight_service.dart';

void main() {
  final now = DateTime.utc(2026, 8, 31, 13);

  test('active session becomes the primary Join Moment insight', () {
    final moment = _moment(
      id: 'lunch',
      title: 'Family Lunch',
      category: MomentCategory.familyTime,
      startAt: now,
    );

    final active = _instance(
      id: 'instance-live',
      moment: moment,
      status: MomentInstanceStatus.active,
      scheduledStartAt: now,
      actualStartAt: now.subtract(const Duration(minutes: 10)),
    );

    final report = FamilyInsightService.analyzeSnapshot(
      _snapshot(
        now: now,
        moments: <FamilyMoment>[moment],
        instances: <MomentInstance>[active],
      ),
    );

    expect(
      report.primaryInsight?.actionType,
      FamilyInsightActionType.joinActiveMoment,
    );
  });

  test('daily lunch before its time recommends Add Reminder', () {
    final moment = _moment(
      id: 'daily-lunch',
      title: 'Daily Lunch',
      category: MomentCategory.tradition,
      startAt: DateTime.utc(2026, 8, 31, 15),
      intervalDays: 1,
    );

    final occurrence = _instance(
      id: 'daily-lunch-31',
      moment: moment,
      status: MomentInstanceStatus.scheduled,
      scheduledStartAt: DateTime.utc(2026, 8, 31, 15),
      scheduledEndAt: DateTime.utc(2026, 8, 31, 16),
    );

    final report = FamilyInsightService.analyzeSnapshot(
      _snapshot(
        now: now,
        moments: <FamilyMoment>[moment],
        instances: <MomentInstance>[occurrence],
      ),
    );

    expect(
      report.primaryInsight?.actionType,
      FamilyInsightActionType.addReminder,
    );
    expect(report.primaryInsight?.relatedInstanceId, occurrence.id);
  });

  test('daily lunch during its start window recommends Start This Now', () {
    final start = DateTime.utc(2026, 8, 31, 15);
    final moment = _moment(
      id: 'daily-lunch',
      title: 'Daily Lunch',
      category: MomentCategory.tradition,
      startAt: start,
      intervalDays: 1,
    );

    final occurrence = _instance(
      id: 'daily-lunch-31',
      moment: moment,
      status: MomentInstanceStatus.scheduled,
      scheduledStartAt: start,
      scheduledEndAt: start.add(const Duration(hours: 1)),
    );

    final report = FamilyInsightService.analyzeSnapshot(
      _snapshot(
        now: start.add(const Duration(minutes: 15)),
        moments: <FamilyMoment>[moment],
        instances: <MomentInstance>[occurrence],
      ),
    );

    expect(
      report.primaryInsight?.actionType,
      FamilyInsightActionType.startMomentNow,
    );
  });

  test('daily lunch after its end recommends Review Today', () {
    final start = DateTime.utc(2026, 8, 31, 15);
    final moment = _moment(
      id: 'daily-lunch',
      title: 'Daily Lunch',
      category: MomentCategory.tradition,
      startAt: start,
      intervalDays: 1,
    );

    final occurrence = _instance(
      id: 'daily-lunch-31',
      moment: moment,
      status: MomentInstanceStatus.scheduled,
      scheduledStartAt: start,
      scheduledEndAt: start.add(const Duration(hours: 1)),
    );

    final report = FamilyInsightService.analyzeSnapshot(
      _snapshot(
        now: start.add(const Duration(hours: 2)),
        moments: <FamilyMoment>[moment],
        instances: <MomentInstance>[occurrence],
      ),
    );

    expect(
      report.primaryInsight?.actionType,
      FamilyInsightActionType.reviewToday,
    );
  });

  test('existing instance reminder becomes Open My Reminders', () {
    final moment = _moment(
      id: 'daily-lunch',
      title: 'Daily Lunch',
      category: MomentCategory.tradition,
      startAt: DateTime.utc(2026, 8, 31, 15),
      intervalDays: 1,
    );

    final occurrence = _instance(
      id: 'daily-lunch-31',
      moment: moment,
      status: MomentInstanceStatus.scheduled,
      scheduledStartAt: DateTime.utc(2026, 8, 31, 15),
      scheduledEndAt: DateTime.utc(2026, 8, 31, 16),
    );

    final reminder = CareAction(
      id: 'reminder-1',
      familyId: 'family-1',
      momentId: moment.id,
      instanceId: occurrence.id,
      title: 'Get ready for lunch',
      reason: '',
      assignedMemberId: 'adult-1',
      dueAt: DateTime.utc(2026, 8, 31, 14, 30),
      status: CareActionStatus.pending,
      source: CareActionSource.calendar,
      evidenceType: EvidenceType.scheduledOnly,
      createdAt: now,
      updatedAt: now,
    );

    final report = FamilyInsightService.analyzeSnapshot(
      _snapshot(
        now: now,
        moments: <FamilyMoment>[moment],
        instances: <MomentInstance>[occurrence],
        reminders: <CareAction>[reminder],
      ),
    );

    expect(
      report.primaryInsight?.actionType,
      FamilyInsightActionType.openReminders,
    );
    expect(report.primaryInsight?.relatedReminderId, reminder.id);
  });

  test('upcoming milestone creates an Add Reminder action', () {
    final moment = _moment(
      id: 'graduation',
      title: 'Graduation',
      category: MomentCategory.milestone,
      startAt: now.add(const Duration(days: 5)),
      type: MomentType.singular,
    );

    final occurrence = _instance(
      id: 'instance-grad',
      moment: moment,
      status: MomentInstanceStatus.scheduled,
      scheduledStartAt: now.add(const Duration(days: 5)),
    );

    final report = FamilyInsightService.analyzeSnapshot(
      _snapshot(
        now: now,
        moments: <FamilyMoment>[moment],
        instances: <MomentInstance>[occurrence],
      ),
    );

    expect(
      report.primaryInsight?.actionType,
      FamilyInsightActionType.addReminder,
    );
  });

  test('flexible drifting rhythm recommends scheduling an occurrence', () {
    final moment = _moment(
      id: 'outing',
      title: 'Family Outing',
      category: MomentCategory.tradition,
      startAt: now,
      flexible: true,
      intervalDays: 30,
    );

    final rhythm = RhythmRecord(
      id: moment.id,
      familyId: 'family-1',
      momentId: moment.id,
      expectedIntervalDays: 30,
      lastOccurrenceAt: now.subtract(const Duration(days: 50)),
      currentGapDays: 50,
      occurrenceCount: 3,
      status: RhythmStatus.drifting,
      confidence: ConfidenceLevel.medium,
      updatedAt: now,
    );

    final report = FamilyInsightService.analyzeSnapshot(
      _snapshot(
        now: now,
        moments: <FamilyMoment>[moment],
        instances: const <MomentInstance>[],
        rhythms: <RhythmRecord>[rhythm],
      ),
    );

    expect(
      report.primaryInsight?.actionType,
      FamilyInsightActionType.scheduleMoment,
    );
  });
}

FamilyInsightSnapshot _snapshot({
  required DateTime now,
  required List<FamilyMoment> moments,
  required List<MomentInstance> instances,
  List<RhythmRecord> rhythms = const <RhythmRecord>[],
  List<CareAction> reminders = const <CareAction>[],
}) {
  return FamilyInsightSnapshot(
    familyId: 'family-1',
    currentUserId: 'adult-1',
    generatedAt: now,
    members: <Member>[
      Member(
        id: 'adult-1',
        familyId: 'family-1',
        displayName: 'Adult',
        role: FamilyRole.adult,
        ageGroup: AgeGroup.adult,
        interests: const <String>[],
        preferredDays: const <int>[],
        isActive: true,
        joinedAt: now,
        updatedAt: now,
      ),
      Member(
        id: 'child-1',
        familyId: 'family-1',
        displayName: 'Child',
        role: FamilyRole.child,
        ageGroup: AgeGroup.child,
        interests: const <String>[],
        preferredDays: const <int>[],
        isActive: true,
        joinedAt: now,
        updatedAt: now,
      ),
    ],
    moments: moments,
    instances: instances,
    rhythms: rhythms,
    availability: const [],
    reminders: reminders,
    memories: const [],
  );
}

FamilyMoment _moment({
  required String id,
  required String title,
  required MomentCategory category,
  required DateTime startAt,
  MomentType type = MomentType.recurring,
  int intervalDays = 7,
  bool flexible = false,
}) {
  return FamilyMoment(
    id: id,
    familyId: 'family-1',
    title: title,
    type: type,
    category: category,
    importanceLevel: 5,
    expectedParticipantIds: const <String>['adult-1', 'child-1'],
    startAt: startAt,
    expectedIntervalDays:
        type == MomentType.recurring ? intervalDays : null,
    preferredStartMinutes: startAt.hour * 60 + startAt.minute,
    isDayFlexible: flexible,
    evidenceType: EvidenceType.manual,
    status: MomentStatus.scheduled,
    createdBy: 'adult-1',
    createdAt: startAt.subtract(const Duration(days: 2)),
    updatedAt: startAt.subtract(const Duration(days: 1)),
  );
}

MomentInstance _instance({
  required String id,
  required FamilyMoment moment,
  required MomentInstanceStatus status,
  required DateTime scheduledStartAt,
  DateTime? scheduledEndAt,
  DateTime? actualStartAt,
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
    status: status,
    scheduledStartAt: scheduledStartAt,
    scheduledEndAt: scheduledEndAt,
    actualStartAt: actualStartAt,
    confirmedParticipantIds: actualStartAt == null
        ? const <String>[]
        : const <String>['adult-1'],
    reportedParticipantIds: const <String>[],
    evidenceSignals: const <MomentEvidenceSignal>[
      MomentEvidenceSignal.scheduled,
    ],
    confirmationLevel: MomentConfirmationLevel.low,
    createdBy: 'adult-1',
    createdAt: scheduledStartAt.subtract(const Duration(days: 1)),
    updatedAt: scheduledStartAt,
  );
}
