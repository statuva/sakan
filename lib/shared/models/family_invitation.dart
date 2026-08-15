import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyInvitation {
  const FamilyInvitation({
    required this.code,
    required this.familyId,
    required this.familyName,
    required this.createdBy,
    required this.isActive,
    required this.expiresAt,
    required this.createdAt,
  });

  final String code;
  final String familyId;
  final String familyName;
  final String createdBy;
  final bool isActive;
  final DateTime expiresAt;
  final DateTime createdAt;

  factory FamilyInvitation.fromMap(String code, Map<String, dynamic> map) {
    return FamilyInvitation(
      code: code,
      familyId: map['familyId'] as String,
      familyName: map['familyName'] as String,
      createdBy: map['createdBy'] as String,
      isActive: map['isActive'] as bool,
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'familyId': familyId,
      'familyName': familyName,
      'createdBy': createdBy,
      'isActive': isActive,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
