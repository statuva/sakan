import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/features/calendar/presentation/calendar_instance_projection.dart';
import 'package:sakan/shared/models/family_insight_snapshot.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_instance.dart';

void main() {
  test(
    'completed recurring occurrence projects as Completed with instance ID',
    () {
      final now = DateTime.utc(2026, 8, 29, 20);

      final definition = FamilyMoment(
        id: 'movie-night',
        familyId: 'family-1',
        title: 'Movie Night',
        type: MomentType.recurring,
        category: MomentCategory.tradition,
        importanceLevel: 4,
        expectedParticipantIds: const <String>['adult-1', 'child-1'],
        startAt: now.add(const Duration(days: 14)),
        expectedIntervalDays: 14,
        evidenceType: EvidenceType.scheduledOnly,
        status: MomentStatus.scheduled,
        createdBy: 'adult-1',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
      );

      final completed = MomentInstance(
        id: 'instance-aug-29',
        familyId: 'family-1',
        momentId: definition.id,
        titleSnapshot: definition.title,
        typeSnapshot: definition.type,
        categorySnapshot: definition.category,
        importanceLevelSnapshot: definition.importanceLevel,
        expectedParticipantIds: definition.expectedParticipantIds,
        source: MomentInstanceSource.calendar,
        status: MomentInstanceStatus.completed,
        scheduledStartAt: now.subtract(const Duration(hours: 2)),
        actualStartAt: now.subtract(const Duration(hours: 2)),
        actualEndAt: now.subtract(const Duration(hours: 1)),
        actualDurationMinutes: 60,
        confirmedParticipantIds: const <String>['adult-1', 'child-1'],
        reportedParticipantIds: const <String>[],
        evidenceSignals: const <MomentEvidenceSignal>[
          MomentEvidenceSignal.manualCheckIn,
          MomentEvidenceSignal.durationRecorded,
        ],
        confirmationLevel: MomentConfirmationLevel.high,
        createdBy: 'adult-1',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      );

      final snapshot = FamilyInsightSnapshot(
        familyId: 'family-1',
        currentUserId: 'adult-1',
        generatedAt: now,
        members: const [],
        moments: <FamilyMoment>[definition],
        instances: <MomentInstance>[completed],
        rhythms: const [],
        availability: const [],
        reminders: const [],
        memories: const [],
      );

      final entries = buildCalendarInstanceEntries(snapshot);
      final projected = entries.single.calendarMoment;

      expect(projected.id, completed.id);
      expect(projected.status, MomentStatus.completed);
      expect(projected.startAt, completed.actualStartAt);
      expect(projected.expectedIntervalDays, 14);
    },
  );
}
