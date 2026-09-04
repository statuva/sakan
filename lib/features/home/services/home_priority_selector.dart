import '../../../shared/models/family_insight_report.dart';

abstract final class HomePrioritySelector {
  static FamilyInsightItem? select(FamilyInsightReport report) {
    return selectFrom(<FamilyInsightItem>[
      if (report.primaryInsight != null) report.primaryInsight!,
      ...report.secondaryInsights,
    ]);
  }

  /// The insight service already applies the full deterministic ordering.
  /// Filtering must preserve it; sorting again can lose importance tie-breaks.
  static FamilyInsightItem? selectFrom(Iterable<FamilyInsightItem> insights) {
    for (final item in insights) {
      if (item.kind != FamilyInsightKind.overdueReminder) {
        return item;
      }
    }
    return null;
  }
}
