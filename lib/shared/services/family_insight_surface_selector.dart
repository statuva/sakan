import '../models/family_insight_report.dart';
import '../models/model_enums.dart';
import 'personalized_family_focus_selector.dart';

/// Keeps Home and Calendar useful for different decisions.
abstract final class FamilyInsightSurfaceSelector {
  static FamilyInsightItem? home(FamilyInsightReport report) {
    return homeFrom(PersonalizedFamilyFocusSelector.selectAll(report));
  }

  /// Home owns the most immediate non-reminder family priority.
  static FamilyInsightItem? homeFrom(Iterable<FamilyInsightItem> insights) {
    for (final insight in insights) {
      if (insight.kind != FamilyInsightKind.overdueReminder) {
        return insight;
      }
    }
    return null;
  }

  static FamilyInsightItem? calendar(FamilyInsightReport report) {
    final insights = PersonalizedFamilyFocusSelector.selectAll(report);
    final currentUserId = report.snapshot.currentUserId;
    final homeHasReadyRoom = report.snapshot.instances.any(
      (instance) =>
          instance.status == MomentInstanceStatus.inviting &&
          instance.expectedParticipantIds.contains(currentUserId),
    );
    final homeInsight = homeHasReadyRoom ? null : homeFrom(insights);
    return calendarFrom(insights, homeInsightId: homeInsight?.id);
  }

  /// Calendar favors concrete planning and never duplicates Home's card.
  static FamilyInsightItem? calendarFrom(
    Iterable<FamilyInsightItem> insights, {
    String? homeInsightId,
  }) {
    final candidates = insights
        .where((insight) => insight.id != homeInsightId)
        .toList(growable: false);

    FamilyInsightItem? firstWhere(
      bool Function(FamilyInsightItem insight) test,
    ) {
      for (final insight in candidates) {
        if (test(insight)) return insight;
      }
      return null;
    }

    bool isUpcoming(FamilyInsightItem insight) {
      return insight.kind == FamilyInsightKind.upcomingMilestone ||
          insight.kind == FamilyInsightKind.carePreparation ||
          insight.kind == FamilyInsightKind.upcomingMoment;
    }

    return firstWhere(
          (insight) =>
              isUpcoming(insight) &&
              insight.actionType == FamilyInsightActionType.addReminder,
        ) ??
        firstWhere(
          (insight) =>
              isUpcoming(insight) &&
              insight.actionType == FamilyInsightActionType.openReminders,
        ) ??
        firstWhere(
          (insight) =>
              insight.actionType == FamilyInsightActionType.scheduleMoment,
        ) ??
        firstWhere(
          (insight) => insight.kind == FamilyInsightKind.overdueReminder,
        ) ??
        firstWhere(isUpcoming);
  }
}
