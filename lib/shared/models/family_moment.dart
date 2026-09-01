import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_enums.dart';

class FamilyMoment {
  const FamilyMoment({
    required this.id,
    required this.familyId,
    required this.title,
    required this.type,
    required this.category,
    required this.importanceLevel,
    required this.expectedParticipantIds,
    required this.startAt,
    required this.evidenceType,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.endAt,
    this.expectedIntervalDays,
    this.location,
    this.notes,
    this.preferredStartMinutes,
    this.preferredEndMinutes,
    this.preferredWeekday,
    this.preferredDayOfMonth,
    this.preferredMonth,
    this.isDayFlexible = false,
    this.isArchived = false,
  });

  static const Object _unset = Object();

  final String id;
  final String familyId;
  final String title;

  final MomentType type;
  final MomentCategory category;

  final int importanceLevel;
  final List<String> expectedParticipantIds;

  /// For one-time Moments, this is the actual planned date and time.
  ///
  /// For recurring Moments, this is the next exact occurrence when one has
  /// been scheduled. Flexible-day recurring Moments keep this only as a
  /// compatibility anchor; they do not create a MomentInstance until the
  /// family confirms an exact date.
  final DateTime startAt;
  final DateTime? endAt;

  /// Approximate interval used by rhythm calculations.
  /// Calendar-aware recurrence fields below control the actual next date.
  final int? expectedIntervalDays;

  /// Preferred recurring time stored as minutes after midnight.
  final int? preferredStartMinutes;
  final int? preferredEndMinutes;

  /// DateTime weekday values: Monday = 1, Sunday = 7.
  final int? preferredWeekday;

  /// Used for monthly, quarterly, and yearly recurrence.
  final int? preferredDayOfMonth;

  /// Used for yearly recurrence: January = 1, December = 12.
  final int? preferredMonth;

  /// When true, Sakan stores the recurring definition but waits for the
  /// family to confirm an exact occurrence date.
  final bool isDayFlexible;

  /// Definition lifecycle. Occurrence completion/missed state belongs to
  /// MomentInstance, not to this reusable definition.
  final bool isArchived;

  final String? location;
  final String? notes;

  final EvidenceType evidenceType;

  /// Kept for backward compatibility with existing Firestore documents.
  /// New definition forms no longer expose occurrence status to users.
  final MomentStatus status;

  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get resolvedPreferredStartMinutes {
    final local = startAt.toLocal();
    return preferredStartMinutes ?? local.hour * 60 + local.minute;
  }

  int? get resolvedPreferredEndMinutes {
    if (preferredEndMinutes != null) {
      return preferredEndMinutes;
    }

    final localEnd = endAt?.toLocal();
    return localEnd == null ? null : localEnd.hour * 60 + localEnd.minute;
  }

  bool get hasExactRecurringDay {
    return type == MomentType.recurring && !isDayFlexible;
  }

  factory FamilyMoment.fromMap(String id, Map<String, dynamic> map) {
    final type = _enumValueOrFallback(
      MomentType.values,
      map['type'],
      MomentType.singular,
    );

    final startAt = (map['startAt'] as Timestamp).toDate();
    final endAt = map['endAt'] == null
        ? null
        : (map['endAt'] as Timestamp).toDate();

    final localStart = startAt.toLocal();
    final localEnd = endAt?.toLocal();

    final intervalDays = _intOrNull(map['expectedIntervalDays']);

    final status = _enumValueOrFallback(
      MomentStatus.values,
      map['status'],
      MomentStatus.scheduled,
    );

    return FamilyMoment(
      id: id,
      familyId: map['familyId'] as String,
      title: map['title'] as String,
      type: type,
      category: _enumValueOrFallback(
        MomentCategory.values,
        map['category'],
        MomentCategory.familyTime,
      ),
      importanceLevel: _intOrNull(map['importanceLevel']) ?? 3,
      expectedParticipantIds: List<String>.from(
        map['expectedParticipantIds'] ?? const <String>[],
      ),
      startAt: startAt,
      endAt: endAt,
      expectedIntervalDays: intervalDays,
      preferredStartMinutes:
          _intOrNull(map['preferredStartMinutes']) ??
          (type == MomentType.recurring
              ? localStart.hour * 60 + localStart.minute
              : null),
      preferredEndMinutes:
          _intOrNull(map['preferredEndMinutes']) ??
          (type == MomentType.recurring && localEnd != null
              ? localEnd.hour * 60 + localEnd.minute
              : null),
      preferredWeekday:
          _intOrNull(map['preferredWeekday']) ??
          (type == MomentType.recurring &&
                  (intervalDays == 7 || intervalDays == 14)
              ? localStart.weekday
              : null),
      preferredDayOfMonth:
          _intOrNull(map['preferredDayOfMonth']) ??
          (type == MomentType.recurring &&
                  (intervalDays == 30 ||
                      intervalDays == 90 ||
                      intervalDays == 365)
              ? localStart.day
              : null),
      preferredMonth:
          _intOrNull(map['preferredMonth']) ??
          (type == MomentType.recurring && intervalDays == 365
              ? localStart.month
              : null),
      isDayFlexible: map['isDayFlexible'] as bool? ?? false,
      isArchived:
          map['isArchived'] as bool? ??
          (type == MomentType.recurring && status == MomentStatus.cancelled),
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      evidenceType: _evidenceTypeFromMap(map['evidenceType']),
      status: status,
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'familyId': familyId,
      'title': title,
      'type': type.name,
      'category': category.name,
      'importanceLevel': importanceLevel,
      'expectedParticipantIds': expectedParticipantIds,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
      'expectedIntervalDays': expectedIntervalDays,
      'preferredStartMinutes': preferredStartMinutes,
      'preferredEndMinutes': preferredEndMinutes,
      'preferredWeekday': preferredWeekday,
      'preferredDayOfMonth': preferredDayOfMonth,
      'preferredMonth': preferredMonth,
      'isDayFlexible': isDayFlexible,
      'isArchived': isArchived,
      'location': location,
      'notes': notes,
      'evidenceType': evidenceType.name,
      'status': status.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  FamilyMoment copyWith({
    String? title,
    MomentType? type,
    MomentCategory? category,
    int? importanceLevel,
    List<String>? expectedParticipantIds,
    DateTime? startAt,
    Object? endAt = _unset,
    Object? expectedIntervalDays = _unset,
    Object? preferredStartMinutes = _unset,
    Object? preferredEndMinutes = _unset,
    Object? preferredWeekday = _unset,
    Object? preferredDayOfMonth = _unset,
    Object? preferredMonth = _unset,
    bool? isDayFlexible,
    bool? isArchived,
    Object? location = _unset,
    Object? notes = _unset,
    EvidenceType? evidenceType,
    MomentStatus? status,
    DateTime? updatedAt,
  }) {
    return FamilyMoment(
      id: id,
      familyId: familyId,
      title: title ?? this.title,
      type: type ?? this.type,
      category: category ?? this.category,
      importanceLevel: importanceLevel ?? this.importanceLevel,
      expectedParticipantIds:
          expectedParticipantIds ?? this.expectedParticipantIds,
      startAt: startAt ?? this.startAt,
      endAt: identical(endAt, _unset) ? this.endAt : endAt as DateTime?,
      expectedIntervalDays: identical(expectedIntervalDays, _unset)
          ? this.expectedIntervalDays
          : expectedIntervalDays as int?,
      preferredStartMinutes: identical(preferredStartMinutes, _unset)
          ? this.preferredStartMinutes
          : preferredStartMinutes as int?,
      preferredEndMinutes: identical(preferredEndMinutes, _unset)
          ? this.preferredEndMinutes
          : preferredEndMinutes as int?,
      preferredWeekday: identical(preferredWeekday, _unset)
          ? this.preferredWeekday
          : preferredWeekday as int?,
      preferredDayOfMonth: identical(preferredDayOfMonth, _unset)
          ? this.preferredDayOfMonth
          : preferredDayOfMonth as int?,
      preferredMonth: identical(preferredMonth, _unset)
          ? this.preferredMonth
          : preferredMonth as int?,
      isDayFlexible: isDayFlexible ?? this.isDayFlexible,
      isArchived: isArchived ?? this.isArchived,
      location: identical(location, _unset)
          ? this.location
          : location as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      evidenceType: evidenceType ?? this.evidenceType,
      status: status ?? this.status,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static EvidenceType _evidenceTypeFromMap(Object? rawValue) {
    // Compatibility for documents created before the physical Hub feature
    // was removed.
    if (rawValue == 'hubVerified') {
      return EvidenceType.manual;
    }

    return _enumValueOrFallback(
      EvidenceType.values,
      rawValue,
      EvidenceType.manual,
    );
  }

  static int? _intOrNull(Object? rawValue) {
    return rawValue is num ? rawValue.toInt() : null;
  }

  static T _enumValueOrFallback<T extends Enum>(
    List<T> values,
    Object? rawValue,
    T fallback,
  ) {
    if (rawValue is String) {
      for (final value in values) {
        if (value.name == rawValue) {
          return value;
        }
      }
    }

    return fallback;
  }
}
