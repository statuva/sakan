import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_enums.dart';

class Member {
  const Member({
    required this.id,
    required this.familyId,
    required this.displayName,
    required this.role,
    required this.ageGroup,
    required this.interests,
    required this.preferredDays,
    required this.isActive,
    required this.joinedAt,
    required this.updatedAt,
    this.photoUrl,
    this.preferredStartMinutes,
    this.preferredEndMinutes,
    this.relationship = FamilyRelationship.other,
  });

  final String id;
  final String familyId;
  final String displayName;
  final FamilyRole role;
  final AgeGroup ageGroup;
  final String? photoUrl;
  final List<String> interests;
  final List<int> preferredDays;
  final int? preferredStartMinutes;
  final int? preferredEndMinutes;
  final bool isActive;
  final DateTime joinedAt;
  final DateTime updatedAt;
  final FamilyRelationship relationship;

  factory Member.fromMap(String id, Map<String, dynamic> map) {
    return Member(
      id: id,
      familyId: map['familyId'] as String,
      displayName: map['displayName'] as String,
      role: FamilyRole.values.byName(map['role'] as String),
      ageGroup: AgeGroup.values.byName(map['ageGroup'] as String),
      photoUrl: map['photoUrl'] as String?,
      interests: List<String>.from(map['interests'] ?? []),
      preferredDays: List<int>.from(map['preferredDays'] ?? []),
      preferredStartMinutes: map['preferredStartMinutes'] as int?,
      preferredEndMinutes: map['preferredEndMinutes'] as int?,
      isActive: map['isActive'] as bool,
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      relationship: FamilyRelationship.values.byName(
        map['relationship'] as String? ?? 'other',
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'displayName': displayName,
      'role': role.name,
      'ageGroup': ageGroup.name,
      'photoUrl': photoUrl,
      'interests': interests,
      'preferredDays': preferredDays,
      'preferredStartMinutes': preferredStartMinutes,
      'preferredEndMinutes': preferredEndMinutes,
      'isActive': isActive,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'relationship': relationship.name,
    };
  }
}
