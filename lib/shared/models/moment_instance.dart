import 'package:cloud_firestore/cloud_firestore.dart';

import 'family_moment.dart';
import 'model_enums.dart';

class MomentInstance {
  MomentInstance({
    required this.id,
    required this.familyId,
    required this.momentId,
    required this.titleSnapshot,
    required this.typeSnapshot,
    required this.categorySnapshot,
    required this.importanceLevelSnapshot,
    required List<String> expectedParticipantIds,
    required this.source,
    required this.status,
    required this.scheduledStartAt,
    required List<String> confirmedParticipantIds,
    required List<String> reportedParticipantIds,
    required List<MomentEvidenceSignal> evidenceSignals,
    required this.confirmationLevel,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.locationSnapshot,
    this.scheduledEndAt,
    this.actualStartAt,
    this.actualEndAt,
    this.actualDurationMinutes,
    this.startedBy,
    this.endedBy,
    this.reviewNote,
    this.reviewedBy,
    this.reviewedAt,
    this.isPartial = false,
  }) : expectedParticipantIds = List<String>.unmodifiable(
         expectedParticipantIds,
       ),
       confirmedParticipantIds = List<String>.unmodifiable(
         confirmedParticipantIds,
       ),
       reportedParticipantIds = List<String>.unmodifiable(
         reportedParticipantIds,
       ),
       evidenceSignals = List<MomentEvidenceSignal>.unmodifiable(
         evidenceSignals,
       );

  static const Object _unset = Object();

  final String id;
  final String familyId;
  final String momentId;

  final String titleSnapshot;
  final MomentType typeSnapshot;
  final MomentCategory categorySnapshot;
  final int importanceLevelSnapshot;
  final String? locationSnapshot;

  final List<String> expectedParticipantIds;

  final MomentInstanceSource source;
  final MomentInstanceStatus status;

  final DateTime scheduledStartAt;
  final DateTime? scheduledEndAt;

  final DateTime? actualStartAt;
  final DateTime? actualEndAt;
  final int? actualDurationMinutes;

  final String? startedBy;
  final String? endedBy;

  /// Self-confirmed participation, normally created through
  /// the Live Moment check-in flow.
  final List<String> confirmedParticipantIds;

  /// Participants reported by an adult during Today Review.
  /// These are lower-confidence than self check-ins.
  final List<String> reportedParticipantIds;

  final List<MomentEvidenceSignal> evidenceSignals;
  final MomentConfirmationLevel confirmationLevel;

  final String? reviewNote;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  final bool isPartial;

  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive {
    return status == MomentInstanceStatus.active;
  }

  bool get isCompleted {
    return status == MomentInstanceStatus.completed;
  }

  bool get isFinished {
    return status == MomentInstanceStatus.completed ||
        status == MomentInstanceStatus.missed ||
        status == MomentInstanceStatus.cancelled;
  }

  bool get isOpen => !isFinished;

  DateTime get effectiveStartAt {
    return actualStartAt ?? scheduledStartAt;
  }

  DateTime? get effectiveEndAt {
    return actualEndAt ?? scheduledEndAt;
  }

  List<String> get allRecordedParticipantIds {
    final result = <String>{
      ...confirmedParticipantIds,
      ...reportedParticipantIds,
    }.toList()..sort();

    return result;
  }

  factory MomentInstance.scheduledFromMoment({
    required String id,
    required FamilyMoment moment,
    required MomentInstanceSource source,
    required String createdBy,
    DateTime? scheduledStartAt,
    DateTime? scheduledEndAt,
    DateTime? now,
  }) {
    final createdAt = (now ?? DateTime.now()).toUtc();

    return MomentInstance(
      id: id,
      familyId: moment.familyId,
      momentId: moment.id,
      titleSnapshot: moment.title,
      typeSnapshot: moment.type,
      categorySnapshot: moment.category,
      importanceLevelSnapshot: moment.importanceLevel,
      locationSnapshot: moment.location,
      expectedParticipantIds: moment.expectedParticipantIds,
      source: source,
      status: MomentInstanceStatus.scheduled,
      scheduledStartAt: (scheduledStartAt ?? moment.startAt).toUtc(),
      scheduledEndAt: (scheduledEndAt ?? moment.endAt)?.toUtc(),
      confirmedParticipantIds: const <String>[],
      reportedParticipantIds: const <String>[],
      evidenceSignals: const <MomentEvidenceSignal>[
        MomentEvidenceSignal.scheduled,
      ],
      confirmationLevel: MomentConfirmationLevel.low,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  factory MomentInstance.fromMap(String id, Map<String, dynamic> map) {
    return MomentInstance(
      id: id,
      familyId: map['familyId'] as String,
      momentId: map['momentId'] as String,
      titleSnapshot: map['titleSnapshot'] as String? ?? 'Family Moment',
      typeSnapshot: _enumValueOrFallback(
        MomentType.values,
        map['typeSnapshot'],
        MomentType.singular,
      ),
      categorySnapshot: _enumValueOrFallback(
        MomentCategory.values,
        map['categorySnapshot'],
        MomentCategory.familyTime,
      ),
      importanceLevelSnapshot: map['importanceLevelSnapshot'] as int? ?? 3,
      locationSnapshot: map['locationSnapshot'] as String?,
      expectedParticipantIds: _stringList(map['expectedParticipantIds']),
      source: _enumValueOrFallback(
        MomentInstanceSource.values,
        map['source'],
        MomentInstanceSource.manual,
      ),
      status: _enumValueOrFallback(
        MomentInstanceStatus.values,
        map['status'],
        MomentInstanceStatus.scheduled,
      ),
      scheduledStartAt: (map['scheduledStartAt'] as Timestamp).toDate(),
      scheduledEndAt: _optionalDate(map['scheduledEndAt']),
      actualStartAt: _optionalDate(map['actualStartAt']),
      actualEndAt: _optionalDate(map['actualEndAt']),
      actualDurationMinutes: map['actualDurationMinutes'] as int?,
      startedBy: map['startedBy'] as String?,
      endedBy: map['endedBy'] as String?,
      confirmedParticipantIds: _stringList(map['confirmedParticipantIds']),
      reportedParticipantIds: _stringList(map['reportedParticipantIds']),
      evidenceSignals: _enumList(
        MomentEvidenceSignal.values,
        map['evidenceSignals'],
      ),
      confirmationLevel: _enumValueOrFallback(
        MomentConfirmationLevel.values,
        map['confirmationLevel'],
        MomentConfirmationLevel.low,
      ),
      reviewNote: map['reviewNote'] as String?,
      reviewedBy: map['reviewedBy'] as String?,
      reviewedAt: _optionalDate(map['reviewedAt']),
      isPartial: map['isPartial'] as bool? ?? false,
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'familyId': familyId,
      'momentId': momentId,
      'titleSnapshot': titleSnapshot,
      'typeSnapshot': typeSnapshot.name,
      'categorySnapshot': categorySnapshot.name,
      'importanceLevelSnapshot': importanceLevelSnapshot,
      'locationSnapshot': locationSnapshot,
      'expectedParticipantIds': expectedParticipantIds,
      'source': source.name,
      'status': status.name,
      'scheduledStartAt': Timestamp.fromDate(scheduledStartAt),
      'scheduledEndAt': scheduledEndAt == null
          ? null
          : Timestamp.fromDate(scheduledEndAt!),
      'actualStartAt': actualStartAt == null
          ? null
          : Timestamp.fromDate(actualStartAt!),
      'actualEndAt': actualEndAt == null
          ? null
          : Timestamp.fromDate(actualEndAt!),
      'actualDurationMinutes': actualDurationMinutes,
      'startedBy': startedBy,
      'endedBy': endedBy,
      'confirmedParticipantIds': confirmedParticipantIds,
      'reportedParticipantIds': reportedParticipantIds,
      'evidenceSignals': evidenceSignals.map((item) => item.name).toList(),
      'confirmationLevel': confirmationLevel.name,
      'reviewNote': reviewNote,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
      'isPartial': isPartial,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  MomentInstance copyWith({
    String? titleSnapshot,
    MomentType? typeSnapshot,
    MomentCategory? categorySnapshot,
    int? importanceLevelSnapshot,
    Object? locationSnapshot = _unset,
    List<String>? expectedParticipantIds,
    MomentInstanceSource? source,
    MomentInstanceStatus? status,
    DateTime? scheduledStartAt,
    Object? scheduledEndAt = _unset,
    Object? actualStartAt = _unset,
    Object? actualEndAt = _unset,
    Object? actualDurationMinutes = _unset,
    Object? startedBy = _unset,
    Object? endedBy = _unset,
    List<String>? confirmedParticipantIds,
    List<String>? reportedParticipantIds,
    List<MomentEvidenceSignal>? evidenceSignals,
    MomentConfirmationLevel? confirmationLevel,
    Object? reviewNote = _unset,
    Object? reviewedBy = _unset,
    Object? reviewedAt = _unset,
    bool? isPartial,
    DateTime? updatedAt,
  }) {
    return MomentInstance(
      id: id,
      familyId: familyId,
      momentId: momentId,
      titleSnapshot: titleSnapshot ?? this.titleSnapshot,
      typeSnapshot: typeSnapshot ?? this.typeSnapshot,
      categorySnapshot: categorySnapshot ?? this.categorySnapshot,
      importanceLevelSnapshot:
          importanceLevelSnapshot ?? this.importanceLevelSnapshot,
      locationSnapshot: identical(locationSnapshot, _unset)
          ? this.locationSnapshot
          : locationSnapshot as String?,
      expectedParticipantIds:
          expectedParticipantIds ?? this.expectedParticipantIds,
      source: source ?? this.source,
      status: status ?? this.status,
      scheduledStartAt: scheduledStartAt ?? this.scheduledStartAt,
      scheduledEndAt: identical(scheduledEndAt, _unset)
          ? this.scheduledEndAt
          : scheduledEndAt as DateTime?,
      actualStartAt: identical(actualStartAt, _unset)
          ? this.actualStartAt
          : actualStartAt as DateTime?,
      actualEndAt: identical(actualEndAt, _unset)
          ? this.actualEndAt
          : actualEndAt as DateTime?,
      actualDurationMinutes: identical(actualDurationMinutes, _unset)
          ? this.actualDurationMinutes
          : actualDurationMinutes as int?,
      startedBy: identical(startedBy, _unset)
          ? this.startedBy
          : startedBy as String?,
      endedBy: identical(endedBy, _unset) ? this.endedBy : endedBy as String?,
      confirmedParticipantIds:
          confirmedParticipantIds ?? this.confirmedParticipantIds,
      reportedParticipantIds:
          reportedParticipantIds ?? this.reportedParticipantIds,
      evidenceSignals: evidenceSignals ?? this.evidenceSignals,
      confirmationLevel: confirmationLevel ?? this.confirmationLevel,
      reviewNote: identical(reviewNote, _unset)
          ? this.reviewNote
          : reviewNote as String?,
      reviewedBy: identical(reviewedBy, _unset)
          ? this.reviewedBy
          : reviewedBy as String?,
      reviewedAt: identical(reviewedAt, _unset)
          ? this.reviewedAt
          : reviewedAt as DateTime?,
      isPartial: isPartial ?? this.isPartial,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _optionalDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return value.whereType<String>().toList(growable: false);
  }

  static List<T> _enumList<T extends Enum>(List<T> values, Object? rawValue) {
    if (rawValue is! Iterable) {
      return <T>[];
    }

    final result = <T>[];

    for (final rawItem in rawValue) {
      if (rawItem is! String) {
        continue;
      }

      for (final value in values) {
        if (value.name == rawItem) {
          result.add(value);
          break;
        }
      }
    }

    return result;
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
