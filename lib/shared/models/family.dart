import 'package:cloud_firestore/cloud_firestore.dart';

class Family {
  const Family({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.countryCode,
    required this.city,
    required this.preferredLanguage,
    required this.setupComplete,
    required this.createdAt,
    required this.updatedAt,
    this.activeInvitationCode,
  });

  final String id;
  final String name;
  final String createdBy;
  final String countryCode;
  final String city;
  final String preferredLanguage;
  final bool setupComplete;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? activeInvitationCode;

  factory Family.fromMap(String id, Map<String, dynamic> map) {
    return Family(
      id: id,
      name: map['name'] as String,
      createdBy: map['createdBy'] as String,
      countryCode: map['countryCode'] as String,
      city: map['city'] as String,
      preferredLanguage: map['preferredLanguage'] as String,
      setupComplete: map['setupComplete'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      activeInvitationCode: map['activeInvitationCode'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'countryCode': countryCode,
      'city': city,
      'preferredLanguage': preferredLanguage,
      'setupComplete': setupComplete,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'activeInvitationCode': activeInvitationCode,
    };
  }
}
