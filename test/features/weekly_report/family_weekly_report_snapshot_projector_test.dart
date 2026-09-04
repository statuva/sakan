import 'package:flutter_test/flutter_test.dart';
import 'package:sakan/features/weekly_report/services/family_weekly_report_snapshot_projector.dart';
import 'package:sakan/shared/models/family_insight_snapshot.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_instance.dart';

void main() {
  final reportReference = DateTime(2026, 9, 7, 9);
  final occurrenceStart = DateTime(2026, 8, 31, 18);

  test('adds a missing recurring occurrence without mutating the snapshot', () {
    final moment = _moment(startAt: occurrenceStart);
    final snapshot = _snapshot(
      generatedAt: reportReference,
      moments: <FamilyMoment>[moment],
    );

    final projected =
        FamilyWeeklyReportSnapshotProjector.projectLatestCompletedWeek(
          snapshot,
          now: reportReference,
        );

    expect(snapshot.instances, isEmpty);
    expect(projected.instances, hasLength(1));
    final occurrence = projected.instances.single;
    expect(occurrence.momentId, moment.id);
    expect(occurrence.scheduledStartAt, occurrenceStart.toUtc());
    expect(occurrence.status, MomentInstanceStatus.scheduled);
    expect(
      occurrence.evidenceSignals,
      contains(MomentEvidenceSignal.scheduled),
    );
  });

  for (final status in <MomentInstanceStatus>[
    MomentInstanceStatus.active,
    MomentInstanceStatus.completed,
    MomentInstanceStatus.missed,
    MomentInstanceStatus.cancelled,
  ]) {
    test('keeps an existing ${status.name} occurrence instead of projecting', () {
      final moment = _moment(startAt: occurrenceStart);
      final existing = _instance(
        id: 'legacy-occurrence-id',
        moment: moment,
        startAt: occurrenceStart,
        status: status,
        updatedAt: DateTime(2026, 9, 1),
      );
      final snapshot = _snapshot(
        generatedAt: reportReference,
        moments: <FamilyMoment>[moment],
        instances: <MomentInstance>[existing],
      );

      final projected =
          FamilyWeeklyReportSnapshotProjector.projectLatestCompletedWeek(
            snapshot,
            now: reportReference,
          );

      expect(projected.instances, hasLength(1));
      expect(projected.instances.single, same(existing));
    });
  }

  test('deduplicates existing instances by their latest update', () {
    final moment = _moment(startAt: occurrenceStart);
    final older = _instance(
      id: 'same-id',
      moment: moment,
      startAt: occurrenceStart,
      status: MomentInstanceStatus.scheduled,
      updatedAt: DateTime(2026, 8, 31, 17),
    );
    final latest = _instance(
      id: 'same-id',
      moment: moment,
      startAt: occurrenceStart,
      status: MomentInstanceStatus.missed,
      updatedAt: DateTime(2026, 9, 1),
    );

    final projected =
        FamilyWeeklyReportSnapshotProjector.projectLatestCompletedWeek(
          _snapshot(
            generatedAt: reportReference,
            moments: <FamilyMoment>[moment],
            instances: <MomentInstance>[older, latest],
          ),
          now: reportReference,
        );

    expect(projected.instances, hasLength(1));
    expect(projected.instances.single, same(latest));
  });

  test('deduplicates different ids that represent the same occurrence', () {
    final moment = _moment(startAt: occurrenceStart);
    final older = _instance(
      id: 'legacy-id',
      moment: moment,
      startAt: occurrenceStart,
      status: MomentInstanceStatus.completed,
      updatedAt: DateTime(2026, 8, 31, 20),
    );
    final latest = _instance(
      id: 'deterministic-id',
      moment: moment,
      startAt: occurrenceStart,
      status: MomentInstanceStatus.missed,
      updatedAt: DateTime(2026, 9, 1),
    );

    final projected =
        FamilyWeeklyReportSnapshotProjector.projectLatestCompletedWeek(
          _snapshot(
            generatedAt: reportReference,
            moments: <FamilyMoment>[moment],
            instances: <MomentInstance>[older, latest],
          ),
          now: reportReference,
        );

    expect(projected.instances, hasLength(1));
    expect(projected.instances.single, same(latest));
  });

  test('prefers a resolved status when duplicate update times tie', () {
    final moment = _moment(startAt: occurrenceStart);
    final scheduled = _instance(
      id: 'scheduled-id',
      moment: moment,
      startAt: occurrenceStart,
      status: MomentInstanceStatus.scheduled,
      updatedAt: DateTime(2026, 9, 1),
    );
    final completed = _instance(
      id: 'completed-id',
      moment: moment,
      startAt: occurrenceStart,
      status: MomentInstanceStatus.completed,
      updatedAt: DateTime(2026, 9, 1),
    );

    final projected =
        FamilyWeeklyReportSnapshotProjector.projectLatestCompletedWeek(
          _snapshot(
            generatedAt: reportReference,
            moments: <FamilyMoment>[moment],
            instances: <MomentInstance>[scheduled, completed],
          ),
          now: reportReference,
        );

    expect(projected.instances, hasLength(1));
    expect(projected.instances.single, same(completed));
  });

  test('does not project cancelled recurring definitions', () {
    final moment = _moment(
      startAt: occurrenceStart,
      status: MomentStatus.cancelled,
    );

    final projected =
        FamilyWeeklyReportSnapshotProjector.projectLatestCompletedWeek(
          _snapshot(
            generatedAt: reportReference,
            moments: <FamilyMoment>[moment],
          ),
          now: reportReference,
        );

    expect(projected.instances, isEmpty);
  });
}

FamilyInsightSnapshot _snapshot({
  required DateTime generatedAt,
  required List<FamilyMoment> moments,
  List<MomentInstance> instances = const <MomentInstance>[],
}) {
  return FamilyInsightSnapshot(
    familyId: 'family-1',
    currentUserId: 'adult-1',
    generatedAt: generatedAt,
    members: const [],
    moments: moments,
    instances: instances,
    rhythms: const [],
    availability: const [],
    reminders: const [],
    memories: const [],
  );
}

FamilyMoment _moment({
  required DateTime startAt,
  MomentStatus status = MomentStatus.scheduled,
}) {
  return FamilyMoment(
    id: 'moment-1',
    familyId: 'family-1',
    title: 'Family dinner',
    type: MomentType.recurring,
    category: MomentCategory.familyTime,
    importanceLevel: 4,
    expectedParticipantIds: const <String>['adult-1', 'child-1'],
    startAt: startAt,
    expectedIntervalDays: 7,
    preferredStartMinutes: 18 * 60,
    preferredWeekday: DateTime.monday,
    evidenceType: EvidenceType.manual,
    status: status,
    isArchived: status != MomentStatus.scheduled,
    createdBy: 'adult-1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
}

MomentInstance _instance({
  required String id,
  required FamilyMoment moment,
  required DateTime startAt,
  required MomentInstanceStatus status,
  required DateTime updatedAt,
}) {
  return MomentInstance.scheduledFromMoment(
    id: id,
    moment: moment,
    source: MomentInstanceSource.calendar,
    createdBy: moment.createdBy,
    scheduledStartAt: startAt,
    now: DateTime(2026, 8, 1),
  ).copyWith(status: status, updatedAt: updatedAt);
}
