import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';


class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState
    extends State<PrivacySettingsScreen> {
  bool _aiAnalysis = true;
  bool _analytics = false;

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Privacy settings saved.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & AI'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'What Sakan Stores',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Family members\n'
                    '• Family moments\n'
                    '• Calendar events\n'
                    '• Schedules\n'
                    '• Preferences\n'
                    '• Rhythm history',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            AppCard(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'What the AI Uses',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The AI analyzes family rhythms, completed moments, schedules, and calendar events to suggest meaningful family activities.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            AppCard(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'What Sakan Does NOT Infer',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sakan does not measure emotions, relationship quality, mental health, or psychological well-being. Recommendations are based only on the information your family chooses to share.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            SwitchListTile(
              title: const Text(
                'Allow AI Analysis',
              ),
              subtitle: const Text(
                'Allow Sakan to analyze your family rhythms to generate recommendations.',
              ),
              value: _aiAnalysis,
              onChanged: (value) {
                setState(() {
                  _aiAnalysis = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text(
                'Share Anonymous Analytics',
              ),
              subtitle: const Text(
                'Help improve Sakan using anonymous usage statistics.',
              ),
              value: _analytics,
              onChanged: (value) {
                setState(() {
                  _analytics = value;
                });
              },
            ),

            const SizedBox(height: AppSpacing.xl),

            AppCard(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Data',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You may leave a family, remove your account, or request deletion of your stored data at any time.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            AppPrimaryButton(
              label: 'Save Settings',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
