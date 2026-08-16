import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/services/uae_rhythm_templates.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';
import 'custom_tradition_dialog.dart';
import 'package:sakan/shared/models/rhythm_setup_draft.dart';

class RhythmLibraryStep extends StatelessWidget {
  const RhythmLibraryStep({
    required this.selectedTemplateIds,
    required this.onSelectionChanged,
    required this.onCustomRhythmCreated,
    required this.onContinue,
    required this.onBack,
    super.key,
  });

  final Set<String> selectedTemplateIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final ValueChanged<RhythmSetupDraft> onCustomRhythmCreated;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  void _toggleTemplate(String templateId) {
    final updated = Set<String>.from(selectedTemplateIds);

    if (updated.contains(templateId)) {
      updated.remove(templateId);
    } else {
      updated.add(templateId);
    }

    onSelectionChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Which rhythms matter to your family?',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Choose the recurring moments that are meaningful to your family.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),

          ...UaeRhythmTemplates.all.map((template) {
            final isSelected = selectedTemplateIds.contains(template.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                onTap: () => _toggleTemplate(template.id),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            template.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.sm),

          OutlinedButton.icon(
            onPressed: () async {
              final draft = await showDialog<RhythmSetupDraft>(
                context: context,
                builder: (_) => const CustomTraditionDialog(),
              );

              if (draft != null) {
                onCustomRhythmCreated(draft);
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Custom Tradition'),
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
                  label: 'Continue',
                  onPressed: selectedTemplateIds.isEmpty ? null : onContinue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
