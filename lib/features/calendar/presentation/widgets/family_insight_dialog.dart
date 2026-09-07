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
    this.onOpenSimulation,
    super.key,
  });

  final FamilyInsightItem insight;
  final SakanAiResult? aiNarrative;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onOpenSimulation;

  @override
  Widget build(BuildContext context) {
    final actionLabel = insight.primaryActionLabel;
    final headline = aiNarrative?.title ?? insight.headline;
    final summary = aiNarrative?.text ?? insight.summary;
    final reasons = aiNarrative?.reasons.isNotEmpty == true
        ? aiNarrative!.reasons
        : insight.reasons;
    final suggestedActions = _mergedTasks();

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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                  'Why this',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...reasons.take(1).map(
                  (reason) => _DialogItem(
                    icon: Icons.check_circle_outline,
                    text: reason,
                  ),
                ),
              ],
              if (suggestedActions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Your plan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...List<Widget>.generate(
                  suggestedActions.length,
                  (index) => _PlanTask(
                    text: suggestedActions[index],
                    isPrimary: index == 0,
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
                      ? 'Based on Sakan’s recorded family data.'
                      : 'AI wording; Sakan validates the action and timing.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CalendarPalette.inkSoft,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (insight.recommendsSimulation &&
                  insight.actionType !=
                      FamilyInsightActionType.openSimulation &&
                  onOpenSimulation != null) ...[
                OutlinedButton.icon(
                  onPressed: onOpenSimulation,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Try Simulation'),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
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
      FamilyInsightActionType.openSimulation => 'Time to compare',
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
      FamilyInsightActionType.openSimulation =>
        Icons.auto_awesome_outlined,
      FamilyInsightActionType.none => Icons.auto_awesome_outlined,
    };
  }

  List<String> _mergedTasks() {
    final baseline = insight.suggestedActions;
    final seen = <String>{};
    return baseline
        .where((task) => seen.add(task.trim().toLowerCase()))
        .take(3)
        .toList(growable: false);
  }
}

class _PlanTask extends StatelessWidget {
  const _PlanTask({required this.text, required this.isPrimary});

  final String text;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isPrimary
            ? CalendarPalette.forestSoft
            : CalendarPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: isPrimary
            ? Border.all(color: CalendarPalette.forest.withAlpha(45))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPrimary ? Icons.arrow_forward_rounded : Icons.circle_outlined,
            size: isPrimary ? 19 : 15,
            color: CalendarPalette.forestDark,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPrimary ? 'DO FIRST' : 'ALSO',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: CalendarPalette.forestDark,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CalendarPalette.ink,
                    fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
