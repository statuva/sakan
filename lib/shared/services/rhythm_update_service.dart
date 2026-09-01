import 'dart:math' as math;

import '../models/family_moment.dart';
import '../models/model_enums.dart';
import '../models/moment_instance.dart';
import '../models/rhythm_record.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/moment_instance_repository.dart';
import '../repositories/rhythm_repository.dart';
import 'moment_schedule_resolver.dart';

class RhythmUpdateResult {
  const RhythmUpdateResult({
    required this.moment,
    required this.rhythm,
    required this.nextInstance,
  });

  final FamilyMoment moment;
  final RhythmRecord? rhythm;
  final MomentInstance? nextInstance;
}

class RhythmUpdateService {
  const RhythmUpdateService({
    required CalendarRepository calendarRepository,
    required MomentInstanceRepository momentInstanceRepository,
    required RhythmRepository rhythmRepository,
  }) : _calendarRepository = calendarRepository,
       _momentInstanceRepository = momentInstanceRepository,
       _rhythmRepository = rhythmRepository;

  final CalendarRepository _calendarRepository;
  final MomentInstanceRepository _momentInstanceRepository;
  final RhythmRepository _rhythmRepository;

  Future<RhythmUpdateResult> refreshMoment({
    required String familyId,
    required String momentId,
    required String updatedBy,
    DateTime? now,
  }) async {
    final moment = await _calendarRepository.getMoment(
      familyId: familyId,
      momentId: momentId,
    );

    if (moment == null) {
      throw StateError('The Family Moment definition could not be found.');
    }

    final referenceNow = (now ?? DateTime.now()).toUtc();

    final instances = await _momentInstanceRepository
        .watchMomentInstances(familyId: familyId, momentId: momentId)
        .first;

    if (moment.type == MomentType.singular) {
      final updatedMoment = await _syncSingularDefinition(
        moment: moment,
        instances: instances,
        now: referenceNow,
      );

      return RhythmUpdateResult(
        moment: updatedMoment,
        rhythm: null,
        nextInstance: null,
      );
    }

    final previous = await _rhythmRepository
        .watchRhythm(familyId: familyId, momentId: momentId)
        .first;

    final rhythm = RhythmUpdateService.calculateRecord(
      moment: moment,
      instances: instances,
      previous: previous,
      now: referenceNow,
    );

    final nextResult = await _ensureNextOccurrence(
      moment: moment,
      instances: instances,
      updatedBy: updatedBy,
      now: referenceNow,
    );

    await _rhythmRepository.saveRhythm(rhythm);

    return RhythmUpdateResult(
      moment: nextResult.moment,
      rhythm: rhythm,
      nextInstance: nextResult.instance,
    );
  }

  static RhythmRecord calculateRecord({
    required FamilyMoment moment,
    required List<MomentInstance> instances,
    required DateTime now,
    RhythmRecord? previous,
  }) {
    final referenceNow = now.toUtc();
    final interval = math.max(1, moment.expectedIntervalDays ?? 7);

    final completed =
        instances
            .where(
              (instance) => instance.status == MomentInstanceStatus.completed,
            )
            .toList()
          ..sort(
            (first, second) =>
                first.effectiveStartAt.compareTo(second.effectiveStartAt),
          );

    final missed =
        instances
            .where((instance) => instance.status == MomentInstanceStatus.missed)
            .toList()
          ..sort(
            (first, second) =>
                first.scheduledStartAt.compareTo(second.scheduledStartAt),
          );

    final lastOccurrence = completed.isEmpty
        ? null
        : completed.last.effectiveStartAt.toUtc();

    final currentGapDays = lastOccurrence == null
        ? 0
        : math.max(
            0,
            _dateOnly(
              referenceNow,
            ).difference(_dateOnly(lastOccurrence)).inDays,
          );

    final missedAfterLastOccurrence = missed.any(
      (instance) =>
          lastOccurrence == null ||
          instance.scheduledStartAt.toUtc().isAfter(lastOccurrence),
    );

    final confidence = _confidenceFor(completed);

    final status = _statusFor(
      completed: completed,
      currentGapDays: currentGapDays,
      expectedIntervalDays: interval,
      missedAfterLastOccurrence: missedAfterLastOccurrence,
      previous: previous,
    );

    return RhythmRecord(
      id: moment.id,
      familyId: moment.familyId,
      momentId: moment.id,
      expectedIntervalDays: interval,
      lastOccurrenceAt: lastOccurrence,
      currentGapDays: currentGapDays,
      occurrenceCount: completed.length,
      status: status,
      confidence: confidence,
      updatedAt: referenceNow,
    );
  }

  Future<FamilyMoment> _syncSingularDefinition({
    required FamilyMoment moment,
    required List<MomentInstance> instances,
    required DateTime now,
  }) async {
    final terminal = instances.where((instance) => instance.isFinished).toList()
      ..sort((first, second) => second.updatedAt.compareTo(first.updatedAt));

    if (terminal.isEmpty) {
      return moment;
    }

    final latest = terminal.first;

    final status = switch (latest.status) {
      MomentInstanceStatus.completed => MomentStatus.completed,
      MomentInstanceStatus.missed => MomentStatus.missed,
      MomentInstanceStatus.cancelled => MomentStatus.cancelled,
      _ => moment.status,
    };

    final updated = moment.copyWith(
      startAt: latest.effectiveStartAt.toUtc(),
      endAt: latest.effectiveEndAt?.toUtc(),
      status: status,
      evidenceType: latest.status == MomentInstanceStatus.completed
          ? EvidenceType.userConfirmed
          : moment.evidenceType,
      updatedAt: now,
    );

    await _calendarRepository.saveMoment(updated);
    return updated;
  }

  Future<_NextOccurrenceResult> _ensureNextOccurrence({
    required FamilyMoment moment,
    required List<MomentInstance> instances,
    required String updatedBy,
    required DateTime now,
  }) async {
    if (moment.isArchived || moment.isDayFlexible) {
      return _NextOccurrenceResult(moment: moment, instance: null);
    }

    final open = await _momentInstanceRepository.getOpenInstanceForMoment(
      familyId: moment.familyId,
      momentId: moment.id,
    );

    if (open != null) {
      return _NextOccurrenceResult(moment: moment, instance: open);
    }

    final terminal =
        instances
            .where(
              (instance) =>
                  instance.status == MomentInstanceStatus.completed ||
                  instance.status == MomentInstanceStatus.missed,
            )
            .toList()
          ..sort(
            (first, second) =>
                second.effectiveStartAt.compareTo(first.effectiveStartAt),
          );

    if (terminal.isEmpty) {
      return _NextOccurrenceResult(moment: moment, instance: null);
    }

    final latest = terminal.first;

    final nextStart = MomentScheduleResolver.nextExactStart(
      moment: moment,
      after: latest.effectiveStartAt,
      now: now,
    );

    if (nextStart == null) {
      return _NextOccurrenceResult(moment: moment, instance: null);
    }

    final nextEnd =
        MomentScheduleResolver.endForStart(
          start: nextStart,
          endMinutes: moment.resolvedPreferredEndMinutes,
        ) ??
        _fallbackEnd(moment, latest, nextStart);

    final nextMoment = moment.copyWith(
      startAt: nextStart.toUtc(),
      endAt: nextEnd?.toUtc(),
      status: MomentStatus.scheduled,
      evidenceType: EvidenceType.manual,
      updatedAt: now,
    );

    await _calendarRepository.saveMoment(nextMoment);

    final nextInstance = await _momentInstanceRepository
        .syncScheduledInstanceFromMoment(
          moment: nextMoment,
          createdBy: updatedBy,
          source: MomentInstanceSource.calendar,
        );

    return _NextOccurrenceResult(moment: nextMoment, instance: nextInstance);
  }

  static ConfidenceLevel _confidenceFor(List<MomentInstance> completed) {
    if (completed.length < 2) {
      return ConfidenceLevel.low;
    }

    final supportedCount = completed.where((instance) {
      return instance.confirmationLevel == MomentConfirmationLevel.medium ||
          instance.confirmationLevel == MomentConfirmationLevel.high;
    }).length;

    if (completed.length >= 5 && supportedCount >= 3) {
      return ConfidenceLevel.high;
    }

    return ConfidenceLevel.medium;
  }

  static RhythmStatus _statusFor({
    required List<MomentInstance> completed,
    required int currentGapDays,
    required int expectedIntervalDays,
    required bool missedAfterLastOccurrence,
    RhythmRecord? previous,
  }) {
    final driftThreshold = (expectedIntervalDays * 1.5).ceil();

    if (missedAfterLastOccurrence || currentGapDays > driftThreshold) {
      return RhythmStatus.drifting;
    }

    if (completed.length < 2) {
      return RhythmStatus.stillLearning;
    }

    if (previous?.status == RhythmStatus.drifting) {
      return RhythmStatus.recovering;
    }

    if (completed.length >= 4 &&
        currentGapDays <= expectedIntervalDays &&
        _recentIntervalsAreConsistent(completed, expectedIntervalDays)) {
      return RhythmStatus.strengthening;
    }

    return RhythmStatus.stable;
  }

  static bool _recentIntervalsAreConsistent(
    List<MomentInstance> completed,
    int expectedIntervalDays,
  ) {
    if (completed.length < 3) {
      return false;
    }

    final recent = completed.length <= 5
        ? completed
        : completed.sublist(completed.length - 5);

    for (var index = 1; index < recent.length; index++) {
      final gap = _dateOnly(
        recent[index].effectiveStartAt,
      ).difference(_dateOnly(recent[index - 1].effectiveStartAt)).inDays.abs();

      if (gap > (expectedIntervalDays * 1.35).ceil()) {
        return false;
      }
    }

    return true;
  }

  DateTime? _fallbackEnd(
    FamilyMoment moment,
    MomentInstance latest,
    DateTime nextStart,
  ) {
    final instanceEnd = latest.scheduledEndAt;

    if (instanceEnd != null && instanceEnd.isAfter(latest.scheduledStartAt)) {
      return nextStart.add(instanceEnd.difference(latest.scheduledStartAt));
    }

    final momentEnd = moment.endAt;

    if (momentEnd != null && momentEnd.isAfter(moment.startAt)) {
      return nextStart.add(momentEnd.difference(moment.startAt));
    }

    return null;
  }

  static DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

class _NextOccurrenceResult {
  const _NextOccurrenceResult({required this.moment, required this.instance});

  final FamilyMoment moment;
  final MomentInstance? instance;
}
