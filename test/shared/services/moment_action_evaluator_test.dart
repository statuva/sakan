import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/shared/models/family_insight_report.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_instance.dart';
import 'package:sakan/shared/services/moment_action_evaluator.dart';

void main() {
  test('before a same-day recurring session the action is Add Reminder', () {
    final instance = _instance(
      start: DateTime(2026, 8, 31, 15),
      end: DateTime(2026, 8, 31, 16),
    );

    final decision = MomentActionEvaluator.evaluate(
      instance: instance,
      now: DateTime(2026, 8, 31, 13),
      activeInstance: null,
      canStartSharedMoment: true,
      canReviewSharedMoment: true,
      canCreatePersonalReminder: true,
    );

    expect(decision.actionType, FamilyInsightActionType.addReminder);
    expect(decision.recommendedActionAt, DateTime(2026, 8, 31, 14, 30));
  });

  test('during the planned window the action is Start This Now', () {
    final instance = _instance(
      start: DateTime(2026, 8, 31, 15),
      end: DateTime(2026, 8, 31, 16),
    );

    final decision = MomentActionEvaluator.evaluate(
      instance: instance,
      now: DateTime(2026, 8, 31, 15, 15),
      activeInstance: null,
      canStartSharedMoment: true,
      canReviewSharedMoment: true,
      canCreatePersonalReminder: true,
    );

    expect(decision.actionType, FamilyInsightActionType.startMomentNow);
  });

  test('after the planned end the action is Review Today', () {
    final instance = _instance(
      start: DateTime(2026, 8, 31, 15),
      end: DateTime(2026, 8, 31, 16),
    );

    final decision = MomentActionEvaluator.evaluate(
      instance: instance,
      now: DateTime(2026, 8, 31, 17),
      activeInstance: null,
      canStartSharedMoment: true,
      canReviewSharedMoment: true,
      canCreatePersonalReminder: true,
    );

    expect(decision.actionType, FamilyInsightActionType.reviewToday);
  });
}

MomentInstance _instance({required DateTime start, required DateTime end}) {
  return MomentInstance(
    id: 'instance-1',
    familyId: 'family-1',
    momentId: 'moment-1',
    titleSnapshot: 'Daily Lunch',
    typeSnapshot: MomentType.recurring,
    categorySnapshot: MomentCategory.tradition,
    importanceLevelSnapshot: 4,
    expectedParticipantIds: const <String>['adult', 'child'],
    source: MomentInstanceSource.calendar,
    status: MomentInstanceStatus.scheduled,
    scheduledStartAt: start,
    scheduledEndAt: end,
    confirmedParticipantIds: const <String>[],
    reportedParticipantIds: const <String>[],
    evidenceSignals: const <MomentEvidenceSignal>[
      MomentEvidenceSignal.scheduled,
    ],
    confirmationLevel: MomentConfirmationLevel.low,
    createdBy: 'adult',
    createdAt: start.subtract(const Duration(days: 1)),
    updatedAt: start.subtract(const Duration(days: 1)),
  );
}
