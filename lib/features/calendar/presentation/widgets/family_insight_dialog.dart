import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_insight_report.dart';
import 'calendar_palette.dart';

class FamilyInsightDialog extends StatelessWidget {
  const FamilyInsightDialog({
    required this.insight,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    super.key,
  });

  final FamilyInsightItem insight;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
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
                    child: const Icon(
                      Icons.auto_awesome_outlined,
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
                          insight.headline,
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
                insight.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CalendarPalette.inkSoft,
                  height: 1.5,
                ),
              ),
              if (insight.reasons.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Why Sakan surfaced this',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...insight.reasons.map(
                  (reason) => _DialogItem(
                    icon: Icons.check_circle_outline,
                    text: reason,
                  ),
                ),
              ],
              if (insight.suggestedActions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Suggested next steps',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...List.generate(
                  insight.suggestedActions.length,
                  (index) => _NumberedAction(
                    number: index + 1,
                    text: insight.suggestedActions[index],
                  ),
                ),
              ],
              if (insight.recommendedReminderAt != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: CalendarPalette.forestSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: CalendarPalette.forestDark,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recommended reminder',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: CalendarPalette.forestDark),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat('EEEE, d MMMM y · h:mm a').format(
                                insight.recommendedReminderAt!.toLocal(),
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (insight
                                .recommendedReminderUsesAvailability) ...[
                              const SizedBox(height: 3),
                              Text(
                                'This time avoids your recorded busy periods.',
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
                  'This recommendation is currently rule-based and '
                  'comes from Sakan’s stored family data. External AI '
                  'wording has not been connected yet.',
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
                  if (primaryActionLabel != null &&
                      onPrimaryAction != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: onPrimaryAction,
                        child: Text(primaryActionLabel!),
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
