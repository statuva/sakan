import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_enums.dart';

class MomentParticipant {
  const MomentParticipant({
    required this.familyId,
    required this.instanceId,
    required this.memberId,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.checkInMethod,
    this.checkedInAt,
    this.checkedOutAt,
    this.nearbyDetectedAt,
    this.confirmedAt,
  });

  static const Object _unset = Object();

  final String familyId;
  final String instanceId;
  final String memberId;

  final ParticipantMomentState state;
  final MomentCheckInMethod? checkInMethod;

  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final DateTime? nearbyDetectedAt;
  final DateTime? confirmedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasCheckedIn {
    return checkedInAt != null;
  }

  bool get isCurrentlyCheckedIn {
    return state == ParticipantMomentState.checkedIn;
  }

  factory MomentParticipant.checkedIn({
    required String familyId,
    required String instanceId,
    required String memberId,
    required MomentCheckInMethod method,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();

    return MomentParticipant(
      familyId: familyId,
      instanceId: instanceId,
      memberId: memberId,
      state: ParticipantMomentState.checkedIn,
      checkInMethod: method,
      checkedInAt: timestamp,
      confirmedAt: timestamp,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory MomentParticipant.fromMap(String memberId, Map<String, dynamic> map) {
    return MomentParticipant(
      familyId: map['familyId'] as String,
      instanceId: map['instanceId'] as String,
      memberId: map['memberId'] as String? ?? memberId,
      state: _enumValueOrFallback(
        ParticipantMomentState.values,
        map['state'],
        ParticipantMomentState.invited,
      ),
      checkInMethod: _optionalEnum(
        MomentCheckInMethod.values,
        map['checkInMethod'],
      ),
      checkedInAt: _optionalDate(map['checkedInAt']),
      checkedOutAt: _optionalDate(map['checkedOutAt']),
      nearbyDetectedAt: _optionalDate(map['nearbyDetectedAt']),
      confirmedAt: _optionalDate(map['confirmedAt']),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'familyId': familyId,
      'instanceId': instanceId,
      'memberId': memberId,
      'state': state.name,
      'checkInMethod': checkInMethod?.name,
      'checkedInAt': checkedInAt == null
          ? null
          : Timestamp.fromDate(checkedInAt!),
      'checkedOutAt': checkedOutAt == null
          ? null
          : Timestamp.fromDate(checkedOutAt!),
      'nearbyDetectedAt': nearbyDetectedAt == null
          ? null
          : Timestamp.fromDate(nearbyDetectedAt!),
      'confirmedAt': confirmedAt == null
          ? null
          : Timestamp.fromDate(confirmedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  MomentParticipant copyWith({
    ParticipantMomentState? state,
    Object? checkInMethod = _unset,
    Object? checkedInAt = _unset,
    Object? checkedOutAt = _unset,
    Object? nearbyDetectedAt = _unset,
    Object? confirmedAt = _unset,
    DateTime? updatedAt,
  }) {
    return MomentParticipant(
      familyId: familyId,
      instanceId: instanceId,
      memberId: memberId,
      state: state ?? this.state,
      checkInMethod: identical(checkInMethod, _unset)
          ? this.checkInMethod
          : checkInMethod as MomentCheckInMethod?,
      checkedInAt: identical(checkedInAt, _unset)
          ? this.checkedInAt
          : checkedInAt as DateTime?,
      checkedOutAt: identical(checkedOutAt, _unset)
          ? this.checkedOutAt
          : checkedOutAt as DateTime?,
      nearbyDetectedAt: identical(nearbyDetectedAt, _unset)
          ? this.nearbyDetectedAt
          : nearbyDetectedAt as DateTime?,
      confirmedAt: identical(confirmedAt, _unset)
          ? this.confirmedAt
          : confirmedAt as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _optionalDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static T? _optionalEnum<T extends Enum>(List<T> values, Object? rawValue) {
    if (rawValue is String) {
      for (final value in values) {
        if (value.name == rawValue) {
          return value;
        }
      }
    }

    return null;
  }

  static T _enumValueOrFallback<T extends Enum>(
    List<T> values,
    Object? rawValue,
    T fallback,
  ) {
    return _optionalEnum(values, rawValue) ?? fallback;
  }
}
