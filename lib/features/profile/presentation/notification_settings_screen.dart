import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/shared/models/current_family_context.dart';
import 'package:sakan/shared/models/notification_preferences.dart';
import 'package:sakan/shared/widgets/feedback/app_error_state.dart';
import 'package:sakan/shared/widgets/feedback/app_loading_state.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  CurrentFamilyContext? _familyContext;

  NotificationPreferences _preferences = const NotificationPreferences();

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
          .getNotificationPreferences(
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
        _errorMessage = 'We could not load your notification settings.';
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final currentMinutes = isStart
        ? _preferences.quietStartMinutes
        : _preferences.quietEndMinutes;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
    );

    if (picked == null) return;

    final minutes = picked.hour * 60 + picked.minute;

    setState(() {
      _preferences = isStart
          ? _preferences.copyWith(quietStartMinutes: minutes)
          : _preferences.copyWith(quietEndMinutes: minutes);
    });
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
      await AppDependencies.profileRepository.updateNotificationPreferences(
        familyId: familyContext.familyId,
        memberId: familyContext.userId,
        preferences: _preferences,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification settings saved.')),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'We could not save your notification settings.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatMinutes(int minutes) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading notification settings…'),
        ),
      );
    }

    if (_errorMessage != null && _familyContext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Settings')),
        body: SafeArea(
          child: AppErrorState(message: _errorMessage!, onRetry: _loadSettings),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            SwitchListTile(
              title: const Text('Rhythm Alerts'),
              subtitle: const Text(
                'Receive reminders when family rhythms begin to drift.',
              ),
              value: _preferences.rhythmAlerts,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          rhythmAlerts: value,
                        );
                      });
                    },
            ),

            SwitchListTile(
              title: const Text('Care Action Reminders'),
              subtitle: const Text(
                'Receive reminders for upcoming care actions.',
              ),
              value: _preferences.careActionReminders,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          careActionReminders: value,
                        );
                      });
                    },
            ),

            SwitchListTile(
              title: const Text('Family Invitations'),
              subtitle: const Text('Receive invitations to family sessions.'),
              value: _preferences.familyInvitations,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          familyInvitations: value,
                        );
                      });
                    },
            ),

            SwitchListTile(
              title: const Text('Weekly Reports'),
              subtitle: const Text('Receive your weekly Digital Twin summary.'),
              value: _preferences.weeklyReports,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          weeklyReports: value,
                        );
                      });
                    },
            ),

            SwitchListTile(
              title: const Text('Important Moments'),
              subtitle: const Text(
                'Receive reminders for important family moments.',
              ),
              value: _preferences.importantMoments,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          importantMoments: value,
                        );
                      });
                    },
            ),

            const Divider(height: 40),

            SwitchListTile(
              title: const Text('Quiet Hours'),
              subtitle: const Text(
                'Pause non-urgent notifications during selected hours.',
              ),
              value: _preferences.quietHoursEnabled,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          quietHoursEnabled: value,
                        );
                      });
                    },
            ),

            if (_preferences.quietHoursEnabled) ...[
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('Quiet Starts'),
                subtitle: Text(_formatMinutes(_preferences.quietStartMinutes)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isSaving
                    ? null
                    : () {
                        _pickTime(isStart: true);
                      },
              ),

              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('Quiet Ends'),
                subtitle: Text(_formatMinutes(_preferences.quietEndMinutes)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isSaving
                    ? null
                    : () {
                        _pickTime(isStart: false);
                      },
              ),
            ],

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
