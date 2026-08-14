import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.familyIds,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrl,
    this.currentFamilyId,
  });

  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final List<String> familyIds;
  final String? currentFamilyId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: map['email'] as String,
      displayName: map['displayName'] as String,
      photoUrl: map['photoUrl'] as String?,
      familyIds: List<String>.from(map['familyIds'] ?? []),
      currentFamilyId: map['currentFamilyId'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'familyIds': familyIds,
      'currentFamilyId': currentFamilyId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
