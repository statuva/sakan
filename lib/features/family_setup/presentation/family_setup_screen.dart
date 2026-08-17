import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sakan/shared/models/rhythm_setup_draft.dart';
import 'package:sakan/shared/services/uae_rhythm_templates.dart';
import 'widgets/members_setup_step.dart';
import 'widgets/rhythm_configuration_step.dart';
import 'widgets/rhythm_library_step.dart';
import 'widgets/setup_review_step.dart';

class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  int currentStep = 0;

  final Set<String> selectedTemplateIds = {};

  List<RhythmSetupDraft> rhythmDrafts = [];

  void nextStep() {
    if (currentStep < 3) {
      setState(() {
        currentStep++;
      });
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
    }
  }

  void updateSelectedTemplates(Set<String> templateIds) {
    setState(() {
      selectedTemplateIds
        ..clear()
        ..addAll(templateIds);

      _rebuildRhythmDrafts();
    });
  }

  void _rebuildRhythmDrafts() {
    final existingDrafts = {
      for (final draft in rhythmDrafts) draft.templateId: draft,
    };

    final now = DateTime.now();

    rhythmDrafts = selectedTemplateIds.map((templateId) {
      if (existingDrafts.containsKey(templateId)) {
        return existingDrafts[templateId]!;
      }

      final template = UaeRhythmTemplates.all.firstWhere(
        (item) => item.id == templateId,
      );

      return RhythmSetupDraft(
        templateId: template.id,
        title: template.title,
        description: template.description,
        category: template.category,
        expectedIntervalDays: template.defaultIntervalDays,
        importanceLevel: template.defaultImportanceLevel,
        expectedParticipantIds: const [],
        nextOccurrenceAt: now.add(Duration(days: template.defaultIntervalDays)),
      );
    }).toList();
  }

  void updateRhythmDraft(int index, RhythmSetupDraft draft) {
    setState(() {
      rhythmDrafts[index] = draft;
    });
  }

  void addCustomRhythm(RhythmSetupDraft draft) {
    setState(() {
      rhythmDrafts.add(draft);
      selectedTemplateIds.add(draft.templateId);
    });
  }

  Future<void> completeSetup() async {
    // Firebase save will be connected next.
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Setup data is ready to be saved.')),
    );
  }

  Widget _buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return MembersSetupStep(onContinue: nextStep);

      case 1:
        return RhythmLibraryStep(
          selectedTemplateIds: selectedTemplateIds,
          onSelectionChanged: updateSelectedTemplates,
          onCustomRhythmCreated: addCustomRhythm,
          onContinue: nextStep,
          onBack: previousStep,
        );

      case 2:
        return RhythmConfigurationStep(
          drafts: rhythmDrafts,
          onDraftChanged: updateRhythmDraft,
          onContinue: nextStep,
          onBack: previousStep,
        );

      case 3:
        return SetupReviewStep(
          rhythmDrafts: rhythmDrafts,
          onBack: previousStep,
          onComplete: completeSetup,
        );

      default:
        return MembersSetupStep(onContinue: nextStep);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Setup')),
      body: SafeArea(
        child: Column(
          children: [
            _SetupProgress(currentStep: currentStep),
            Expanded(child: _buildCurrentStep()),
          ],
        ),
      ),
    );
  }
}

class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Members', 'Traditions', 'Configure', 'Review'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${currentStep + 1} of 4',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (currentStep + 1) / 4),
          const SizedBox(height: 8),
          Text(
            labels[currentStep],
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}
