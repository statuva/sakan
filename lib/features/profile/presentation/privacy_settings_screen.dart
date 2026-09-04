import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';
import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/shared/models/current_family_context.dart';
import 'package:sakan/shared/models/privacy_preferences.dart';
import 'package:sakan/shared/widgets/feedback/app_error_state.dart';
import 'package:sakan/shared/widgets/feedback/app_loading_state.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  CurrentFamilyContext? _familyContext;

  PrivacyPreferences _preferences = const PrivacyPreferences();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      final preferences = await AppDependencies.profileRepository
          .getPrivacyPreferences(
            familyId: familyContext.familyId,
            memberId: familyContext.userId,
          );

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _preferences = preferences;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load your privacy settings.';
      });
    }
  }

  Future<void> _saveSettings() async {
    final familyContext = _familyContext;

    if (familyContext == null || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await AppDependencies.profileRepository.updatePrivacySettings(
        familyId: familyContext.familyId,
        memberId: familyContext.userId,
        aiConsent: _preferences.aiConsent,
        analyticsConsent: _preferences.analyticsConsent,
      );
      AppDependencies.clearAiCaches();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Privacy settings saved.')));
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'We could not save your privacy settings.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading privacy settings…'),
        ),
      );
    }

    if (_errorMessage != null && _familyContext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Privacy & AI')),
        body: SafeArea(
          child: AppErrorState(message: _errorMessage!, onRetry: _loadSettings),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & AI')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What Sakan Stores',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Family members\n'
                    '• Family moments\n'
                    '• Calendar events\n'
                    '• Schedules\n'
                    '• Personal preferences\n'
                    '• Rhythm history',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What the AI Uses',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'When you allow AI, Sakan sends a bounded set of recent '
                    'Moment, rhythm, reminder, and Memory metadata to OpenAI. '
                    'A family note is sent only when you explicitly create a '
                    'reflection for that Memory. Photos, contact details, and '
                    'invitation codes are never sent. AI is currently available '
                    'only to confirmed adults.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What Sakan Does Not Infer',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sakan does not diagnose emotions, '
                    'mental health, relationship quality, '
                    'or psychological well-being.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            SwitchListTile(
              title: const Text('Allow AI Analysis'),
              subtitle: const Text(
                'Allow protected OpenAI processing for chat, explanations, '
                'simulations, Memory reflections, and weekly narratives. '
                'This is off by default and can be turned off again anytime.',
              ),
              value: _preferences.aiConsent,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(aiConsent: value);
                      });
                    },
            ),

            SwitchListTile(
              title: const Text('Share Anonymous Analytics'),
              subtitle: const Text(
                'Help improve Sakan with anonymous '
                'usage information.',
              ),
              value: _preferences.analyticsConsent,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          analyticsConsent: value,
                        );
                      });
                    },
            ),

            const SizedBox(height: AppSpacing.xl),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Data',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Account and data deletion controls '
                    'will be completed before the final release.',
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],

            const SizedBox(height: AppSpacing.xxl),

            AppPrimaryButton(
              label: 'Save Settings',
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _saveSettings,
            ),
          ],
        ),
      ),
    );
  }
}
