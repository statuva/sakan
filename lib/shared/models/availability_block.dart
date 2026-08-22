import 'package:cloud_firestore/cloud_firestore.dart';

import 'schedule_block.dart';

class AvailabilityBlock {
  const AvailabilityBlock({
    required this.id,
    required this.familyId,
    required this.memberId,
    required this.repeatDays,
    required this.startMinutes,
    required this.endMinutes,
    required this.isRecurring,
    required this.updatedAt,
    this.scheduledDate,
  });

  final String id;
  final String familyId;
  final String memberId;

  /// Used by weekly recurring availability.
  ///
  /// 1 = Monday ... 7 = Sunday.
  final List<int> repeatDays;

  /// Used by one-time availability.
  final DateTime? scheduledDate;

  final int startMinutes;
  final int endMinutes;

  final bool isRecurring;
  final DateTime updatedAt;

  /// Compatibility getter for older code.
  int get dayOfWeek {
    if (isRecurring && repeatDays.isNotEmpty) {
      return repeatDays.first;
    }

    return scheduledDate?.weekday ?? 1;
  }

  factory AvailabilityBlock.fromScheduleBlock({
    required String id,
    required ScheduleBlock block,
  }) {
    return AvailabilityBlock(
      id: id,
      familyId: block.familyId,
      memberId: block.memberId,
      repeatDays: block.repeatDays,
      scheduledDate: block.scheduledDate,
      startMinutes: block.startMinutes,
      endMinutes: block.endMinutes,
      isRecurring: block.isRecurring,
      updatedAt: block.updatedAt,
    );
  }

  factory AvailabilityBlock.fromMap(String id, Map<String, dynamic> map) {
    final isRecurring = map['isRecurring'] as bool? ?? true;

    final rawScheduledDate = map['scheduledDate'] ?? map['date'];

    DateTime? scheduledDate;

    if (rawScheduledDate is Timestamp) {
      scheduledDate = _dateOnly(rawScheduledDate.toDate().toLocal());
    } else if (rawScheduledDate is DateTime) {
      scheduledDate = _dateOnly(rawScheduledDate.toLocal());
    }

    final parsedDays = <int>{};

    final rawRepeatDays = map['repeatDays'];

    if (rawRepeatDays is Iterable) {
      for (final value in rawRepeatDays) {
        if (value is num) {
          final day = value.toInt();

          if (day >= 1 && day <= 7) {
            parsedDays.add(day);
          }
        }
      }
    }

    // Compatibility with old availability records.
    final legacyDay = map['dayOfWeek'];

    if (isRecurring && parsedDays.isEmpty && legacyDay is num) {
      final day = legacyDay.toInt();

      if (day >= 1 && day <= 7) {
        parsedDays.add(day);
      }
    }

    final repeatDays = parsedDays.toList()..sort();

    return AvailabilityBlock(
      id: id,
      familyId: map['familyId'] as String,
      memberId: map['memberId'] as String,
      repeatDays: isRecurring ? repeatDays : const <int>[],
      scheduledDate: isRecurring ? null : scheduledDate,
      startMinutes: map['startMinutes'] as int,
      endMinutes: map['endMinutes'] as int,
      isRecurring: isRecurring,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  bool occursOn(DateTime targetDate) {
    final target = _dateOnly(targetDate.toLocal());

    if (isRecurring) {
      return repeatDays.contains(target.weekday);
    }

    final date = scheduledDate;

    if (date == null) {
      return false;
    }

    return _sameDate(_dateOnly(date.toLocal()), target);
  }

  bool isExpiredAt(DateTime referenceTime) {
    if (isRecurring) {
      return false;
    }

    final date = scheduledDate;

    if (date == null) {
      return true;
    }

    final localDate = date.toLocal();

    final endDateTime = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
      endMinutes ~/ 60,
      endMinutes % 60,
    );

    return !endDateTime.isAfter(referenceTime.toLocal());
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'memberId': memberId,
      'repeatDays': repeatDays,
      'scheduledDate': scheduledDate == null
          ? null
          : Timestamp.fromDate(scheduledDate!),

      // Kept temporarily for compatibility.
      'dayOfWeek': dayOfWeek,

      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'isRecurring': isRecurring,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
