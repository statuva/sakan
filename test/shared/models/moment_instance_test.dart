import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_instance.dart';

void main() {
  test(
    'scheduledFromMoment preserves the Moment snapshot',
    () {
      final now =
          DateTime.utc(2026, 8, 26, 10);

      final moment = FamilyMoment(
        id: 'movie-night',
        familyId: 'family-1',
        title: 'Movie Night',
        type: MomentType.recurring,
        category: MomentCategory.tradition,
        importanceLevel: 5,
        expectedParticipantIds: const <String>[
          'member-1',
          'member-2',
        ],
        startAt:
            DateTime.utc(2026, 8, 28, 20),
        endAt:
            DateTime.utc(2026, 8, 28, 22),
        expectedIntervalDays: 14,
        location: 'Living Room',
        evidenceType:
            EvidenceType.scheduledOnly,
        status: MomentStatus.scheduled,
        createdBy: 'member-1',
        createdAt: now,
        updatedAt: now,
      );

      final instance =
          MomentInstance.scheduledFromMoment(
        id: 'instance-1',
        moment: moment,
        source:
            MomentInstanceSource.calendar,
        createdBy: 'member-1',
        now: now,
      );

      expect(
        instance.titleSnapshot,
        'Movie Night',
      );

      expect(
        instance.status,
        MomentInstanceStatus.scheduled,
      );

      expect(
        instance.expectedParticipantIds,
        <String>['member-1', 'member-2'],
      );

      expect(
        instance.evidenceSignals,
        contains(
          MomentEvidenceSignal.scheduled,
        ),
      );

      final restored =
          MomentInstance.fromMap(
        instance.id,
        instance.toMap(),
      );

      expect(restored.id, instance.id);
      expect(
        restored.scheduledStartAt,
        instance.scheduledStartAt,
      );
      expect(
        restored.categorySnapshot,
        MomentCategory.tradition,
      );
    },
  );

  test(
    'copyWith can move an instance into the active state',
    () {
      final now =
          DateTime.utc(2026, 8, 26, 10);

      final original = MomentInstance(
        id: 'instance-1',
        familyId: 'family-1',
        momentId: 'moment-1',
        titleSnapshot: 'Family Lunch',
        typeSnapshot: MomentType.recurring,
        categorySnapshot:
            MomentCategory.familyTime,
        importanceLevelSnapshot: 4,
        expectedParticipantIds:
            const <String>['member-1'],
        source:
            MomentInstanceSource.calendar,
        status:
            MomentInstanceStatus.scheduled,
        scheduledStartAt: now,
        confirmedParticipantIds:
            const <String>[],
        evidenceSignals: const <
            MomentEvidenceSignal>[
          MomentEvidenceSignal.scheduled,
        ],
        confirmationLevel:
            MomentConfirmationLevel.low,
        createdBy: 'member-1',
        createdAt: now,
        updatedAt: now,
      );

      final active = original.copyWith(
        status: MomentInstanceStatus.active,
        actualStartAt: now,
        startedBy: 'member-1',
        confirmedParticipantIds:
            const <String>['member-1'],
      );

      expect(active.isActive, isTrue);
      expect(
        active.confirmedParticipantIds,
        <String>['member-1'],
      );
      expect(active.startedBy, 'member-1');
    },
  );
}
