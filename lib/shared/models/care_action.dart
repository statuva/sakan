import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_enums.dart';

class CareAction {
  const CareAction({
    required this.id,
    required this.familyId,
    required this.title,
    required this.reason,
    required this.assignedMemberId,
    required this.dueAt,
    required this.status,
    required this.source,
    required this.evidenceType,
    required this.createdAt,
    required this.updatedAt,
    this.momentId,
    this.instanceId,
    this.completedAt,
  });

  static const Object _notProvided = Object();

  final String id;
  final String familyId;

  /// Null for a manually created personal reminder.
  final String? momentId;

  /// Links a recommendation to one concrete occurrence. Old reminders may
  /// have only momentId and remain readable through the compatibility lookup.
  final String? instanceId;

  final String title;
  final String reason;
  final String assignedMemberId;
  final DateTime dueAt;

  final CareActionStatus status;
  final CareActionSource source;
  final EvidenceType evidenceType;

  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted {
    return status == CareActionStatus.completed;
  }

  bool get isFinished {
    return status == CareActionStatus.completed ||
        status == CareActionStatus.skipped;
  }

  bool isOverdueAt(DateTime referenceTime) {
    return !isFinished && dueAt.toLocal().isBefore(referenceTime.toLocal());
  }

  factory CareAction.fromMap(String id, Map<String, dynamic> map) {
    final momentId = _nonEmptyString(map['momentId']);
    final instanceId = _nonEmptyString(map['instanceId']);

    final fallbackSource = momentId == null
        ? CareActionSource.manual
        : CareActionSource.calendar;

    return CareAction(
      id: id,
      familyId: map['familyId'] as String,
      momentId: momentId,
      instanceId: instanceId,
      title: map['title'] as String? ?? 'Untitled reminder',
      reason: map['reason'] as String? ?? '',
      assignedMemberId: map['assignedMemberId'] as String,
      dueAt: (map['dueAt'] as Timestamp).toDate(),
      status: _enumValueOrFallback(
        CareActionStatus.values,
        map['status'],
        CareActionStatus.pending,
      ),
      source: _enumValueOrFallback(
        CareActionSource.values,
        map['source'],
        fallbackSource,
      ),
      evidenceType: _enumValueOrFallback(
        EvidenceType.values,
        map['evidenceType'],
        EvidenceType.scheduledOnly,
      ),
      completedAt: map['completedAt'] == null
          ? null
          : (map['completedAt'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'familyId': familyId,
      'momentId': momentId,
      'instanceId': instanceId,
      'title': title,
      'reason': reason,
      'assignedMemberId': assignedMemberId,
      'dueAt': Timestamp.fromDate(dueAt),
      'status': status.name,
      'source': source.name,
      'evidenceType': evidenceType.name,
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CareAction copyWith({
    Object? momentId = _notProvided,
    Object? instanceId = _notProvided,
    String? title,
    String? reason,
    String? assignedMemberId,
    DateTime? dueAt,
    CareActionStatus? status,
    CareActionSource? source,
    EvidenceType? evidenceType,
    Object? completedAt = _notProvided,
    DateTime? updatedAt,
  }) {
    return CareAction(
      id: id,
      familyId: familyId,
      momentId: identical(momentId, _notProvided)
          ? this.momentId
          : momentId as String?,
      instanceId: identical(instanceId, _notProvided)
          ? this.instanceId
          : instanceId as String?,
      title: title ?? this.title,
      reason: reason ?? this.reason,
      assignedMemberId: assignedMemberId ?? this.assignedMemberId,
      dueAt: dueAt ?? this.dueAt,
      status: status ?? this.status,
      source: source ?? this.source,
      evidenceType: evidenceType ?? this.evidenceType,
      completedAt: identical(completedAt, _notProvided)
          ? this.completedAt
          : completedAt as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String? _nonEmptyString(Object? value) {
    return value is String && value.trim().isNotEmpty ? value : null;
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
