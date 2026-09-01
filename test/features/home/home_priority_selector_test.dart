import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/features/home/services/home_priority_selector.dart';
import 'package:sakan/shared/models/family_insight_report.dart';
import 'package:sakan/shared/models/model_enums.dart';

void main() {
  test('shared family concern is chosen over a personal overdue reminder', () {
    final selected = HomePrioritySelector.selectFrom(<FamilyInsightItem>[
      _insight(
        id: 'personal-reminder',
        kind: FamilyInsightKind.overdueReminder,
        actionType: FamilyInsightActionType.openReminders,
        priority: 1,
      ),
      _insight(
        id: 'family-review',
        kind: FamilyInsightKind.reviewNeeded,
        actionType: FamilyInsightActionType.reviewToday,
        priority: 15,
      ),
    ]);

    expect(selected?.id, 'family-review');
  });

  test('only personal overdue reminders leaves What Matters Now calm', () {
    final selected = HomePrioritySelector.selectFrom(<FamilyInsightItem>[
      _insight(
        id: 'personal-reminder',
        kind: FamilyInsightKind.overdueReminder,
        actionType: FamilyInsightActionType.openReminders,
        priority: 1,
      ),
    ]);

    expect(selected, isNull);
  });

  test('lowest family priority number wins', () {
    final selected = HomePrioritySelector.selectFrom(<FamilyInsightItem>[
      _insight(
        id: 'later-today',
        kind: FamilyInsightKind.upcomingMoment,
        actionType: FamilyInsightActionType.addReminder,
        priority: 10,
      ),
      _insight(
        id: 'active',
        kind: FamilyInsightKind.activeMoment,
        actionType: FamilyInsightActionType.joinActiveMoment,
        priority: 0,
      ),
    ]);

    expect(selected?.id, 'active');
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
    summary: id,
    reasons: const <String>[],
    suggestedActions: const <String>[],
    confidence: ConfidenceLevel.high,
  );
}
