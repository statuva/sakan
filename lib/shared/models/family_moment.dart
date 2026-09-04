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
    this.format = MomentFormat.sharedSession,
    this.subjectMemberIds = const <String>[],
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

  /// Determines whether this Moment uses Sakan's live-session flow or is
  /// confirmed as an external real-world event.
  final MomentFormat format;

  /// Members the Moment is specifically about, not merely expected to attend.
  /// Example: Ali for "Ali's Graduation" or "Ali's Birthday".
  final List<String> subjectMemberIds;

  final int importanceLevel;
  final List<String> expectedParticipantIds;
  final DateTime startAt;
  final DateTime? endAt;
  final int? expectedIntervalDays;
  final int? preferredStartMinutes;
  final int? preferredEndMinutes;
  final int? preferredWeekday;
  final int? preferredDayOfMonth;
  final int? preferredMonth;
  final bool isDayFlexible;
  final bool isArchived;
  final String? location;
  final String? notes;
  final EvidenceType evidenceType;
  final MomentStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isSharedSession => format == MomentFormat.sharedSession;
  bool get isExternalEvent => format == MomentFormat.externalEvent;

  bool isSubject(String memberId) => subjectMemberIds.contains(memberId);
  bool expects(String memberId) => expectedParticipantIds.contains(memberId);

  int get resolvedPreferredStartMinutes {
    final local = startAt.toLocal();
    return preferredStartMinutes ?? local.hour * 60 + local.minute;
  }

  int? get resolvedPreferredEndMinutes {
    if (preferredEndMinutes != null) return preferredEndMinutes;
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

    final category = _enumValueOrFallback(
      MomentCategory.values,
      map['category'],
      MomentCategory.familyTime,
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

    final explicitFormat = map['format'];
    final format = explicitFormat == null
        ? _legacyFormatForCategory(category)
        : _enumValueOrFallback(
            MomentFormat.values,
            explicitFormat,
            MomentFormat.sharedSession,
          );

    return FamilyMoment(
      id: id,
      familyId: map['familyId'] as String,
      title: map['title'] as String,
      type: type,
      category: category,
      format: format,
      subjectMemberIds: List<String>.from(
        map['subjectMemberIds'] ?? const <String>[],
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
      'format': format.name,
      'subjectMemberIds': subjectMemberIds,
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
    MomentFormat? format,
    List<String>? subjectMemberIds,
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
      format: format ?? this.format,
      subjectMemberIds: subjectMemberIds ?? this.subjectMemberIds,
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

  static MomentFormat _legacyFormatForCategory(MomentCategory category) {
    return switch (category) {
      MomentCategory.milestone ||
      MomentCategory.responsibility ||
      MomentCategory.care => MomentFormat.externalEvent,
      MomentCategory.tradition ||
      MomentCategory.familyTime ||
      MomentCategory.memory => MomentFormat.sharedSession,
    };
  }

  static EvidenceType _evidenceTypeFromMap(Object? rawValue) {
    if (rawValue == 'hubVerified') return EvidenceType.manual;
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
        if (value.name == rawValue) return value;
      }
    }
    return fallback;
  }
}
