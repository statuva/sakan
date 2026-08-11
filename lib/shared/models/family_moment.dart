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
  });

  final String id;
  final String familyId;
  final String title;

  final MomentType type;
  final MomentCategory category;

  final int importanceLevel;

  final List<String> expectedParticipantIds;

  final DateTime startAt;
  final DateTime? endAt;

  final int? expectedIntervalDays;

  final String? location;
  final String? notes;

  final EvidenceType evidenceType;
  final MomentStatus status;

  final String createdBy;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory FamilyMoment.fromMap(String id, Map<String, dynamic> map) {
    return FamilyMoment(
      id: id,
      familyId: map['familyId'] as String,
      title: map['title'] as String,
      type: MomentType.values.byName(map['type'] as String),
      category: MomentCategory.values.byName(map['category'] as String),
      importanceLevel: map['importanceLevel'] as int,
      expectedParticipantIds: List<String>.from(
        map['expectedParticipantIds'] ?? [],
      ),
      startAt: (map['startAt'] as Timestamp).toDate(),
      endAt: map['endAt'] == null ? null : (map['endAt'] as Timestamp).toDate(),
      expectedIntervalDays: map['expectedIntervalDays'] as int?,
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      evidenceType: EvidenceType.values.byName(map['evidenceType'] as String),
      status: MomentStatus.values.byName(map['status'] as String),
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'title': title,
      'type': type.name,
      'category': category.name,
      'importanceLevel': importanceLevel,
      'expectedParticipantIds': expectedParticipantIds,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
      'expectedIntervalDays': expectedIntervalDays,
      'location': location,
      'notes': notes,
      'evidenceType': evidenceType.name,
      'status': status.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
