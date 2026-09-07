import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/shared/models/family_insight_report.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/services/family_insight_surface_selector.dart';

void main() {
  test('Home and Calendar choose the most urgent useful insight', () {
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
    expect(calendar?.id, 'overdue');
  });

  test('Calendar stays empty when there is no planning insight', () {
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

  test('Calendar selects the most urgent planning recommendation', () {
    final laterReminder = _insight(
      id: 'later-reminder',
      kind: FamilyInsightKind.upcomingMilestone,
      actionType: FamilyInsightActionType.addReminder,
      priority: 30,
    );
    final urgentConflict = _insight(
      id: 'urgent-conflict',
      kind: FamilyInsightKind.upcomingMoment,
      actionType: FamilyInsightActionType.openSimulation,
      priority: 10,
    );

    final selected = FamilyInsightSurfaceSelector.calendarFrom(
      <FamilyInsightItem>[laterReminder, urgentConflict],
    );

    expect(selected?.id, urgentConflict.id);
  });

  test('Calendar expands the Home recommendation when it is most urgent', () {
    final home = _insight(
      id: 'home',
      kind: FamilyInsightKind.upcomingMoment,
      actionType: FamilyInsightActionType.addReminder,
      priority: 10,
    );
    final calendar = _insight(
      id: 'calendar',
      kind: FamilyInsightKind.upcomingMilestone,
      actionType: FamilyInsightActionType.addReminder,
      priority: 30,
    );

    final selected = FamilyInsightSurfaceSelector.calendarFrom(
      <FamilyInsightItem>[home, calendar],
      homeInsightId: home.id,
    );

    expect(selected?.id, home.id);
  });

  test('Calendar breaks equal priorities by the earliest action time', () {
    final later = _insight(
      id: 'later',
      kind: FamilyInsightKind.upcomingMoment,
      actionType: FamilyInsightActionType.addReminder,
      priority: 30,
      recommendedActionAt: DateTime.utc(2026, 9, 10),
    );
    final sooner = _insight(
      id: 'sooner',
      kind: FamilyInsightKind.upcomingMoment,
      actionType: FamilyInsightActionType.addReminder,
      priority: 30,
      recommendedActionAt: DateTime.utc(2026, 9, 8),
    );

    final selected = FamilyInsightSurfaceSelector.calendarFrom(
      <FamilyInsightItem>[later, sooner],
    );

    expect(selected?.id, sooner.id);
  });
}

FamilyInsightItem _insight({
  required String id,
  required FamilyInsightKind kind,
  required FamilyInsightActionType actionType,
  required int priority,
  DateTime? recommendedActionAt,
}) {
  return FamilyInsightItem(
    id: id,
    kind: kind,
    actionType: actionType,
    priority: priority,
    headline: id,
    summary: id,
    reasons: const <String>[],
    suggestedActions: const <String>['Do the task.'],
    confidence: ConfidenceLevel.high,
    recommendedActionAt: recommendedActionAt,
  );
}
