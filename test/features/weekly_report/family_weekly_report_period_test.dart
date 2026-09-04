import 'package:flutter_test/flutter_test.dart';
import 'package:sakan/features/weekly_report/domain/family_weekly_report_period.dart';

void main() {
  test('latest completed period is the previous Monday through Sunday', () {
    final period = FamilyWeeklyReportPeriod.latestCompleted(
      now: DateTime(2026, 9, 4, 18, 30),
    );

    expect(period.start, DateTime(2026, 8, 24));
    expect(period.endExclusive, DateTime(2026, 8, 31));
    expect(
      period.inclusiveEnd,
      DateTime(2026, 8, 30, 23, 59, 59, 999, 999),
    );
  });

  test('Monday still selects the fully completed preceding week', () {
    final period = FamilyWeeklyReportPeriod.latestCompleted(
      now: DateTime(2026, 3, 2, 0, 1),
    );

    expect(period.start, DateTime(2026, 2, 23));
    expect(period.endExclusive, DateTime(2026, 3, 2));
  });
}
