import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_insight_report.dart';
import '../../../../shared/ai/ai_models.dart';
import 'calendar_palette.dart';
import 'family_insight_dialog.dart';
import 'family_insight_notice_card.dart';

class FamilyInsightSection extends StatelessWidget {
  const FamilyInsightSection({
    required this.insight,
    required this.aiNarrative,
    required this.onPerformAction,
    super.key,
  });

  final FamilyInsightItem? insight;
  final Future<SakanAiResult>? aiNarrative;

  final Future<void> Function(FamilyInsightItem insight) onPerformAction;

  @override
  Widget build(BuildContext context) {
    final item = insight;
    if (item == null) {
      return const _NoFamilyInsightCard();
    }

    return FamilyInsightNoticeCard(
      insight: item,
      aiNarrative: aiNarrative,
      onOpen: () {
        _openDialog(context, item);
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
        return FutureBuilder<SakanAiResult>(
          future: aiNarrative,
          builder: (context, snapshot) {
            return FamilyInsightDialog(
              insight: insight,
              aiNarrative: snapshot.data,
              onPrimaryAction:
                  insight.actionType == FamilyInsightActionType.none
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      unawaited(onPerformAction(insight));
                    },
            );
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
            'Nothing separate to prepare',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: CalendarPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sakan will add one clear Calendar step when an upcoming Moment '
            'needs it.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: CalendarPalette.inkSoft),
          ),
        ],
      ),
    );
  }
}
