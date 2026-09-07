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

  /// Calendar expands the most urgent concrete plan. Home may show the same
  /// plan's first task while Calendar exposes its supporting tasks.
  static FamilyInsightItem? calendarFrom(
    Iterable<FamilyInsightItem> insights, {
    String? homeInsightId,
  }) {
    final candidates = insights.toList(growable: false);

    bool isUpcoming(FamilyInsightItem insight) {
      return insight.kind == FamilyInsightKind.upcomingMilestone ||
          insight.kind == FamilyInsightKind.carePreparation ||
          insight.kind == FamilyInsightKind.upcomingMoment ||
          insight.kind == FamilyInsightKind.sharedMomentOpportunity;
    }

    final planning = candidates.where((insight) {
      return isUpcoming(insight) ||
          insight.kind == FamilyInsightKind.overdueReminder ||
          insight.actionType == FamilyInsightActionType.scheduleMoment ||
          insight.actionType == FamilyInsightActionType.openSimulation;
    }).toList(growable: false)
      ..sort((left, right) {
        final priority = left.priority.compareTo(right.priority);
        if (priority != 0) return priority;

        final leftTime = left.recommendedActionAt ?? DateTime(9999);
        final rightTime = right.recommendedActionAt ?? DateTime(9999);
        final timing = leftTime.compareTo(rightTime);
        if (timing != 0) return timing;

        if (homeInsightId != null) {
          if (left.id == homeInsightId && right.id != homeInsightId) return -1;
          if (right.id == homeInsightId && left.id != homeInsightId) return 1;
        }

        return left.id.compareTo(right.id);
      });

    return planning.isEmpty ? null : planning.first;
  }
}
