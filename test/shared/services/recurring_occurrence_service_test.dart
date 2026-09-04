import 'package:flutter_test/flutter_test.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_instance.dart';
import 'package:sakan/shared/repositories/moment_instance_repository.dart';
import 'package:sakan/shared/repositories/non_destructive_occurrence_repository.dart';
import 'package:sakan/shared/services/recurring_occurrence_service.dart';

void main() {
  final service = RecurringOccurrenceService(_UnusedRepository());

  test('never emits a daily occurrence before the anchor time', () {
    final moment = _moment(
      startAt: DateTime(2026, 9, 4, 10),
      intervalDays: 1,
      preferredStartMinutes: 9 * 60,
    );

    final starts = service.startsInRange(
      moment: moment,
      rangeStart: DateTime(2026, 9, 4),
      rangeEnd: DateTime(2026, 9, 5),
    );

    expect(starts, <DateTime>[DateTime(2026, 9, 5, 9)]);
  });

  test('biweekly cadence uses calendar dates from the anchor', () {
    final moment = _moment(
      startAt: DateTime(2026, 3, 2, 10),
      intervalDays: 14,
      preferredStartMinutes: 10 * 60,
      preferredWeekday: DateTime.monday,
    );

    final starts = service.startsInRange(
      moment: moment,
      rangeStart: DateTime(2026, 3),
      rangeEnd: DateTime(2026, 3, 31),
    );

    expect(starts, <DateTime>[
      DateTime(2026, 3, 2, 10),
      DateTime(2026, 3, 16, 10),
      DateTime(2026, 3, 30, 10),
    ]);
  });

  test('biweekly cadence anchors to the first preferred weekday', () {
    final moment = _moment(
      startAt: DateTime(2026, 3, 2, 10),
      intervalDays: 14,
      preferredStartMinutes: 10 * 60,
      preferredWeekday: DateTime.wednesday,
    );

    final starts = service.startsInRange(
      moment: moment,
      rangeStart: DateTime(2026, 3),
      rangeEnd: DateTime(2026, 3, 31),
    );

    expect(starts, <DateTime>[
      DateTime(2026, 3, 4, 10),
      DateTime(2026, 3, 18, 10),
    ]);
  });

  test('falls back safely from invalid weekday and start-minute metadata', () {
    final moment = _moment(
      startAt: DateTime(2026, 9, 4, 10),
      intervalDays: 14,
      preferredStartMinutes: 2000,
      preferredWeekday: 99,
    );

    final starts = service.startsInRange(
      moment: moment,
      rangeStart: DateTime(2026, 9, 4),
      rangeEnd: DateTime(2026, 9, 30),
    );

    expect(starts, <DateTime>[
      DateTime(2026, 9, 4, 10),
      DateTime(2026, 9, 18, 10),
    ]);
  });

  test('custom day intervals use the preferred local start time', () {
    final moment = _moment(
      startAt: DateTime(2026, 9, 1, 10),
      intervalDays: 3,
      preferredStartMinutes: 9 * 60,
    );

    final starts = service.startsInRange(
      moment: moment,
      rangeStart: DateTime(2026, 9),
      rangeEnd: DateTime(2026, 9, 8),
    );

    expect(starts, <DateTime>[
      DateTime(2026, 9, 4, 9),
      DateTime(2026, 9, 7, 9),
    ]);
  });

  test('does not backfill a range that ends before the anchor', () {
    final moment = _moment(
      startAt: DateTime(2026, 9, 4, 10),
      intervalDays: 7,
      preferredStartMinutes: 10 * 60,
      preferredWeekday: DateTime.friday,
    );

    final starts = service.startsInRange(
      moment: moment,
      rangeStart: DateTime(2026, 8, 24),
      rangeEnd: DateTime(2026, 8, 30),
    );

    expect(starts, isEmpty);
  });

  test('does not materialize a non-scheduled recurring definition', () {
    final moment = _moment(
      startAt: DateTime(2026, 9, 4, 10),
      intervalDays: 7,
      preferredStartMinutes: 10 * 60,
      preferredWeekday: DateTime.friday,
    ).copyWith(status: MomentStatus.cancelled);

    final starts = service.startsInRange(
      moment: moment,
      rangeStart: DateTime(2026, 9, 4),
      rangeEnd: DateTime(2026, 9, 30),
    );

    expect(starts, isEmpty);
  });

  test('repeated materialization creates one deterministic occurrence', () async {
    final repository = _MemoryNonDestructiveRepository();
    final materializer = RecurringOccurrenceService(repository);
    final moment = _moment(
      startAt: DateTime(2026, 9, 4, 10),
      intervalDays: 7,
      preferredStartMinutes: 10 * 60,
      preferredWeekday: DateTime.friday,
    );

    final firstWrites = await materializer.ensureRange(
      moments: <FamilyMoment>[moment],
      rangeStart: DateTime(2026, 9, 4),
      rangeEnd: DateTime(2026, 9, 4),
      createdBy: 'adult-1',
    );
    final secondWrites = await materializer.ensureRange(
      moments: <FamilyMoment>[moment],
      rangeStart: DateTime(2026, 9, 4),
      rangeEnd: DateTime(2026, 9, 4),
      createdBy: 'adult-1',
    );

    expect(firstWrites, 1);
    expect(secondWrites, 0);
    expect(repository.instances, hasLength(1));
  });

  for (final status in <MomentInstanceStatus>[
    MomentInstanceStatus.active,
    MomentInstanceStatus.completed,
    MomentInstanceStatus.missed,
    MomentInstanceStatus.cancelled,
  ]) {
    test('materialization preserves an existing ${status.name} occurrence', () async {
      final repository = _MemoryNonDestructiveRepository();
      final materializer = RecurringOccurrenceService(repository);
      final moment = _moment(
        startAt: DateTime(2026, 9, 4, 10),
        intervalDays: 7,
        preferredStartMinutes: 10 * 60,
        preferredWeekday: DateTime.friday,
      );
      final existing = MomentInstance.scheduledFromMoment(
        id: _occurrenceId(moment.id, moment.startAt),
        moment: moment,
        source: MomentInstanceSource.calendar,
        createdBy: 'adult-1',
        now: DateTime.utc(2026, 8, 1),
      ).copyWith(
        status: status,
        updatedAt: DateTime.utc(2026, 9, 5),
      );
      repository.instances[existing.id] = existing;

      final writes = await materializer.ensureRange(
        moments: <FamilyMoment>[moment],
        rangeStart: DateTime(2026, 9, 4),
        rangeEnd: DateTime(2026, 9, 4),
        createdBy: 'adult-1',
      );

      expect(writes, 0);
      expect(repository.instances[existing.id]?.status, status);
      expect(
        repository.instances[existing.id]?.updatedAt,
        DateTime.utc(2026, 9, 5),
      );
    });
  }
}

FamilyMoment _moment({
  required DateTime startAt,
  required int intervalDays,
  required int preferredStartMinutes,
  int? preferredWeekday,
}) {
  return FamilyMoment(
    id: 'moment-1',
    familyId: 'family-1',
    title: 'Family dinner',
    type: MomentType.recurring,
    category: MomentCategory.familyTime,
    importanceLevel: 3,
    expectedParticipantIds: const <String>['adult-1'],
    startAt: startAt,
    expectedIntervalDays: intervalDays,
    preferredStartMinutes: preferredStartMinutes,
    preferredWeekday: preferredWeekday,
    evidenceType: EvidenceType.manual,
    status: MomentStatus.scheduled,
    createdBy: 'adult-1',
    createdAt: startAt,
    updatedAt: startAt,
  );
}

class _UnusedRepository implements MomentInstanceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _MemoryNonDestructiveRepository
    implements MomentInstanceRepository, NonDestructiveOccurrenceRepository {
  final Map<String, MomentInstance> instances = <String, MomentInstance>{};

  @override
  Future<MomentInstance?> getInstance({
    required String familyId,
    required String instanceId,
  }) async {
    return instances[instanceId];
  }

  @override
  Future<MomentInstance> scheduleOccurrence({
    required FamilyMoment moment,
    required DateTime scheduledStartAt,
    DateTime? scheduledEndAt,
    required String createdBy,
    MomentInstanceSource source = MomentInstanceSource.manual,
  }) async {
    final result = await materializeOccurrence(
      moment: moment,
      scheduledStartAt: scheduledStartAt,
      scheduledEndAt: scheduledEndAt,
      createdBy: createdBy,
      source: source,
    );
    return result.instance;
  }

  @override
  Future<OccurrenceMaterializationResult> materializeOccurrence({
    required FamilyMoment moment,
    required DateTime scheduledStartAt,
    DateTime? scheduledEndAt,
    required String createdBy,
    MomentInstanceSource source = MomentInstanceSource.calendar,
  }) async {
    final id = _occurrenceId(moment.id, scheduledStartAt);
    final existing = instances[id];
    if (existing != null) {
      return OccurrenceMaterializationResult(
        instance: existing,
        wasCreated: false,
      );
    }

    final instance = MomentInstance.scheduledFromMoment(
      id: id,
      moment: moment,
      source: source,
      createdBy: createdBy,
      scheduledStartAt: scheduledStartAt,
      scheduledEndAt: scheduledEndAt,
      now: DateTime.utc(2026, 9, 1),
    );
    instances[id] = instance;
    return OccurrenceMaterializationResult(
      instance: instance,
      wasCreated: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

String _occurrenceId(String momentId, DateTime start) {
  return 'instance_${momentId}_${start.toUtc().millisecondsSinceEpoch}';
}
