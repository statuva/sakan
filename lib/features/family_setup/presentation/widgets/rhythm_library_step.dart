import 'package:flutter/material.dart';

import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/rhythm_setup_draft.dart';
import 'package:sakan/shared/services/uae_rhythm_templates.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

import 'custom_tradition_dialog.dart';

class RhythmLibraryStep extends StatelessWidget {
  const RhythmLibraryStep({
    required this.selectedTemplateIds,
    required this.customRhythms,
    required this.onSelectionChanged,
    required this.onCustomRhythmCreated,
    required this.onCustomRhythmRemoved,
    required this.onContinue,
    required this.onBack,
    super.key,
  });

  final Set<String> selectedTemplateIds;
  final List<RhythmSetupDraft> customRhythms;
  final ValueChanged<Set<String>> onSelectionChanged;
  final ValueChanged<RhythmSetupDraft> onCustomRhythmCreated;
  final ValueChanged<String> onCustomRhythmRemoved;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  void _toggleTemplate(String templateId) {
    final updatedIds = Set<String>.from(selectedTemplateIds);
    if (updatedIds.contains(templateId)) {
      updatedIds.remove(templateId);
    } else {
      updatedIds.add(templateId);
    }
    onSelectionChanged(updatedIds);
  }

  Future<void> _openCustomTraditionDialog(BuildContext context) async {
    final draft = await showDialog<RhythmSetupDraft>(
      context: context,
      builder: (_) => const CustomTraditionDialog(),
    );

    if (draft != null) onCustomRhythmCreated(draft);
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
            'Choose recurring moments that are meaningful to your family. These templates are optional and can be customized later.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          ...UaeRhythmTemplates.all.map((template) {
            final isSelected = selectedTemplateIds.contains(template.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _RhythmTemplateCard(
                title: template.title,
                description: template.description,
                intervalDays: template.defaultIntervalDays,
                importanceLevel: template.defaultImportanceLevel,
                isSelected: isSelected,
                onTap: () => _toggleTemplate(template.id),
              ),
            );
          }),
          if (customRhythms.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Custom traditions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...customRhythms.map(
              (draft) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              draft.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (draft.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                draft.description,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove custom tradition',
                        onPressed: () {
                          onCustomRhythmRemoved(draft.templateId);
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _openCustomTraditionDialog(context),
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

class _RhythmTemplateCard extends StatelessWidget {
  const _RhythmTemplateCard({
    required this.title,
    required this.description,
    required this.intervalDays,
    required this.importanceLevel,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String description;
  final int intervalDays;
  final int importanceLevel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      color: isSelected ? colorScheme.primary.withAlpha(18) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
            ),
            child: Icon(
              isSelected ? Icons.check_rounded : Icons.favorite_border_rounded,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _SmallLabel(
                      icon: Icons.repeat_rounded,
                      label: _frequencyLabel(intervalDays),
                    ),
                    _SmallLabel(
                      icon: Icons.star_outline_rounded,
                      label: _importanceLabel(importanceLevel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _frequencyLabel(int days) {
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

  static String _importanceLabel(int level) {
    if (level >= 5) return 'Essential';
    if (level >= 4) return 'Important';
    if (level >= 3) return 'Moderate';
    if (level >= 2) return 'Low';
    return 'Minimal';
  }
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
