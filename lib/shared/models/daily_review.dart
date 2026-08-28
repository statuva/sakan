import 'package:cloud_firestore/cloud_firestore.dart';

class DailyReview {
  DailyReview({
    required this.id,
    required this.familyId,
    required this.dateKey,
    required this.reviewDate,
    required this.reviewedBy,
    required List<String> resolvedInstanceIds,
    required List<String> loggedInstanceIds,
    required this.confirmedNoOtherMoments,
    required this.createdAt,
    required this.updatedAt,
  }) : resolvedInstanceIds = List<String>.unmodifiable(resolvedInstanceIds),
       loggedInstanceIds = List<String>.unmodifiable(loggedInstanceIds);

  final String id;
  final String familyId;
  final String dateKey;
  final DateTime reviewDate;
  final String reviewedBy;
  final List<String> resolvedInstanceIds;
  final List<String> loggedInstanceIds;
  final bool confirmedNoOtherMoments;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DailyReview.fromMap(String id, Map<String, dynamic> map) {
    return DailyReview(
      id: id,
      familyId: map['familyId'] as String,
      dateKey: map['dateKey'] as String,
      reviewDate: (map['reviewDate'] as Timestamp).toDate(),
      reviewedBy: map['reviewedBy'] as String,
      resolvedInstanceIds: List<String>.from(
        map['resolvedInstanceIds'] ?? const <String>[],
      ),
      loggedInstanceIds: List<String>.from(
        map['loggedInstanceIds'] ?? const <String>[],
      ),
      confirmedNoOtherMoments: map['confirmedNoOtherMoments'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'familyId': familyId,
      'dateKey': dateKey,
      'reviewDate': Timestamp.fromDate(reviewDate),
      'reviewedBy': reviewedBy,
      'resolvedInstanceIds': resolvedInstanceIds,
      'loggedInstanceIds': loggedInstanceIds,
      'confirmedNoOtherMoments': confirmedNoOtherMoments,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static String dateKeyFor(DateTime date) {
    final local = date.toLocal();

    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String documentIdFor(DateTime date) {
    return 'review_${dateKeyFor(date)}';
  }

  static DateTime normalizedReviewDate(DateTime date) {
    final local = date.toLocal();
    return DateTime.utc(local.year, local.month, local.day);
  }
}
