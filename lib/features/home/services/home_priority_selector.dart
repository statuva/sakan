import '../../../shared/models/family_insight_report.dart';

abstract final class HomePrioritySelector {
  /// Home owns shared family attention.
  ///
  /// Generic overdue personal reminders stay in the wide My Reminders card,
  /// so they do not replace a shared family concern in What Matters Now.
  static FamilyInsightItem? select(FamilyInsightReport report) {
    return selectFrom(<FamilyInsightItem>[
      if (report.primaryInsight != null) report.primaryInsight!,
      ...report.secondaryInsights,
    ]);
  }

  static FamilyInsightItem? selectFrom(Iterable<FamilyInsightItem> insights) {
    final candidates = insights
        .where((item) => item.kind != FamilyInsightKind.overdueReminder)
        .toList();

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((first, second) {
      final priorityResult = first.priority.compareTo(second.priority);

      if (priorityResult != 0) {
        return priorityResult;
      }

      final firstTime = first.recommendedActionAt ?? DateTime(9999);
      final secondTime = second.recommendedActionAt ?? DateTime(9999);
      return firstTime.compareTo(secondTime);
    });

    return candidates.first;
  }
}
