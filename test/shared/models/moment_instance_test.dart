import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_instance.dart';

void main() {
  test('review fields survive serialization', () {
    final start = DateTime.utc(2026, 8, 28, 19);

    final instance = MomentInstance(
      id: 'instance-1',
      familyId: 'family-1',
      momentId: 'moment-1',
      titleSnapshot: 'Family Dinner',
      typeSnapshot: MomentType.recurring,
      categorySnapshot: MomentCategory.familyTime,
      importanceLevelSnapshot: 4,
      expectedParticipantIds: const <String>[
        'member-1',
        'member-2',
      ],
      source: MomentInstanceSource.todayReview,
      status: MomentInstanceStatus.completed,
      scheduledStartAt: start,
      actualStartAt: start,
      actualEndAt: start.add(const Duration(hours: 1)),
      actualDurationMinutes: 60,
      confirmedParticipantIds: const <String>[
        'member-1',
      ],
      reportedParticipantIds: const <String>[
        'member-1',
        'member-2',
      ],
      evidenceSignals: const <MomentEvidenceSignal>[
        MomentEvidenceSignal.todayReview,
        MomentEvidenceSignal.durationRecorded,
      ],
      confirmationLevel: MomentConfirmationLevel.medium,
      reviewNote: 'We ate together after work.',
      reviewedBy: 'member-1',
      reviewedAt: start.add(const Duration(hours: 2)),
      createdBy: 'member-1',
      createdAt: start,
      updatedAt: start,
    );

    final restored = MomentInstance.fromMap(
      instance.id,
      instance.toMap(),
    );

    expect(restored.reportedParticipantIds.length, 2);
    expect(restored.reviewNote, 'We ate together after work.');
    expect(restored.allRecordedParticipantIds, <String>[
      'member-1',
      'member-2',
    ]);
  });

  test('scheduled factory initializes empty review evidence', () {
    final now = DateTime.utc(2026, 8, 28);

    final moment = FamilyMoment(
      id: 'moment-1',
      familyId: 'family-1',
      title: 'Movie Night',
      type: MomentType.recurring,
      category: MomentCategory.tradition,
      importanceLevel: 4,
      expectedParticipantIds: const <String>[
        'member-1',
      ],
      startAt: now,
      expectedIntervalDays: 7,
      evidenceType: EvidenceType.scheduledOnly,
      status: MomentStatus.scheduled,
      createdBy: 'member-1',
      createdAt: now,
      updatedAt: now,
    );

    final instance = MomentInstance.scheduledFromMoment(
      id: 'instance-1',
      moment: moment,
      source: MomentInstanceSource.calendar,
      createdBy: 'member-1',
      now: now,
    );

    expect(instance.reportedParticipantIds, isEmpty);
    expect(instance.reviewedAt, isNull);
    expect(instance.status, MomentInstanceStatus.scheduled);
  });
}
