import '../models/daily_review.dart';

abstract interface class DailyReviewRepository {
  Stream<DailyReview?> watchReview({
    required String familyId,
    required DateTime reviewDate,
  });

  Future<DailyReview?> getReview({
    required String familyId,
    required DateTime reviewDate,
  });

  Future<void> saveReview(DailyReview review);
}
