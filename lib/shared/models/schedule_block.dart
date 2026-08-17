import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleBlock {
  const ScheduleBlock({
    required this.id,
    required this.familyId,
    required this.memberId,
    required this.label,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    required this.isRecurring,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String familyId;
  final String memberId;

  final String label;

  /// 1 = Monday ... 7 = Sunday
  final int dayOfWeek;

  /// Minutes after midnight.
  final int startMinutes;
  final int endMinutes;

  final bool isRecurring;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory ScheduleBlock.fromMap(String id, Map<String, dynamic> map) {
    return ScheduleBlock(
      id: id,
      familyId: map['familyId'] as String,
      memberId: map['memberId'] as String,
      label: map['label'] as String,
      dayOfWeek: map['dayOfWeek'] as int,
      startMinutes: map['startMinutes'] as int,
      endMinutes: map['endMinutes'] as int,
      isRecurring: map['isRecurring'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'memberId': memberId,
      'label': label,
      'dayOfWeek': dayOfWeek,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'isRecurring': isRecurring,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ScheduleBlock copyWith({
    String? label,
    int? dayOfWeek,
    int? startMinutes,
    int? endMinutes,
    bool? isRecurring,
    DateTime? updatedAt,
  }) {
    return ScheduleBlock(
      id: id,
      familyId: familyId,
      memberId: memberId,
      label: label ?? this.label,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      isRecurring: isRecurring ?? this.isRecurring,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
