import 'package:flutter/material.dart';

import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/rhythm_setup_draft.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

class RhythmConfigurationStep extends StatelessWidget {
  const RhythmConfigurationStep({
    required this.drafts,
    required this.onDraftChanged,
    required this.onContinue,
    required this.onBack,
    super.key,
  });

  final List<RhythmSetupDraft> drafts;

  final void Function(int index, RhythmSetupDraft draft) onDraftChanged;

  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Configure your family rhythms',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tell Sakan how often these moments usually happen and how important they are.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),

          ...List.generate(drafts.length, (index) {
            final draft = drafts[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    DropdownButtonFormField<int>(
                      initialValue: draft.expectedIntervalDays,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Daily')),
                        DropdownMenuItem(value: 7, child: Text('Weekly')),
                        DropdownMenuItem(
                          value: 14,
                          child: Text('Every 2 weeks'),
                        ),
                        DropdownMenuItem(value: 30, child: Text('Monthly')),
                        DropdownMenuItem(
                          value: 90,
                          child: Text('Every 3 months'),
                        ),
                        DropdownMenuItem(value: 365, child: Text('Yearly')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        onDraftChanged(
                          index,
                          draft.copyWith(expectedIntervalDays: value),
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.md),

                    DropdownButtonFormField<int>(
                      initialValue: draft.importanceLevel,
                      decoration: const InputDecoration(
                        labelText: 'Importance',
                      ),
                      items: const [
                        DropdownMenuItem(value: 2, child: Text('Low')),
                        DropdownMenuItem(value: 3, child: Text('Moderate')),
                        DropdownMenuItem(value: 4, child: Text('Important')),
                        DropdownMenuItem(value: 5, child: Text('Essential')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        onDraftChanged(
                          index,
                          draft.copyWith(importanceLevel: value),
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.md),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Next expected date'),
                      subtitle: Text(_formatDate(draft.nextOccurrenceAt)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: draft.nextOccurrenceAt,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(DateTime.now().year + 5),
                        );

                        if (date == null) return;

                        onDraftChanged(
                          index,
                          draft.copyWith(nextOccurrenceAt: date),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.xl),

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
                  label: 'Continue',
                  onPressed: drafts.isEmpty ? null : onContinue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
