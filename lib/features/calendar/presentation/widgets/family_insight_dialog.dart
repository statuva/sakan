import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_insight_report.dart';
import '../../../../shared/ai/ai_models.dart';
import 'calendar_palette.dart';

class FamilyInsightDialog extends StatelessWidget {
  const FamilyInsightDialog({
    required this.insight,
    required this.aiNarrative,
    required this.onPrimaryAction,
    super.key,
  });

  final FamilyInsightItem insight;
  final SakanAiResult? aiNarrative;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = insight.primaryActionLabel;
    final headline = aiNarrative?.title ?? insight.headline;
    final summary = aiNarrative?.text ?? insight.summary;
    final reasons = aiNarrative?.reasons.isNotEmpty == true
        ? aiNarrative!.reasons
        : insight.reasons;
    final suggestedActions = aiNarrative?.suggestedActions.isNotEmpty == true
        ? aiNarrative!.suggestedActions
        : insight.suggestedActions;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: CalendarPalette.forestSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _actionIcon(),
                      color: CalendarPalette.forestDark,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sakan Recommendation',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: CalendarPalette.forestDark,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          headline,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: CalendarPalette.ink),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CalendarPalette.inkSoft,
                  height: 1.5,
                ),
              ),
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Why Sakan surfaced this',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...reasons.map(
                  (reason) => _DialogItem(
                    icon: Icons.check_circle_outline,
                    text: reason,
                  ),
                ),
              ],
              if (suggestedActions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Suggested next steps',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...List.generate(
                  suggestedActions.length,
                  (index) => _NumberedAction(
                    number: index + 1,
                    text: suggestedActions[index],
                  ),
                ),
              ],
              if (insight.recommendedActionAt != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: CalendarPalette.forestSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(_actionIcon(), color: CalendarPalette.forestDark),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _timingLabel(),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: CalendarPalette.forestDark),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat(
                                'EEEE, d MMMM y · h:mm a',
                              ).format(insight.recommendedActionAt!.toLocal()),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (insight.recommendedActionUsesAvailability) ...[
                              const SizedBox(height: 3),
                              Text(
                                'This time avoids recorded schedule conflicts.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: CalendarPalette.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  aiNarrative == null
                      ? 'This recommendation uses Sakan’s deterministic '
                            'family rules because AI is unavailable or disabled.'
                      : 'AI-generated explanation grounded in Sakan’s '
                            'permitted family data. The action and timing are '
                            'still calculated and validated by Sakan.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CalendarPalette.inkSoft,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Not Now'),
                    ),
                  ),
                  if (actionLabel != null && onPrimaryAction != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: onPrimaryAction,
                        child: Text(actionLabel),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timingLabel() {
    return switch (insight.actionType) {
      FamilyInsightActionType.addReminder => 'Recommended reminder',
      FamilyInsightActionType.scheduleMoment => 'Planned occurrence',
      FamilyInsightActionType.startMomentNow => 'Recommended start',
      FamilyInsightActionType.joinActiveMoment => 'Session started',
      FamilyInsightActionType.reviewToday => 'Review reference time',
      FamilyInsightActionType.openReminders => 'Reminder due time',
      FamilyInsightActionType.manageMoments => 'Suggested timing',
      FamilyInsightActionType.none => 'Suggested timing',
    };
  }

  IconData _actionIcon() {
    return switch (insight.actionType) {
      FamilyInsightActionType.joinActiveMoment => Icons.login_rounded,
      FamilyInsightActionType.reviewToday => Icons.fact_check_outlined,
      FamilyInsightActionType.openReminders => Icons.checklist_rounded,
      FamilyInsightActionType.addReminder => Icons.add_alert_outlined,
      FamilyInsightActionType.startMomentNow => Icons.play_arrow_rounded,
      FamilyInsightActionType.scheduleMoment => Icons.event_available_outlined,
      FamilyInsightActionType.manageMoments =>
        Icons.auto_awesome_motion_outlined,
      FamilyInsightActionType.none => Icons.auto_awesome_outlined,
    };
  }
}

class _DialogItem extends StatelessWidget {
  const _DialogItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: CalendarPalette.forest),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _NumberedAction extends StatelessWidget {
  const _NumberedAction({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: CalendarPalette.forestSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: CalendarPalette.forestDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
