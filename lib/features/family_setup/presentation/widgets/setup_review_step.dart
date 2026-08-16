import 'package:flutter/material.dart';

import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/rhythm_setup_draft.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

class SetupReviewStep extends StatelessWidget {
  const SetupReviewStep({
    required this.rhythmDrafts,
    required this.onBack,
    required this.onComplete,
    super.key,
  });

  final List<RhythmSetupDraft> rhythmDrafts;
  final VoidCallback onBack;
  final VoidCallback onComplete;

  String _frequencyLabel(int days) {
    return switch (days) {
      1 => 'Daily',
      7 => 'Weekly',
      14 => 'Every 2 weeks',
      30 => 'Monthly',
      90 => 'Every 3 months',
      365 => 'Yearly',
      _ => 'Every $days days',
    };
  }

  String _importanceLabel(int level) {
    if (level >= 5) return 'Essential';
    if (level >= 4) return 'Important';
    if (level >= 3) return 'Moderate';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Review your family setup',
            style: Theme.of(context).textTheme.headlineLarge,
          ),

          const SizedBox(height: AppSpacing.xs),

          Text(
            'Check everything before Sakan creates your initial family rhythm baseline.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: AppSpacing.xl),

          Text('Family', style: Theme.of(context).textTheme.titleLarge),

          const SizedBox(height: AppSpacing.sm),

          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Al Mansoori Family',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text('2 joined members'),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          Text('Members', style: Theme.of(context).textTheme.titleLarge),

          const SizedBox(height: AppSpacing.sm),

          const AppCard(
            child: Column(
              children: [
                _ReviewMemberRow(
                  name: 'Mom',
                  role: 'Admin',
                  relationship: 'Parent',
                ),
                Divider(),
                _ReviewMemberRow(
                  name: 'Sara',
                  role: 'Child',
                  relationship: 'Child',
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          Text(
            'Selected rhythms',
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: AppSpacing.sm),

          AppCard(
            child: Column(
              children: List.generate(rhythmDrafts.length, (index) {
                final rhythm = rhythmDrafts[index];

                return Column(
                  children: [
                    _ReviewRhythmRow(
                      title: rhythm.title,
                      details:
                          '${_frequencyLabel(rhythm.expectedIntervalDays)} · '
                          '${_importanceLabel(rhythm.importanceLevel)}',
                    ),
                    if (index != rhythmDrafts.length - 1) const Divider(),
                  ],
                );
              }),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),

                const SizedBox(width: AppSpacing.md),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How your baseline starts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'All selected rhythms will begin as “Still Learning”. Their confidence will improve as your family completes real moments together.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  child: const Text('Back'),
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              Expanded(
                child: AppPrimaryButton(
                  label: 'Complete Setup',
                  onPressed: onComplete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewMemberRow extends StatelessWidget {
  const _ReviewMemberRow({
    required this.name,
    required this.role,
    required this.relationship,
  });

  final String name;
  final String role;
  final String relationship;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
          ),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '$role · $relationship',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRhythmRow extends StatelessWidget {
  const _ReviewRhythmRow({required this.title, required this.details});

  final String title;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.favorite_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(details, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
