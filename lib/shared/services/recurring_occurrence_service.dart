import '../models/family_moment.dart';
import '../models/model_enums.dart';
import '../repositories/moment_instance_repository.dart';
import 'moment_schedule_resolver.dart';

/// Materializes only a rolling Calendar window. It never creates an infinite
/// recurrence series, and scheduleOccurrence uses deterministic IDs so calling
/// this repeatedly does not create duplicates.
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

        await _repository.scheduleOccurrence(
          moment: moment,
          scheduledStartAt: start,
          scheduledEndAt: end,
          createdBy: createdBy,
          source: MomentInstanceSource.calendar,
        );
        writes++;
      }
    }

    return writes;
  }

  List<DateTime> startsInRange({
    required FamilyMoment moment,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    if (moment.type != MomentType.recurring ||
        moment.isDayFlexible ||
        moment.isArchived) {
      return const <DateTime>[];
    }

    final localStart = DateTime(
      rangeStart.toLocal().year,
      rangeStart.toLocal().month,
      rangeStart.toLocal().day,
    );
    final localEnd = DateTime(
      rangeEnd.toLocal().year,
      rangeEnd.toLocal().month,
      rangeEnd.toLocal().day,
      23,
      59,
      59,
    );

    final interval = moment.expectedIntervalDays ?? 7;
    final minutes = moment.resolvedPreferredStartMinutes;
    final results = <DateTime>[];

    DateTime atMinutes(DateTime date) =>
        DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);

    if (interval == 1) {
      var cursor = localStart;
      while (!cursor.isAfter(localEnd)) {
        results.add(atMinutes(cursor));
        cursor = cursor.add(const Duration(days: 1));
      }
      return results;
    }

    if (interval == 7 || interval == 14) {
      final weekday =
          moment.preferredWeekday ?? moment.startAt.toLocal().weekday;
      var cursor = localStart;
      while (cursor.weekday != weekday) {
        cursor = cursor.add(const Duration(days: 1));
      }

      final anchor = moment.startAt.toLocal();
      while (!cursor.isAfter(localEnd)) {
        final daysFromAnchor = DateTime(
          cursor.year,
          cursor.month,
          cursor.day,
        ).difference(DateTime(anchor.year, anchor.month, anchor.day)).inDays;
        if (interval == 7 || daysFromAnchor % 14 == 0) {
          results.add(atMinutes(cursor));
        }
        cursor = cursor.add(const Duration(days: 7));
      }
      return results;
    }

    if (interval == 30 || interval == 90) {
      final monthStep = interval == 30 ? 1 : 3;
      var year = localStart.year;
      var month = localStart.month;
      final anchor = moment.startAt.toLocal();
      final day = moment.preferredDayOfMonth ?? anchor.day;

      while (DateTime(
        year,
        month,
        1,
      ).isBefore(DateTime(localEnd.year, localEnd.month + 1, 1))) {
        final monthsFromAnchor =
            (year - anchor.year) * 12 + month - anchor.month;
        if (monthsFromAnchor % monthStep == 0) {
          final maxDay = MomentScheduleResolver.daysInMonth(year, month);
          final candidate = DateTime(
            year,
            month,
            day.clamp(1, maxDay).toInt(),
            minutes ~/ 60,
            minutes % 60,
          );
          if (!candidate.isBefore(localStart) && !candidate.isAfter(localEnd)) {
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
      final month = moment.preferredMonth ?? moment.startAt.toLocal().month;
      final day = moment.preferredDayOfMonth ?? moment.startAt.toLocal().day;
      for (var year = localStart.year; year <= localEnd.year; year++) {
        final maxDay = MomentScheduleResolver.daysInMonth(year, month);
        final candidate = DateTime(
          year,
          month,
          day.clamp(1, maxDay).toInt(),
          minutes ~/ 60,
          minutes % 60,
        );
        if (!candidate.isBefore(localStart) && !candidate.isAfter(localEnd)) {
          results.add(candidate);
        }
      }
      return results;
    }

    var cursor = moment.startAt.toLocal();
    final safeInterval = interval <= 0 ? 1 : interval;
    while (cursor.isBefore(localStart)) {
      cursor = cursor.add(Duration(days: safeInterval));
    }
    while (!cursor.isAfter(localEnd)) {
      results.add(cursor);
      cursor = cursor.add(Duration(days: safeInterval));
    }
    return results;
  }
}
