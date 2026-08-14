import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_enums.dart';

class CareAction {
  const CareAction({
    required this.id,
    required this.familyId,
    required this.momentId,
    required this.title,
    required this.reason,
    required this.assignedMemberId,
    required this.dueAt,
    required this.status,
    required this.evidenceType,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String familyId;
  final String momentId;

  final String title;
  final String reason;

  final String assignedMemberId;

  final DateTime dueAt;

  final CareActionStatus status;
  final EvidenceType evidenceType;

  final DateTime? completedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory CareAction.fromMap(String id, Map<String, dynamic> map) {
    return CareAction(
      id: id,
      familyId: map['familyId'] as String,
      momentId: map['momentId'] as String,
      title: map['title'] as String,
      reason: map['reason'] as String,
      assignedMemberId: map['assignedMemberId'] as String,
      dueAt: (map['dueAt'] as Timestamp).toDate(),
      status: CareActionStatus.values.byName(map['status'] as String),
      evidenceType: EvidenceType.values.byName(map['evidenceType'] as String),
      completedAt: map['completedAt'] == null
          ? null
          : (map['completedAt'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'momentId': momentId,
      'title': title,
      'reason': reason,
      'assignedMemberId': assignedMemberId,
      'dueAt': Timestamp.fromDate(dueAt),
      'status': status.name,
      'evidenceType': evidenceType.name,
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
