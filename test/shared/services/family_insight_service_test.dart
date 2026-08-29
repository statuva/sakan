import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/shared/models/family_insight_report.dart';
import 'package:sakan/shared/models/family_insight_snapshot.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_instance.dart';
import 'package:sakan/shared/models/rhythm_record.dart';
import 'package:sakan/shared/services/family_insight_service.dart';

void main() {
  final now = DateTime.utc(2026, 8, 29, 16);

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
      actualStartAt: now.subtract(
        const Duration(minutes: 10),
      ),
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

    expect(
      report.primaryInsight?.relatedInstanceId,
      active.id,
    );
  });

  test('past unresolved occurrence asks an adult to Review Today', () {
    final moment = _moment(
      id: 'movie',
      title: 'Movie Night',
      category: MomentCategory.tradition,
      startAt: now.subtract(const Duration(hours: 2)),
    );

    final unresolved = _instance(
      id: 'instance-review',
      moment: moment,
      status: MomentInstanceStatus.scheduled,
      scheduledStartAt: now.subtract(const Duration(hours: 2)),
      scheduledEndAt: now.subtract(const Duration(hours: 1)),
    );

    final report = FamilyInsightService.analyzeSnapshot(
      _snapshot(
        now: now,
        moments: <FamilyMoment>[moment],
        instances: <MomentInstance>[unresolved],
      ),
    );

    expect(
      report.primaryInsight?.actionType,
      FamilyInsightActionType.reviewToday,
    );
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

  test('drifting rhythm recommends scheduling its next occurrence', () {
    final moment = _moment(
      id: 'breakfast',
      title: 'Weekend Breakfast',
      category: MomentCategory.tradition,
      startAt: now.add(const Duration(days: 6)),
    );

    final occurrence = _instance(
      id: 'instance-breakfast',
      moment: moment,
      status: MomentInstanceStatus.scheduled,
      scheduledStartAt: now.add(const Duration(days: 6)),
    );

    final rhythm = RhythmRecord(
      id: moment.id,
      familyId: 'family-1',
      momentId: moment.id,
      expectedIntervalDays: 7,
      lastOccurrenceAt: now.subtract(const Duration(days: 18)),
      currentGapDays: 18,
      occurrenceCount: 3,
      status: RhythmStatus.drifting,
      confidence: ConfidenceLevel.medium,
      updatedAt: now,
    );

    final report = FamilyInsightService.analyzeSnapshot(
      _snapshot(
        now: now,
        moments: <FamilyMoment>[moment],
        instances: <MomentInstance>[occurrence],
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
    reminders: const [],
    memories: const [],
  );
}

FamilyMoment _moment({
  required String id,
  required String title,
  required MomentCategory category,
  required DateTime startAt,
  MomentType type = MomentType.recurring,
}) {
  return FamilyMoment(
    id: id,
    familyId: 'family-1',
    title: title,
    type: type,
    category: category,
    importanceLevel: 5,
    expectedParticipantIds: const <String>[
      'adult-1',
      'child-1',
    ],
    startAt: startAt,
    expectedIntervalDays:
        type == MomentType.recurring ? 7 : null,
    evidenceType: EvidenceType.scheduledOnly,
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
    createdAt: scheduledStartAt.subtract(
      const Duration(days: 1),
    ),
    updatedAt: scheduledStartAt,
  );
}
