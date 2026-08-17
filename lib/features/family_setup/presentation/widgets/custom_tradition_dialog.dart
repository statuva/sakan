import 'package:flutter/material.dart';

import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/rhythm_setup_draft.dart';

class CustomTraditionDialog extends StatefulWidget {
  const CustomTraditionDialog({super.key});

  @override
  State<CustomTraditionDialog> createState() => _CustomTraditionDialogState();
}

class _CustomTraditionDialogState extends State<CustomTraditionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customDaysController = TextEditingController();

  MomentCategory _category = MomentCategory.tradition;
  int _frequencySelection = 7;
  int _importanceLevel = 4;

  bool get _usesCustomFrequency => _frequencySelection == -1;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final intervalDays = _usesCustomFrequency
        ? int.parse(_customDaysController.text.trim())
        : _frequencySelection;

    Navigator.of(context).pop(
      RhythmSetupDraft(
        templateId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        title: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        expectedIntervalDays: intervalDays,
        importanceLevel: _importanceLevel,
        expectedParticipantIds: const [],
        nextOccurrenceAt: DateTime.now().add(Duration(days: intervalDays)),
        isCustom: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Custom Tradition'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Tradition name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a tradition name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<MomentCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(
                      value: MomentCategory.tradition,
                      child: Text('Tradition'),
                    ),
                    DropdownMenuItem(
                      value: MomentCategory.familyTime,
                      child: Text('Family Time'),
                    ),
                    DropdownMenuItem(
                      value: MomentCategory.care,
                      child: Text('Care'),
                    ),
                    DropdownMenuItem(
                      value: MomentCategory.memory,
                      child: Text('Memory'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  initialValue: _frequencySelection,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Daily')),
                    DropdownMenuItem(value: 7, child: Text('Weekly')),
                    DropdownMenuItem(value: 14, child: Text('Every 2 weeks')),
                    DropdownMenuItem(value: 30, child: Text('Monthly')),
                    DropdownMenuItem(value: 90, child: Text('Every 3 months')),
                    DropdownMenuItem(value: 365, child: Text('Yearly')),
                    DropdownMenuItem(value: -1, child: Text('Custom interval')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _frequencySelection = value);
                    }
                  },
                ),
                if (_usesCustomFrequency) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _customDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Interval in days',
                    ),
                    validator: (value) {
                      if (!_usesCustomFrequency) return null;
                      final days = int.tryParse(value?.trim() ?? '');
                      if (days == null || days <= 0) {
                        return 'Enter a valid number of days.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  initialValue: _importanceLevel,
                  decoration: const InputDecoration(labelText: 'Importance'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Minimal')),
                    DropdownMenuItem(value: 2, child: Text('Low')),
                    DropdownMenuItem(value: 3, child: Text('Moderate')),
                    DropdownMenuItem(value: 4, child: Text('Important')),
                    DropdownMenuItem(value: 5, child: Text('Essential')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _importanceLevel = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Add Tradition')),
      ],
    );
  }
}
