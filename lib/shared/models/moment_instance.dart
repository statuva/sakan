import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_enums.dart';

class MomentInstance {
  const MomentInstance({
    required this.id,
    required this.familyId,
    required this.momentId,
    required this.scheduledAt,
    required this.status,
    required this.evidenceType,
    required this.actualParticipantIds,
    required this.checkedInMemberIds,
    required this.checkedOutMemberIds,
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String familyId;
  final String momentId;

  final DateTime scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  final MomentStatus status;
  final EvidenceType evidenceType;

  final List<String> actualParticipantIds;
  final List<String> checkedInMemberIds;
  final List<String> checkedOutMemberIds;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory MomentInstance.fromMap(String id, Map<String, dynamic> map) {
    return MomentInstance(
      id: id,
      familyId: map['familyId'] as String,
      momentId: map['momentId'] as String,
      scheduledAt: (map['scheduledAt'] as Timestamp).toDate(),
      startedAt: map['startedAt'] == null
          ? null
          : (map['startedAt'] as Timestamp).toDate(),
      endedAt: map['endedAt'] == null
          ? null
          : (map['endedAt'] as Timestamp).toDate(),
      status: MomentStatus.values.byName(map['status'] as String),
      evidenceType: EvidenceType.values.byName(map['evidenceType'] as String),
      actualParticipantIds: List<String>.from(
        map['actualParticipantIds'] ?? [],
      ),
      checkedInMemberIds: List<String>.from(map['checkedInMemberIds'] ?? []),
      checkedOutMemberIds: List<String>.from(map['checkedOutMemberIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'momentId': momentId,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
      'endedAt': endedAt == null ? null : Timestamp.fromDate(endedAt!),
      'status': status.name,
      'evidenceType': evidenceType.name,
      'actualParticipantIds': actualParticipantIds,
      'checkedInMemberIds': checkedInMemberIds,
      'checkedOutMemberIds': checkedOutMemberIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
