import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakan/core/theme/app_colors.dart';
import 'package:sakan/features/weekly_report/domain/family_weekly_report.dart';
import 'package:sakan/features/weekly_report/presentation/widgets/weekly_report_charts.dart';

void main() {
  testWidgets('activity status segments fill the visible bar width', (
    tester,
  ) async {
    final days = List<WeeklyDayActivity>.generate(7, (index) {
      final hasActivity = index == 0;
      return WeeklyDayActivity(
        date: DateTime(2026, 8, 31 + index),
        occurrenceCount: hasActivity ? 4 : 0,
        completedCount: hasActivity ? 1 : 0,
        missedCount: hasActivity ? 1 : 0,
        pendingReviewCount: hasActivity ? 1 : 0,
        cancelledCount: hasActivity ? 1 : 0,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyActivityChart(days: days),
        ),
      ),
    );

    for (final color in <Color>[
      AppColors.success,
      AppColors.error,
      AppColors.info,
      AppColors.disabled,
    ]) {
      final segment = find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == color,
      );

      expect(segment, findsOneWidget);
      expect(tester.getSize(segment).width, 24);
      expect(tester.getSize(segment).height, greaterThan(0));
    }
  });
}
