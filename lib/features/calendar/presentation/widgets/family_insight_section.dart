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
    required this.onPerformAction,
    super.key,
  });

  final FamilyInsightReport report;

  final Future<void> Function(FamilyInsightItem insight) onPerformAction;

  @override
  Widget build(BuildContext context) {
    final insight = report.primaryInsight;

    if (insight == null) {
      return const _NoFamilyInsightCard();
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
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return FamilyInsightDialog(
          insight: insight,
          onPrimaryAction: insight.actionType == FamilyInsightActionType.none
              ? null
              : () {
                  Navigator.of(dialogContext).pop();
                  unawaited(onPerformAction(insight));
                },
        );
      },
    );
  }
}

class _NoFamilyInsightCard extends StatelessWidget {
  const _NoFamilyInsightCard();

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
            'Sakan will surface a live session, unresolved occurrence, '
            'overdue reminder, milestone, or drifting rhythm when the '
            'recorded data supports it.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: CalendarPalette.inkSoft),
          ),
        ],
      ),
    );
  }
}
