import '../models/family_moment.dart';
import '../models/model_enums.dart';
import '../repositories/moment_instance_repository.dart';
import '../repositories/non_destructive_occurrence_repository.dart';
import 'moment_schedule_resolver.dart';

class RecurringOccurrenceService {
  const RecurringOccurrenceService(this._repository);

  final MomentInstanceRepository _repository;

  Future<int> ensureRange({
    required List<FamilyMoment> moments,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required String createdBy,
  }) async {
    if (rangeEnd.isBefore(rangeStart)) {
      throw ArgumentError('rangeEnd must be on or after rangeStart.');
    }

    var writes = 0;

    for (final moment in moments) {
      if (moment.type != MomentType.recurring ||
          moment.status != MomentStatus.scheduled ||
          moment.isArchived ||
          moment.isDayFlexible ||
          !moment.hasExactRecurringDay) {
        continue;
      }

      for (final start in startsInRange(
        moment: moment,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      )) {
        final end = MomentScheduleResolver.endForStart(
          start: start,
          endMinutes: moment.resolvedPreferredEndMinutes,
        );
        final wasCreated = await _materialize(
          moment: moment,
          scheduledStartAt: start,
          scheduledEndAt: end,
          createdBy: createdBy,
        );
        if (wasCreated) {
          writes++;
        }
      }
    }

    return writes;
  }

  List<DateTime> startsInRange({
    required FamilyMoment moment,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return calculateStartsInRange(
      moment: moment,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  static List<DateTime> calculateStartsInRange({
    required FamilyMoment moment,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    if (moment.type != MomentType.recurring ||
        moment.status != MomentStatus.scheduled ||
        moment.isDayFlexible ||
        moment.isArchived) {
      return const <DateTime>[];
    }

    final rangeStartLocal = rangeStart.toLocal();
    final rangeEndLocal = rangeEnd.toLocal();
    final anchor = moment.startAt.toLocal();
    final localStart = DateTime(
      rangeStartLocal.year,
      rangeStartLocal.month,
      rangeStartLocal.day,
    );
    final localEnd = DateTime(
      rangeEndLocal.year,
      rangeEndLocal.month,
      rangeEndLocal.day,
      23,
      59,
      59,
      999,
      999,
    );
    final anchorDay = DateTime(anchor.year, anchor.month, anchor.day);
    final effectiveStart = localStart.isAfter(anchorDay)
        ? localStart
        : anchorDay;

    if (effectiveStart.isAfter(localEnd)) {
      return const <DateTime>[];
    }

    final interval = moment.expectedIntervalDays ?? 7;
    final preferredMinutes = moment.resolvedPreferredStartMinutes;
    final anchorMinutes = anchor.hour * 60 + anchor.minute;
    final minutes = preferredMinutes >= 0 && preferredMinutes < 24 * 60
        ? preferredMinutes
        : anchorMinutes;
    final results = <DateTime>[];

    DateTime atMinutes(DateTime date) =>
        DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);

    if (interval == 1) {
      var cursor = effectiveStart;
      while (!cursor.isAfter(localEnd)) {
        final candidate = atMinutes(cursor);
        if (!candidate.isBefore(anchor)) {
          results.add(candidate);
        }
        cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
      }
      return results;
    }

    if (interval == 7 || interval == 14) {
      final preferredWeekday = moment.preferredWeekday;
      final weekday = preferredWeekday != null &&
              preferredWeekday >= DateTime.monday &&
              preferredWeekday <= DateTime.sunday
          ? preferredWeekday
          : anchor.weekday;
      var cadenceAnchor = anchorDay;
      while (cadenceAnchor.weekday != weekday) {
        cadenceAnchor = DateTime(
          cadenceAnchor.year,
          cadenceAnchor.month,
          cadenceAnchor.day + 1,
        );
      }
      if (atMinutes(cadenceAnchor).isBefore(anchor)) {
        cadenceAnchor = DateTime(
          cadenceAnchor.year,
          cadenceAnchor.month,
          cadenceAnchor.day + 7,
        );
      }

      var cursor = effectiveStart;
      while (cursor.weekday != weekday) {
        cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
      }

      while (!cursor.isAfter(localEnd)) {
        final daysFromAnchor = _calendarDayDifference(
          cadenceAnchor,
          cursor,
        );
        if (daysFromAnchor >= 0 &&
            (interval == 7 || daysFromAnchor % 14 == 0)) {
          final candidate = atMinutes(cursor);
          if (!candidate.isBefore(anchor)) {
            results.add(candidate);
          }
        }
        cursor = DateTime(cursor.year, cursor.month, cursor.day + 7);
      }
      return results;
    }

    if (interval == 30 || interval == 90) {
      final monthStep = interval == 30 ? 1 : 3;
      var year = effectiveStart.year;
      var month = effectiveStart.month;
      final day = moment.preferredDayOfMonth ?? anchor.day;

      while (DateTime(year, month, 1).isBefore(
        DateTime(localEnd.year, localEnd.month + 1, 1),
      )) {
        final monthsFromAnchor =
            (year - anchor.year) * 12 + month - anchor.month;
        if (monthsFromAnchor >= 0 && monthsFromAnchor % monthStep == 0) {
          final maxDay = MomentScheduleResolver.daysInMonth(year, month);
          final candidate = DateTime(
            year,
            month,
            day.clamp(1, maxDay).toInt(),
            minutes ~/ 60,
            minutes % 60,
          );
          if (!candidate.isBefore(effectiveStart) &&
              !candidate.isBefore(anchor) &&
              !candidate.isAfter(localEnd)) {
            results.add(candidate);
          }
        }
        month++;
        if (month > 12) {
          month = 1;
          year++;
        }
      }
      return results;
    }

    if (interval == 365) {
      final preferredMonth = moment.preferredMonth;
      final month = preferredMonth != null &&
              preferredMonth >= DateTime.january &&
              preferredMonth <= DateTime.december
          ? preferredMonth
          : anchor.month;
      final day = moment.preferredDayOfMonth ?? anchor.day;
      for (var year = effectiveStart.year; year <= localEnd.year; year++) {
        final maxDay = MomentScheduleResolver.daysInMonth(year, month);
        final candidate = DateTime(
          year,
          month,
          day.clamp(1, maxDay).toInt(),
          minutes ~/ 60,
          minutes % 60,
        );
        if (!candidate.isBefore(effectiveStart) &&
            !candidate.isBefore(anchor) &&
            !candidate.isAfter(localEnd)) {
          results.add(candidate);
        }
      }
      return results;
    }

    final safeInterval = interval <= 0 ? 1 : interval;
    var cursor = atMinutes(anchorDay);
    if (cursor.isBefore(anchor)) {
      cursor = DateTime(
        cursor.year,
        cursor.month,
        cursor.day + safeInterval,
        minutes ~/ 60,
        minutes % 60,
      );
    }
    while (cursor.isBefore(effectiveStart)) {
      cursor = DateTime(
        cursor.year,
        cursor.month,
        cursor.day + safeInterval,
        minutes ~/ 60,
        minutes % 60,
      );
    }
    while (!cursor.isAfter(localEnd)) {
      results.add(cursor);
      cursor = DateTime(
        cursor.year,
        cursor.month,
        cursor.day + safeInterval,
        minutes ~/ 60,
        minutes % 60,
      );
    }
    return results;
  }

  Future<bool> _materialize({
    required FamilyMoment moment,
    required DateTime scheduledStartAt,
    required DateTime? scheduledEndAt,
    required String createdBy,
  }) async {
    final repository = _repository;
    if (repository is NonDestructiveOccurrenceRepository) {
      final result = await
          (repository as NonDestructiveOccurrenceRepository)
              .materializeOccurrence(
        moment: moment,
        scheduledStartAt: scheduledStartAt,
        scheduledEndAt: scheduledEndAt,
        createdBy: createdBy,
        source: MomentInstanceSource.calendar,
      );
      return result.wasCreated;
    }

    final id = _scheduledInstanceId(
      momentId: moment.id,
      scheduledStartAt: scheduledStartAt,
    );
    final existing = await repository.getInstance(
      familyId: moment.familyId,
      instanceId: id,
    );
    if (existing != null) {
      return false;
    }

    await repository.scheduleOccurrence(
      moment: moment,
      scheduledStartAt: scheduledStartAt,
      scheduledEndAt: scheduledEndAt,
      createdBy: createdBy,
      source: MomentInstanceSource.calendar,
    );
    return true;
  }

  String _scheduledInstanceId({
    required String momentId,
    required DateTime scheduledStartAt,
  }) {
    return 'instance_${momentId}_'
        '${scheduledStartAt.toUtc().millisecondsSinceEpoch}';
  }

  static int _calendarDayDifference(DateTime start, DateTime end) {
    final startOrdinal = DateTime.utc(start.year, start.month, start.day);
    final endOrdinal = DateTime.utc(end.year, end.month, end.day);
    return endOrdinal.difference(startOrdinal).inDays;
  }
}
