import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/features/digital_twin/services/digital_twin_interpretation_service.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_instance.dart';
import 'package:sakan/shared/models/rhythm_record.dart';

void main() {
  const service = DigitalTwinInterpretationService();

  test(
    'drifting Moment with strong participation points to timing consistency',
    () {
      final moment = _moment(
        id: 'friday-lunch',
        title: 'Friday Lunch',
        expectedParticipantIds: const <String>[
          'dad',
          'mom',
          'sara',
          'ali',
        ],
      );

      final rhythm = _rhythm(
        momentId: moment.id,
        status: RhythmStatus.drifting,
        gapDays: 19,
        occurrenceCount: 2,
      );

      final interpretation = service.interpretMoment(
        moment: moment,
        rhythm: rhythm,
        instances: <MomentInstance>[
          _completedInstance(
            id: 'one',
            moment: moment,
            participants: const <String>[
              'dad',
              'mom',
              'sara',
              'ali',
            ],
          ),
          _completedInstance(
            id: 'two',
            moment: moment,
            participants: const <String>[
              'dad',
              'mom',
              'sara',
            ],
            dayOffset: -14,
          ),
        ],
      );

      expect(
        interpretation.summary,
        contains('participation remains strong'),
      );

      expect(
        interpretation.summary,
        contains('timing consistency'),
      );
    },
  );

  test(
    'new Moment explains that more history is needed',
    () {
      final moment = _moment(
        id: 'breakfast',
        title: 'Weekend Breakfast',
      );

      final interpretation = service.interpretMoment(
        moment: moment,
        rhythm: _rhythm(
          momentId: moment.id,
          status: RhythmStatus.stillLearning,
          gapDays: 0,
          occurrenceCount: 0,
        ),
        instances: const <MomentInstance>[],
      );

      expect(
        interpretation.summary,
        contains('does not yet have enough'),
      );

      expect(
        interpretation.themes,
        contains('More history is needed'),
      );
    },
  );

  test(
    'family interpretation explains mixed patterns instead of one score',
    () {
      final stableMoment = _moment(
        id: 'movie-night',
        title: 'Movie Night',
      );

      final driftingMoment = _moment(
        id: 'friday-lunch',
        title: 'Friday Lunch',
      );

      final interpretation = service.interpretFamily(
        moments: <FamilyMoment>[
          stableMoment,
          driftingMoment,
        ],
        rhythms: <RhythmRecord>[
          _rhythm(
            momentId: stableMoment.id,
            status: RhythmStatus.stable,
            gapDays: 7,
            occurrenceCount: 4,
          ),
          _rhythm(
            momentId: driftingMoment.id,
            status: RhythmStatus.drifting,
            gapDays: 19,
            occurrenceCount: 3,
          ),
        ],
        instances: <MomentInstance>[
          _completedInstance(
            id: 'stable-one',
            moment: stableMoment,
            participants: const <String>[
              'dad',
              'mom',
            ],
          ),
          _completedInstance(
            id: 'drift-one',
            moment: driftingMoment,
            participants: const <String>[
              'dad',
              'mom',
            ],
          ),
        ],
      );

      expect(
        interpretation.summary,
        contains('mixed rather than one overall family score'),
      );

      expect(
        interpretation.themes,
        contains('1 dependable rhythm'),
      );

      expect(
        interpretation.themes,
        contains('1 rhythm needs consistency'),
      );
    },
  );
}

FamilyMoment _moment({
  required String id,
  required String title,
  List<String> expectedParticipantIds =
      const <String>['dad', 'mom'],
}) {
  final now = DateTime.utc(2026, 8, 29, 12);

  return FamilyMoment(
    id: id,
    familyId: 'family-1',
    title: title,
    type: MomentType.recurring,
    category: MomentCategory.tradition,
    importanceLevel: 4,
    expectedParticipantIds: expectedParticipantIds,
    startAt: now,
    expectedIntervalDays: 7,
    evidenceType: EvidenceType.manual,
    status: MomentStatus.scheduled,
    createdBy: 'dad',
    createdAt: now,
    updatedAt: now,
  );
}

RhythmRecord _rhythm({
  required String momentId,
  required RhythmStatus status,
  required int gapDays,
  required int occurrenceCount,
}) {
  final now = DateTime.utc(2026, 8, 29, 12);

  return RhythmRecord(
    id: momentId,
    familyId: 'family-1',
    momentId: momentId,
    expectedIntervalDays: 7,
    lastOccurrenceAt: occurrenceCount == 0
        ? null
        : now.subtract(Duration(days: gapDays)),
    currentGapDays: gapDays,
    occurrenceCount: occurrenceCount,
    status: status,
    confidence: occurrenceCount >= 3
        ? ConfidenceLevel.medium
        : ConfidenceLevel.low,
    updatedAt: now,
  );
}

MomentInstance _completedInstance({
  required String id,
  required FamilyMoment moment,
  required List<String> participants,
  int dayOffset = -7,
}) {
  final start = DateTime.utc(
    2026,
    8,
    29,
    12,
  ).add(Duration(days: dayOffset));

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
    actualEndAt: start.add(const Duration(minutes: 50)),
    actualDurationMinutes: 50,
    startedBy: 'dad',
    endedBy: 'dad',
    confirmedParticipantIds: participants,
    reportedParticipantIds: const <String>[],
    evidenceSignals: const <MomentEvidenceSignal>[
      MomentEvidenceSignal.hostStarted,
      MomentEvidenceSignal.manualCheckIn,
      MomentEvidenceSignal.durationRecorded,
    ],
    confirmationLevel: MomentConfirmationLevel.high,
    createdBy: 'dad',
    createdAt: start,
    updatedAt: start.add(const Duration(minutes: 50)),
  );
}
