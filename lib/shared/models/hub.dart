import 'package:cloud_firestore/cloud_firestore.dart';

class Hub {
  const Hub({
    required this.id,
    required this.familyId,
    required this.name,
    required this.locationLabel,
    required this.tagIdHash,
    required this.isActive,
    required this.registeredBy,
    required this.registeredAt,
    this.lastScannedAt,
  });

  final String id;
  final String familyId;

  final String name;
  final String locationLabel;

  final String tagIdHash;

  final bool isActive;

  final String registeredBy;

  final DateTime registeredAt;
  final DateTime? lastScannedAt;

  factory Hub.fromMap(String id, Map<String, dynamic> map) {
    return Hub(
      id: id,
      familyId: map['familyId'] as String,
      name: map['name'] as String,
      locationLabel: map['locationLabel'] as String,
      tagIdHash: map['tagIdHash'] as String,
      isActive: map['isActive'] as bool,
      registeredBy: map['registeredBy'] as String,
      registeredAt: (map['registeredAt'] as Timestamp).toDate(),
      lastScannedAt: map['lastScannedAt'] == null
          ? null
          : (map['lastScannedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'name': name,
      'locationLabel': locationLabel,
      'tagIdHash': tagIdHash,
      'isActive': isActive,
      'registeredBy': registeredBy,
      'registeredAt': Timestamp.fromDate(registeredAt),
      'lastScannedAt': lastScannedAt == null
          ? null
          : Timestamp.fromDate(lastScannedAt!),
    };
  }
}
