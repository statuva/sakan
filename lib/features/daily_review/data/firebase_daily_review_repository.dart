import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/daily_review.dart';
import '../../../shared/repositories/daily_review_repository.dart';

class FirebaseDailyReviewRepository implements DailyReviewRepository {
  FirebaseDailyReviewRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _reviews(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('dailyReviews');
  }

  DocumentReference<Map<String, dynamic>> _reviewReference({
    required String familyId,
    required DateTime reviewDate,
  }) {
    return _reviews(familyId).doc(DailyReview.documentIdFor(reviewDate));
  }

  @override
  Stream<DailyReview?> watchReview({
    required String familyId,
    required DateTime reviewDate,
  }) {
    return _reviewReference(
      familyId: familyId,
      reviewDate: reviewDate,
    ).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return DailyReview.fromMap(snapshot.id, data);
    });
  }

  @override
  Future<DailyReview?> getReview({
    required String familyId,
    required DateTime reviewDate,
  }) async {
    final snapshot = await _reviewReference(
      familyId: familyId,
      reviewDate: reviewDate,
    ).get();

    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return DailyReview.fromMap(snapshot.id, data);
  }

  @override
  Future<void> saveReview(DailyReview review) {
    return _reviews(
      review.familyId,
    ).doc(review.id).set(review.toMap(), SetOptions(merge: true));
  }
}
