import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../domain/family_weekly_report.dart';

class HomeWeeklyReportCard extends StatelessWidget {
  const HomeWeeklyReportCard({
    required this.report,
    required this.onViewReport,
    this.onEnableNotifications,
    this.isEnablingNotifications = false,
    super.key,
  });

  final FamilyWeeklyReport report;
  final VoidCallback onViewReport;
  final VoidCallback? onEnableNotifications;
  final bool isEnablingNotifications;

  @override
  Widget build(BuildContext context) {
    final weekEnd = DateTime(
      report.weekEndExclusive.year,
      report.weekEndExclusive.month,
      report.weekEndExclusive.day - 1,
    );

    return AppCard(
      color: AppColors.primary.withAlpha(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your weekly family report is ready',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('d MMM').format(report.weekStart)}–'
                      '${DateFormat('d MMM').format(weekEnd)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            report.headline,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _CompactMetric(
                value: '${report.completedCount}',
                label: 'Completed',
                color: AppColors.success,
              ),
              _CompactMetric(
                value: '${report.missedCount}',
                label: 'Missed',
                color: AppColors.error,
              ),
              _CompactMetric(
                value: report.completionRate == null
                    ? '—'
                    : '${(report.completionRate! * 100).round()}%',
                label: 'Completion',
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (onEnableNotifications != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isEnablingNotifications
                    ? null
                    : onEnableNotifications,
                icon: isEnablingNotifications
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.notifications_active_outlined),
                label: Text(
                  isEnablingNotifications ? 'Enabling…' : 'Enable Alert',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onViewReport,
              icon: const Icon(Icons.insights_rounded),
              label: const Text('View Report'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$value $label',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
