class FamilyWeeklyReportPeriod {
  const FamilyWeeklyReportPeriod({
    required this.start,
    required this.endExclusive,
  });

  final DateTime start;
  final DateTime endExclusive;

  DateTime get inclusiveEnd => DateTime(
    endExclusive.year,
    endExclusive.month,
    endExclusive.day - 1,
    23,
    59,
    59,
    999,
    999,
  );

  static FamilyWeeklyReportPeriod latestCompleted({DateTime? now}) {
    final reference = (now ?? DateTime.now()).toLocal();
    final today = DateTime(reference.year, reference.month, reference.day);
    final currentWeekStart = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - DateTime.monday),
    );

    return FamilyWeeklyReportPeriod(
      start: DateTime(
        currentWeekStart.year,
        currentWeekStart.month,
        currentWeekStart.day - 7,
      ),
      endExclusive: currentWeekStart,
    );
  }
}
