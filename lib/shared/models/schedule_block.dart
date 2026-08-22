import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleBlock {
  const ScheduleBlock({
    required this.id,
    required this.familyId,
    required this.memberId,
    required this.label,
    required this.repeatDays,
    required this.startMinutes,
    required this.endMinutes,
    required this.isRecurring,
    required this.createdAt,
    required this.updatedAt,
    this.scheduledDate,
  });

  static const Object _notProvided = Object();

  final String id;
  final String familyId;
  final String memberId;

  final String label;

  /// Used only for weekly recurring entries.
  ///
  /// 1 = Monday ... 7 = Sunday.
  final List<int> repeatDays;

  /// Used only for one-time entries.
  final DateTime? scheduledDate;

  /// Minutes after midnight.
  final int startMinutes;
  final int endMinutes;

  /// true  = weekly routine
  /// false = one-time unavailable period
  final bool isRecurring;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Kept as a compatibility getter for older code.
  ///
  /// New code should normally use [repeatDays] or [scheduledDate].
  int get dayOfWeek {
    if (isRecurring && repeatDays.isNotEmpty) {
      return repeatDays.first;
    }

    return scheduledDate?.weekday ?? 1;
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

  factory ScheduleBlock.fromMap(String id, Map<String, dynamic> map) {
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

    // Backward compatibility:
    // old schedule documents stored only one dayOfWeek.
    final legacyDay = map['dayOfWeek'];

    if (isRecurring && parsedDays.isEmpty && legacyDay is num) {
      final day = legacyDay.toInt();

      if (day >= 1 && day <= 7) {
        parsedDays.add(day);
      }
    }

    final repeatDays = parsedDays.toList()..sort();

    return ScheduleBlock(
      id: id,
      familyId: map['familyId'] as String,
      memberId: map['memberId'] as String,
      label: map['label'] as String,
      repeatDays: isRecurring ? repeatDays : const <int>[],
      scheduledDate: isRecurring ? null : scheduledDate,
      startMinutes: map['startMinutes'] as int,
      endMinutes: map['endMinutes'] as int,
      isRecurring: isRecurring,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'memberId': memberId,
      'label': label,

      // New schedule fields.
      'repeatDays': repeatDays,
      'scheduledDate': scheduledDate == null
          ? null
          : Timestamp.fromDate(scheduledDate!),

      // Kept for compatibility with older data/tools.
      'dayOfWeek': dayOfWeek,

      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'isRecurring': isRecurring,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ScheduleBlock copyWith({
    String? label,
    List<int>? repeatDays,
    Object? scheduledDate = _notProvided,
    int? startMinutes,
    int? endMinutes,
    bool? isRecurring,
    DateTime? updatedAt,
  }) {
    return ScheduleBlock(
      id: id,
      familyId: familyId,
      memberId: memberId,
      label: label ?? this.label,
      repeatDays: repeatDays ?? this.repeatDays,
      scheduledDate: identical(scheduledDate, _notProvided)
          ? this.scheduledDate
          : scheduledDate as DateTime?,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      isRecurring: isRecurring ?? this.isRecurring,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
