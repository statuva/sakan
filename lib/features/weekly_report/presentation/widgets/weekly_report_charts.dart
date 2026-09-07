import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/family_weekly_report.dart';

class WeeklyCompletionChart extends StatelessWidget {
  const WeeklyCompletionChart({required this.report, super.key});

  final FamilyWeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final rate = report.completionRate;
    final percentage = rate == null ? null : (rate * 100).round();

    return Semantics(
      label: rate == null
          ? 'No resolved Moments this week'
          : '$percentage percent of resolved Moments were completed',
      child: SizedBox(
        width: 150,
        height: 150,
        child: CustomPaint(
          painter: _CompletionRingPainter(rate: rate ?? 0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      percentage == null ? '—' : '$percentage%',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'completion',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WeeklyActivityChart extends StatelessWidget {
  const WeeklyActivityChart({required this.days, super.key});

  final List<WeeklyDayActivity> days;

  @override
  Widget build(BuildContext context) {
    final maximum = days.fold<int>(
      1,
      (value, day) => math.max(value, day.occurrenceCount),
    );

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: days
              .map((day) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _DayBar(day: day, maximum: maximum),
                  ),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: AppSpacing.md),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            _LegendDot(color: AppColors.success, label: 'Completed'),
            _LegendDot(color: AppColors.error, label: 'Missed'),
            _LegendDot(color: AppColors.info, label: 'Unresolved'),
            _LegendDot(color: AppColors.disabled, label: 'Cancelled'),
          ],
        ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.day, required this.maximum});

  final WeeklyDayActivity day;
  final int maximum;

  @override
  Widget build(BuildContext context) {
    const chartHeight = 150.0;
    final height = day.occurrenceCount == 0
        ? 4.0
        : math.max(16.0, chartHeight * day.occurrenceCount / maximum);

    return Semantics(
      label:
          '${DateFormat('EEEE').format(day.date)}: '
          '${day.completedCount} completed, '
          '${day.missedCount} missed, '
          '${day.pendingReviewCount} unresolved, '
          '${day.cancelledCount} cancelled',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: chartHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 24,
                  height: height,
                  child: day.occurrenceCount == 0
                      ? const ColoredBox(color: AppColors.linen)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (day.completedCount > 0)
                              Expanded(
                                flex: day.completedCount,
                                child: const ColoredBox(
                                  color: AppColors.success,
                                ),
                              ),
                            if (day.missedCount > 0)
                              Expanded(
                                flex: day.missedCount,
                                child: const ColoredBox(color: AppColors.error),
                              ),
                            if (day.pendingReviewCount > 0)
                              Expanded(
                                flex: day.pendingReviewCount,
                                child: const ColoredBox(color: AppColors.info),
                              ),
                            if (day.cancelledCount > 0)
                              Expanded(
                                flex: day.cancelledCount,
                                child: const ColoredBox(
                                  color: AppColors.disabled,
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            DateFormat('E').format(day.date).substring(0, 1),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _CompletionRingPainter extends CustomPainter {
  const _CompletionRingPainter({required this.rate});

  final double rate;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final background = Paint()
      ..color = AppColors.linen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final foreground = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, background);
    if (rate > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * rate.clamp(0.0, 1.0).toDouble(),
        false,
        foreground,
      );
    }
  }

  @override
  bool shouldRepaint(_CompletionRingPainter oldDelegate) {
    return oldDelegate.rate != rate;
  }
}
