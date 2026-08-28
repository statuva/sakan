import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/shared/models/daily_review.dart';

void main() {
  test('DailyReview serializes and restores', () {
    final review = DailyReview(
      id: 'review_2026-08-28',
      familyId: 'family-1',
      dateKey: '2026-08-28',
      reviewDate: DateTime.utc(2026, 8, 28),
      reviewedBy: 'member-1',
      resolvedInstanceIds: const <String>[
        'instance-1',
      ],
      loggedInstanceIds: const <String>[
        'instance-2',
      ],
      confirmedNoOtherMoments: true,
      createdAt: DateTime.utc(2026, 8, 28, 20),
      updatedAt: DateTime.utc(2026, 8, 28, 20),
    );

    final restored = DailyReview.fromMap(
      review.id,
      review.toMap(),
    );

    expect(restored.dateKey, '2026-08-28');
    expect(restored.resolvedInstanceIds, <String>['instance-1']);
    expect(restored.loggedInstanceIds, <String>['instance-2']);
    expect(restored.confirmedNoOtherMoments, isTrue);
  });

  test('date key is stable for local dates', () {
    final key = DailyReview.dateKeyFor(
      DateTime(2026, 8, 28, 23, 45),
    );

    expect(key, '2026-08-28');
    expect(
      DailyReview.documentIdFor(
        DateTime(2026, 8, 28),
      ),
      'review_2026-08-28',
    );
  });
}
