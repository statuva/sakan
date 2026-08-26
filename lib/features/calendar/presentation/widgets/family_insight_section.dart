import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_insight_report.dart';
import 'calendar_palette.dart';
import 'family_insight_dialog.dart';
import 'family_insight_notice_card.dart';

class FamilyInsightSection extends StatelessWidget {
  const FamilyInsightSection({
    required this.report,
    required this.onAddReminder,
    required this.onOpenReminders,
    required this.onManageMoments,
    super.key,
  });

  final FamilyInsightReport report;

  final Future<void> Function(FamilyInsightItem insight) onAddReminder;

  final VoidCallback onOpenReminders;
  final VoidCallback onManageMoments;

  @override
  Widget build(BuildContext context) {
    final insight = report.primaryInsight;

    if (insight == null) {
      return _NoFamilyInsightCard(onManageMoments: onManageMoments);
    }

    return FamilyInsightNoticeCard(
      insight: insight,
      onOpen: () {
        _openDialog(context, insight);
      },
    );
  }

  Future<void> _openDialog(
    BuildContext context,
    FamilyInsightItem insight,
  ) async {
    final hasExistingReminder = insight.relatedReminderId != null;

    final canAddReminder =
        !hasExistingReminder && insight.recommendedReminderAt != null;

    final String primaryActionLabel;

    if (hasExistingReminder ||
        insight.kind == FamilyInsightKind.overdueReminder) {
      primaryActionLabel = 'Open My Reminders';
    } else if (canAddReminder) {
      primaryActionLabel = 'Add Reminder';
    } else {
      primaryActionLabel = 'Manage Moments';
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return FamilyInsightDialog(
          insight: insight,
          primaryActionLabel: primaryActionLabel,
          onPrimaryAction: () {
            Navigator.of(dialogContext).pop();

            if (hasExistingReminder ||
                insight.kind == FamilyInsightKind.overdueReminder) {
              onOpenReminders();
              return;
            }

            if (canAddReminder) {
              unawaited(onAddReminder(insight));
              return;
            }

            onManageMoments();
          },
        );
      },
    );
  }
}

class _NoFamilyInsightCard extends StatelessWidget {
  const _NoFamilyInsightCard({required this.onManageMoments});

  final VoidCallback onManageMoments;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CalendarPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No urgent action right now',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: CalendarPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sakan will surface an overdue reminder, '
            'upcoming milestone, care need, or drifting '
            'rhythm when the stored data supports it.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: CalendarPalette.inkSoft),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: onManageMoments,
            child: const Text('Manage Moments'),
          ),
        ],
      ),
    );
  }
}
