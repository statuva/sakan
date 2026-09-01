import '../models/family_moment.dart';
import '../models/model_enums.dart';

abstract final class MomentScheduleResolver {
  static DateTime? firstExactStart({
    required MomentType type,
    required DateTime reference,
    required int startMinutes,
    DateTime? oneTimeDate,
    int intervalDays = 7,
    bool isDayFlexible = false,
    int? preferredWeekday,
    int? preferredDayOfMonth,
    int? preferredMonth,
  }) {
    final localReference = reference.toLocal();

    if (type == MomentType.singular) {
      final date = oneTimeDate;

      if (date == null) {
        throw ArgumentError('A one-time Moment requires a date.');
      }

      return _atMinutes(date.toLocal(), startMinutes);
    }

    if (isDayFlexible) {
      return null;
    }

    return switch (intervalDays) {
      1 => _nextDaily(localReference, startMinutes),
      7 || 14 => _nextWeekday(
        localReference,
        preferredWeekday ?? localReference.weekday,
        startMinutes,
      ),
      30 => _nextMonthly(
        localReference,
        preferredDayOfMonth ?? localReference.day,
        startMinutes,
        monthsStep: 1,
      ),
      90 => _nextMonthly(
        localReference,
        preferredDayOfMonth ?? localReference.day,
        startMinutes,
        monthsStep: 3,
      ),
      365 => _nextYearly(
        localReference,
        preferredMonth ?? localReference.month,
        preferredDayOfMonth ?? localReference.day,
        startMinutes,
      ),
      _ => _nextCustomInterval(localReference, intervalDays, startMinutes),
    };
  }

  static DateTime anchorForFlexible({
    required DateTime reference,
    required int startMinutes,
  }) {
    final localReference = reference.toLocal();
    var candidate = _atMinutes(localReference, startMinutes);

    if (candidate.isBefore(localReference)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    return candidate;
  }

  static DateTime? nextExactStart({
    required FamilyMoment moment,
    required DateTime after,
    required DateTime now,
  }) {
    if (moment.type != MomentType.recurring ||
        moment.isDayFlexible ||
        moment.isArchived) {
      return null;
    }

    final interval = moment.expectedIntervalDays ?? 7;
    final startMinutes = moment.resolvedPreferredStartMinutes;
    final localAfter = after.toLocal();
    final localNow = now.toLocal();

    DateTime advance(DateTime reference) {
      return switch (interval) {
        1 => _atMinutes(reference.add(const Duration(days: 1)), startMinutes),
        7 ||
        14 => _atMinutes(reference.add(Duration(days: interval)), startMinutes),
        30 => _addMonths(
          reference,
          1,
          moment.preferredDayOfMonth ?? reference.day,
          startMinutes,
        ),
        90 => _addMonths(
          reference,
          3,
          moment.preferredDayOfMonth ?? reference.day,
          startMinutes,
        ),
        365 => _addYears(
          reference,
          1,
          moment.preferredMonth ?? reference.month,
          moment.preferredDayOfMonth ?? reference.day,
          startMinutes,
        ),
        _ => _atMinutes(
          reference.add(Duration(days: interval <= 0 ? 1 : interval)),
          startMinutes,
        ),
      };
    }

    var candidate = advance(localAfter);
    final minimum = localNow.add(const Duration(minutes: 5));

    while (!candidate.isAfter(minimum)) {
      candidate = advance(candidate);
    }

    return candidate;
  }

  static DateTime? endForStart({
    required DateTime start,
    required int? endMinutes,
  }) {
    if (endMinutes == null) {
      return null;
    }

    var end = _atMinutes(start.toLocal(), endMinutes);

    if (!end.isAfter(start.toLocal())) {
      end = end.add(const Duration(days: 1));
    }

    return end;
  }

  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static DateTime _nextDaily(DateTime reference, int minutes) {
    var candidate = _atMinutes(reference, minutes);

    if (candidate.isBefore(reference)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    return candidate;
  }

  static DateTime _nextWeekday(DateTime reference, int weekday, int minutes) {
    final safeWeekday = weekday.clamp(DateTime.monday, DateTime.sunday).toInt();
    final daysAhead = (safeWeekday - reference.weekday + 7) % 7;

    var candidate = _atMinutes(
      reference.add(Duration(days: daysAhead)),
      minutes,
    );

    if (candidate.isBefore(reference)) {
      candidate = candidate.add(const Duration(days: 7));
    }

    return candidate;
  }

  static DateTime _nextMonthly(
    DateTime reference,
    int day,
    int minutes, {
    required int monthsStep,
  }) {
    var candidate = _dateInMonth(reference.year, reference.month, day, minutes);

    if (candidate.isBefore(reference)) {
      candidate = _addMonths(reference, monthsStep, day, minutes);
    }

    return candidate;
  }

  static DateTime _nextYearly(
    DateTime reference,
    int month,
    int day,
    int minutes,
  ) {
    var candidate = _dateInMonth(
      reference.year,
      month.clamp(1, 12).toInt(),
      day,
      minutes,
    );

    if (candidate.isBefore(reference)) {
      candidate = _dateInMonth(
        reference.year + 1,
        month.clamp(1, 12).toInt(),
        day,
        minutes,
      );
    }

    return candidate;
  }

  static DateTime _nextCustomInterval(
    DateTime reference,
    int intervalDays,
    int minutes,
  ) {
    var candidate = _atMinutes(reference, minutes);

    if (candidate.isBefore(reference)) {
      candidate = candidate.add(
        Duration(days: intervalDays <= 0 ? 1 : intervalDays),
      );
    }

    return candidate;
  }

  static DateTime _addMonths(
    DateTime reference,
    int months,
    int day,
    int minutes,
  ) {
    final zeroBased = reference.month - 1 + months;
    final year = reference.year + zeroBased ~/ 12;
    final month = zeroBased % 12 + 1;

    return _dateInMonth(year, month, day, minutes);
  }

  static DateTime _addYears(
    DateTime reference,
    int years,
    int month,
    int day,
    int minutes,
  ) {
    return _dateInMonth(
      reference.year + years,
      month.clamp(1, 12).toInt(),
      day,
      minutes,
    );
  }

  static DateTime _dateInMonth(int year, int month, int day, int minutes) {
    final safeMonth = month.clamp(1, 12).toInt();
    final safeDay = day.clamp(1, daysInMonth(year, safeMonth)).toInt();

    return DateTime(year, safeMonth, safeDay, minutes ~/ 60, minutes % 60);
  }

  static DateTime _atMinutes(DateTime date, int minutes) {
    final safeMinutes = minutes.clamp(0, 1439).toInt();

    return DateTime(
      date.year,
      date.month,
      date.day,
      safeMinutes ~/ 60,
      safeMinutes % 60,
    );
  }
}
