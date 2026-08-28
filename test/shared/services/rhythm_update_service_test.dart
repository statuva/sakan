import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_instance.dart';
import 'package:sakan/shared/models/rhythm_record.dart';
import 'package:sakan/shared/services/rhythm_update_service.dart';

void main() {
  final createdAt = DateTime.utc(2026, 8, 1);

  FamilyMoment recurringMoment() {
    return FamilyMoment(
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
      startAt: DateTime.utc(2026, 8, 22, 20),
      endAt: DateTime.utc(2026, 8, 22, 22),
      expectedIntervalDays: 7,
      evidenceType: EvidenceType.scheduledOnly,
      status: MomentStatus.scheduled,
      createdBy: 'member-1',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  MomentInstance completed({
    required String id,
    required DateTime start,
    MomentConfirmationLevel confirmation =
        MomentConfirmationLevel.medium,
  }) {
    return MomentInstance(
      id: id,
      familyId: 'family-1',
      momentId: 'movie-night',
      titleSnapshot: 'Movie Night',
      typeSnapshot: MomentType.recurring,
      categorySnapshot: MomentCategory.tradition,
      importanceLevelSnapshot: 5,
      expectedParticipantIds: const <String>[
        'member-1',
        'member-2',
      ],
      source: MomentInstanceSource.calendar,
      status: MomentInstanceStatus.completed,
      scheduledStartAt: start,
      scheduledEndAt: start.add(
        const Duration(hours: 2),
      ),
      actualStartAt: start,
      actualEndAt: start.add(
        const Duration(hours: 1),
      ),
      actualDurationMinutes: 60,
      startedBy: 'member-1',
      endedBy: 'member-1',
      confirmedParticipantIds: const <String>[
        'member-1',
        'member-2',
      ],
      reportedParticipantIds: const <String>[],
      evidenceSignals: const <MomentEvidenceSignal>[
        MomentEvidenceSignal.manualCheckIn,
        MomentEvidenceSignal.multipleCheckIns,
        MomentEvidenceSignal.durationRecorded,
      ],
      confirmationLevel: confirmation,
      createdBy: 'member-1',
      createdAt: start,
      updatedAt: start,
    );
  }

  test('two recent occurrences produce a stable rhythm', () {
    final record = RhythmUpdateService.calculateRecord(
      moment: recurringMoment(),
      instances: <MomentInstance>[
        completed(
          id: 'one',
          start: DateTime.utc(2026, 8, 15, 20),
        ),
        completed(
          id: 'two',
          start: DateTime.utc(2026, 8, 22, 20),
        ),
      ],
      now: DateTime.utc(2026, 8, 26, 12),
    );

    expect(record.occurrenceCount, 2);
    expect(record.currentGapDays, 4);
    expect(record.status, RhythmStatus.stable);
    expect(record.confidence, ConfidenceLevel.medium);
  });

  test('a missed occurrence after completion makes rhythm drift', () {
    final missed = MomentInstance.scheduledFromMoment(
      id: 'missed',
      moment: recurringMoment(),
      source: MomentInstanceSource.calendar,
      createdBy: 'member-1',
      scheduledStartAt: DateTime.utc(2026, 8, 29, 20),
      now: DateTime.utc(2026, 8, 22),
    ).copyWith(
      status: MomentInstanceStatus.missed,
      updatedAt: DateTime.utc(2026, 8, 30),
    );

    final record = RhythmUpdateService.calculateRecord(
      moment: recurringMoment(),
      instances: <MomentInstance>[
        completed(
          id: 'one',
          start: DateTime.utc(2026, 8, 15, 20),
        ),
        completed(
          id: 'two',
          start: DateTime.utc(2026, 8, 22, 20),
        ),
        missed,
      ],
      now: DateTime.utc(2026, 8, 30, 12),
    );

    expect(record.status, RhythmStatus.drifting);
  });

  test('a new completion after drifting becomes recovering', () {
    final previous = RhythmRecord(
      id: 'movie-night',
      familyId: 'family-1',
      momentId: 'movie-night',
      expectedIntervalDays: 7,
      lastOccurrenceAt: DateTime.utc(2026, 8, 15),
      currentGapDays: 14,
      occurrenceCount: 2,
      status: RhythmStatus.drifting,
      confidence: ConfidenceLevel.medium,
      updatedAt: DateTime.utc(2026, 8, 29),
    );

    final record = RhythmUpdateService.calculateRecord(
      moment: recurringMoment(),
      instances: <MomentInstance>[
        completed(
          id: 'one',
          start: DateTime.utc(2026, 8, 15, 20),
        ),
        completed(
          id: 'two',
          start: DateTime.utc(2026, 8, 29, 20),
        ),
      ],
      previous: previous,
      now: DateTime.utc(2026, 8, 30, 12),
    );

    expect(record.status, RhythmStatus.recovering);
  });
}
