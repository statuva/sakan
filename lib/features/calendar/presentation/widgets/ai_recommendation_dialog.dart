import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../calendar_types.dart';
import 'calendar_palette.dart';

class AiRecommendationDialog extends StatelessWidget {
  const AiRecommendationDialog({
    required this.recommendation,
    required this.canSchedule,
    required this.onScheduleReminder,
    super.key,
  });

  final CalendarRecommendation recommendation;
  final bool canSchedule;
  final Future<void> Function() onScheduleReminder;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470, maxHeight: 690),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: CalendarPalette.forestSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_outlined,
                      color: CalendarPalette.forestDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sakan Recommendation',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: CalendarPalette.ink,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          recommendation.moment.title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: CalendarPalette.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _DialogSection(
                title: 'Why Sakan is suggesting this',
                icon: Icons.info_outline_rounded,
                children: recommendation.reasons
                    .map((reason) => _BulletText(text: reason))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              _DialogSection(
                title: 'Suggested preparation',
                icon: Icons.checklist_rounded,
                children: List<Widget>.generate(
                  recommendation.preparationSteps.length,
                  (index) => _NumberedStep(
                    number: index + 1,
                    text: recommendation.preparationSteps[index],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: CalendarPalette.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: CalendarPalette.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat(
                              'EEEE, d MMMM · h:mm a',
                            ).format(recommendation.recommendedReminderAt),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: CalendarPalette.inkSoft),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            recommendation.reminderTimeUsesAvailability
                                ? 'This time was selected from your recurring availability.'
                                : 'This is a suggested reminder time because no complete availability match was found.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: CalendarPalette.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Not Now'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: canSchedule
                          ? () async {
                              await onScheduleReminder();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            }
                          : null,
                      icon: const Icon(Icons.add_alert_outlined),
                      label: Text(
                        canSchedule ? 'Schedule Reminder' : 'Admin Required',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogSection extends StatelessWidget {
  const _DialogSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: CalendarPalette.forestDark),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: CalendarPalette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...children,
      ],
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: CircleAvatar(
              radius: 2.5,
              backgroundColor: CalendarPalette.forest,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: CalendarPalette.forestSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: CalendarPalette.forestDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
