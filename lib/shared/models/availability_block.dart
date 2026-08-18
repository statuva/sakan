import 'package:cloud_firestore/cloud_firestore.dart';

import 'schedule_block.dart';

class AvailabilityBlock {
  const AvailabilityBlock({
    required this.id,
    required this.familyId,
    required this.memberId,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    required this.isRecurring,
    required this.updatedAt,
  });

  final String id;
  final String familyId;
  final String memberId;

  /// 1 = Monday, 7 = Sunday.
  final int dayOfWeek;

  /// Number of minutes after midnight.
  final int startMinutes;
  final int endMinutes;

  final bool isRecurring;
  final DateTime updatedAt;

  factory AvailabilityBlock.fromScheduleBlock({
    required String id,
    required ScheduleBlock block,
  }) {
    return AvailabilityBlock(
      id: id,
      familyId: block.familyId,
      memberId: block.memberId,
      dayOfWeek: block.dayOfWeek,
      startMinutes: block.startMinutes,
      endMinutes: block.endMinutes,
      isRecurring: block.isRecurring,
      updatedAt: block.updatedAt,
    );
  }

  factory AvailabilityBlock.fromMap(String id, Map<String, dynamic> map) {
    return AvailabilityBlock(
      id: id,
      familyId: map['familyId'] as String,
      memberId: map['memberId'] as String,
      dayOfWeek: map['dayOfWeek'] as int,
      startMinutes: map['startMinutes'] as int,
      endMinutes: map['endMinutes'] as int,
      isRecurring: map['isRecurring'] as bool? ?? true,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'memberId': memberId,
      'dayOfWeek': dayOfWeek,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'isRecurring': isRecurring,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
