import 'package:flutter/material.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/rhythm_setup_draft.dart';

class CustomTraditionDialog extends StatefulWidget {
  const CustomTraditionDialog({super.key});

  @override
  State<CustomTraditionDialog> createState() => _CustomTraditionDialogState();
}

class _CustomTraditionDialogState extends State<CustomTraditionDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _intervalDays = 7;
  int _importanceLevel = 4;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _nameController.text.trim();

    if (title.isEmpty) {
      return;
    }

    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';

    Navigator.of(context).pop(
      RhythmSetupDraft(
        templateId: id,
        title: title,
        description: _descriptionController.text.trim(),
        category: MomentCategory.tradition,
        expectedIntervalDays: _intervalDays,
        importanceLevel: _importanceLevel,
        expectedParticipantIds: const [],
        nextOccurrenceAt: DateTime.now().add(Duration(days: _intervalDays)),
        isCustom: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Custom Tradition'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tradition name'),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<int>(
              initialValue: _intervalDays,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Daily')),
                DropdownMenuItem(value: 7, child: Text('Weekly')),
                DropdownMenuItem(value: 14, child: Text('Every 2 weeks')),
                DropdownMenuItem(value: 30, child: Text('Monthly')),
                DropdownMenuItem(value: 90, child: Text('Every 3 months')),
                DropdownMenuItem(value: 365, child: Text('Yearly')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _intervalDays = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<int>(
              initialValue: _importanceLevel,
              decoration: const InputDecoration(labelText: 'Importance'),
              items: const [
                DropdownMenuItem(value: 2, child: Text('Low')),
                DropdownMenuItem(value: 4, child: Text('Important')),
                DropdownMenuItem(value: 5, child: Text('Essential')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _importanceLevel = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Add Tradition')),
      ],
    );
  }
}
