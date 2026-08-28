import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMemory {
  const FamilyMemory({
    required this.id,
    required this.familyId,
    required this.momentId,
    required this.title,
    required this.occurredAt,
    required this.photoUrls,
    required this.participantIds,
    required this.createdAt,
    required this.updatedAt,
    this.instanceId,
    this.note,
    this.aiReflection,
  });

  final String id;
  final String familyId;
  final String momentId;

  /// New Memories should reference a concrete completed
  /// Moment occurrence. Null keeps older records valid.
  final String? instanceId;

  final String title;
  final DateTime occurredAt;
  final List<String> photoUrls;
  final List<String> participantIds;
  final String? note;
  final String? aiReflection;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FamilyMemory.fromMap(String id, Map<String, dynamic> map) {
    return FamilyMemory(
      id: id,
      familyId: map['familyId'] as String,
      momentId: map['momentId'] as String,
      instanceId: map['instanceId'] as String?,
      title: map['title'] as String,
      occurredAt: (map['occurredAt'] as Timestamp).toDate(),
      photoUrls: List<String>.from(map['photoUrls'] ?? const <String>[]),
      participantIds: List<String>.from(
        map['participantIds'] ?? const <String>[],
      ),
      note: map['note'] as String?,
      aiReflection: map['aiReflection'] as String?,
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
      'occurredAt': Timestamp.fromDate(occurredAt),
      'photoUrls': photoUrls,
      'participantIds': participantIds,
      'note': note,
      'aiReflection': aiReflection,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
