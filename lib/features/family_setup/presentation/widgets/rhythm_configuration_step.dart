import 'package:flutter/material.dart';

import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/rhythm_setup_draft.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

class RhythmConfigurationStep extends StatelessWidget {
  const RhythmConfigurationStep({
    required this.drafts,
    required this.members,
    required this.onDraftChanged,
    required this.onContinue,
    required this.onBack,
    super.key,
  });

  final List<RhythmSetupDraft> drafts;
  final List<Member> members;
  final void Function(int index, RhythmSetupDraft draft) onDraftChanged;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  void _validateAndContinue(BuildContext context) {
    if (drafts.isEmpty) {
      _showMessage(context, 'Choose at least one family tradition.');
      return;
    }

    for (final draft in drafts) {
      if (draft.expectedIntervalDays <= 0) {
        _showMessage(context, '${draft.title} needs a valid frequency.');
        return;
      }
      if (draft.importanceLevel < 1 || draft.importanceLevel > 5) {
        _showMessage(context, '${draft.title} needs a valid importance level.');
        return;
      }
      if (draft.expectedParticipantIds.isEmpty) {
        _showMessage(
          context,
          'Choose at least one participant for ${draft.title}.',
        );
        return;
      }
    }

    onContinue();
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final activeMembers = members
        .where((member) => member.isActive)
        .toList(growable: false);

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
            'Tell Sakan how often these moments usually happen, how important they are, and who normally participates.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (drafts.isEmpty)
            const AppCard(child: Text('No family rhythms were selected.'))
          else
            ...List.generate(drafts.length, (index) {
              final draft = drafts[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _RhythmConfigurationCard(
                  draft: draft,
                  members: activeMembers,
                  onChanged: (updatedDraft) {
                    onDraftChanged(index, updatedDraft);
                  },
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
                  onPressed: drafts.isEmpty
                      ? null
                      : () => _validateAndContinue(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RhythmConfigurationCard extends StatelessWidget {
  const _RhythmConfigurationCard({
    required this.draft,
    required this.members,
    required this.onChanged,
  });

  final RhythmSetupDraft draft;
  final List<Member> members;
  final ValueChanged<RhythmSetupDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(draft.title, style: Theme.of(context).textTheme.titleLarge),
          if (draft.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              draft.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<int>(
            key: ValueKey(
              'frequency-${draft.templateId}-${draft.expectedIntervalDays}',
            ),
            initialValue: draft.expectedIntervalDays,
            decoration: const InputDecoration(labelText: 'Frequency'),
            items: _frequencyValues(draft.expectedIntervalDays)
                .map(
                  (days) => DropdownMenuItem(
                    value: days,
                    child: Text(_frequencyLabel(days)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              onChanged(draft.copyWith(expectedIntervalDays: value));
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            key: ValueKey(
              'importance-${draft.templateId}-${draft.importanceLevel}',
            ),
            initialValue: draft.importanceLevel,
            decoration: const InputDecoration(labelText: 'Importance'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Minimal')),
              DropdownMenuItem(value: 2, child: Text('Low')),
              DropdownMenuItem(value: 3, child: Text('Moderate')),
              DropdownMenuItem(value: 4, child: Text('Important')),
              DropdownMenuItem(value: 5, child: Text('Essential')),
            ],
            onChanged: (value) {
              if (value == null) return;
              onChanged(draft.copyWith(importanceLevel: value));
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Expected participants',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${draft.expectedParticipantIds.length} selected',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (members.isEmpty)
            Text(
              'No active family members are available.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...members.map((member) {
              final isSelected = draft.expectedParticipantIds.contains(
                member.id,
              );

              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: isSelected,
                title: Text(member.displayName),
                subtitle: Text(_relationshipLabel(member.relationship)),
                onChanged: (selected) {
                  final participantIds = List<String>.from(
                    draft.expectedParticipantIds,
                  );

                  if (selected == true) {
                    if (!participantIds.contains(member.id)) {
                      participantIds.add(member.id);
                    }
                  } else {
                    participantIds.remove(member.id);
                  }

                  onChanged(
                    draft.copyWith(expectedParticipantIds: participantIds),
                  );
                },
              );
            }),
          const SizedBox(height: AppSpacing.lg),
          _DateTile(
            label: 'Next expected date',
            date: draft.nextOccurrenceAt,
            onTap: () async {
              final selectedDate = await _selectNextDate(
                context,
                draft.nextOccurrenceAt,
              );
              if (selectedDate == null) return;
              onChanged(draft.copyWith(nextOccurrenceAt: selectedDate));
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _DateTile(
            label: 'Last occurrence (optional)',
            date: draft.lastOccurrenceAt,
            placeholder: 'Not provided',
            onTap: () async {
              final selectedDate = await _selectPastDate(
                context,
                draft.lastOccurrenceAt,
              );
              if (selectedDate == null) return;
              onChanged(draft.copyWith(lastOccurrenceAt: selectedDate));
            },
            onClear: draft.lastOccurrenceAt == null
                ? null
                : () {
                    onChanged(draft.copyWith(removeLastOccurrence: true));
                  },
          ),
        ],
      ),
    );
  }

  static List<int> _frequencyValues(int currentValue) {
    final values = <int>{
      1,
      7,
      14,
      30,
      90,
      365,
      currentValue,
    }.where((value) => value > 0).toList();
    values.sort();
    return values;
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

  static String _relationshipLabel(FamilyRelationship relationship) {
    return switch (relationship) {
      FamilyRelationship.parent => 'Parent',
      FamilyRelationship.child => 'Child',
      FamilyRelationship.grandparent => 'Grandparent',
      FamilyRelationship.sibling => 'Sibling',
      FamilyRelationship.guardian => 'Guardian',
      FamilyRelationship.relative => 'Relative',
      FamilyRelationship.other => 'Other',
    };
  }

  static Future<DateTime?> _selectNextDate(
    BuildContext context,
    DateTime currentDate,
  ) {
    final today = DateUtils.dateOnly(DateTime.now());
    final initialDate = currentDate.isBefore(today)
        ? today
        : DateUtils.dateOnly(currentDate);

    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime(today.year + 5, 12, 31),
    );
  }

  static Future<DateTime?> _selectPastDate(
    BuildContext context,
    DateTime? currentDate,
  ) {
    final today = DateUtils.dateOnly(DateTime.now());
    final candidate = currentDate == null
        ? today
        : DateUtils.dateOnly(currentDate);
    final initialDate = candidate.isAfter(today) ? today : candidate;

    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(today.year - 20, 1, 1),
      lastDate: today,
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
    this.placeholder,
    this.onClear,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final String? placeholder;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today_outlined),
      title: Text(label),
      subtitle: Text(
        date == null ? placeholder ?? 'Choose date' : _formatDate(date!),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onClear != null)
            IconButton(
              tooltip: 'Clear date',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }

  static String _formatDate(DateTime date) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
