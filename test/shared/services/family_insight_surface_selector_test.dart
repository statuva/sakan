import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/shared/models/family_insight_report.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/services/family_insight_surface_selector.dart';

void main() {
  test('Home and Calendar choose different useful insights', () {
    final overdue = _insight(
      id: 'overdue',
      kind: FamilyInsightKind.overdueReminder,
      actionType: FamilyInsightActionType.openReminders,
      priority: 0,
    );
    final review = _insight(
      id: 'review-lunch',
      kind: FamilyInsightKind.reviewNeeded,
      actionType: FamilyInsightActionType.reviewToday,
      priority: 1,
    );
    final preparation = _insight(
      id: 'prepare-birthday',
      kind: FamilyInsightKind.upcomingMilestone,
      actionType: FamilyInsightActionType.addReminder,
      priority: 2,
    );
    final insights = <FamilyInsightItem>[overdue, review, preparation];

    final home = FamilyInsightSurfaceSelector.homeFrom(insights);
    final calendar = FamilyInsightSurfaceSelector.calendarFrom(
      insights,
      homeInsightId: home?.id,
    );

    expect(home?.id, 'review-lunch');
    expect(calendar?.id, 'prepare-birthday');
  });

  test('Calendar does not repeat Home when no separate item exists', () {
    final review = _insight(
      id: 'review-lunch',
      kind: FamilyInsightKind.reviewNeeded,
      actionType: FamilyInsightActionType.reviewToday,
      priority: 0,
    );

    final calendar = FamilyInsightSurfaceSelector.calendarFrom(
      <FamilyInsightItem>[review],
      homeInsightId: review.id,
    );

    expect(calendar, isNull);
  });
}

FamilyInsightItem _insight({
  required String id,
  required FamilyInsightKind kind,
  required FamilyInsightActionType actionType,
  required int priority,
}) {
  return FamilyInsightItem(
    id: id,
    kind: kind,
    actionType: actionType,
    priority: priority,
    headline: id,
    summary: 'summary',
    reasons: const <String>['reason'],
    suggestedActions: const <String>['action'],
    confidence: ConfidenceLevel.high,
  );
}
