import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _rhythmAlerts = true;
  bool _careReminders = true;
  bool _familyInvitations = true;
  bool _weeklyReports = true;
  bool _importantMoments = true;

  bool _quietHours = false;

  int _quietStartMinutes = 22 * 60;
  int _quietEndMinutes = 7 * 60;

  Future<void> _pickTime({
    required bool isStart,
  }) async {
    final currentMinutes = isStart
        ? _quietStartMinutes
        : _quietEndMinutes;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
    );

    if (picked == null) return;

    setState(() {
      final minutes =
          picked.hour * 60 + picked.minute;

      if (isStart) {
        _quietStartMinutes = minutes;
      } else {
        _quietEndMinutes = minutes;
      }
    });
  }

  String _formatMinutes(int minutes) {
    final hour24 = minutes ~/ 60;
    final minute = minutes % 60;

    final time = TimeOfDay(
      hour: hour24,
      minute: minute,
    );

    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time);
  }

  void _save() {
    // Firebase save comes next.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Notification settings saved.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Notification Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.all(AppSpacing.xl),
          children: [
            SwitchListTile(
              title:
                  const Text('Rhythm Alerts'),
              subtitle: const Text(
                'Receive reminders when family rhythms begin to drift.',
              ),
              value: _rhythmAlerts,
              onChanged: (value) {
                setState(() {
                  _rhythmAlerts = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text(
                'Care Action Reminders',
              ),
              subtitle: const Text(
                'Receive reminders for upcoming care actions.',
              ),
              value: _careReminders,
              onChanged: (value) {
                setState(() {
                  _careReminders = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text(
                'Family Invitations',
              ),
              subtitle: const Text(
                'Receive invitations to family sessions.',
              ),
              value: _familyInvitations,
              onChanged: (value) {
                setState(() {
                  _familyInvitations = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text(
                'Weekly Reports',
              ),
              subtitle: const Text(
                'Receive your weekly Digital Twin summary.',
              ),
              value: _weeklyReports,
              onChanged: (value) {
                setState(() {
                  _weeklyReports = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text(
                'Important Moments',
              ),
              subtitle: const Text(
                'Receive reminders for important family moments.',
              ),
              value: _importantMoments,
              onChanged: (value) {
                setState(() {
                  _importantMoments = value;
                });
              },
            ),

            const Divider(
              height: 40,
            ),

            SwitchListTile(
              title:
                  const Text('Quiet Hours'),
              subtitle: const Text(
                'Pause non-urgent notifications during selected hours.',
              ),
              value: _quietHours,
              onChanged: (value) {
                setState(() {
                  _quietHours = value;
                });
              },
            ),

            if (_quietHours) ...[
              ListTile(
                leading: const Icon(
                  Icons.bedtime_outlined,
                ),
                title:
                    const Text('Quiet Starts'),
                subtitle: Text(
                  _formatMinutes(
                    _quietStartMinutes,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {
                  _pickTime(
                    isStart: true,
                  );
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.wb_sunny_outlined,
                ),
                title:
                    const Text('Quiet Ends'),
                subtitle: Text(
                  _formatMinutes(
                    _quietEndMinutes,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {
                  _pickTime(
                    isStart: false,
                  );
                },
              ),
            ],

            const SizedBox(
              height: AppSpacing.xxl,
            ),

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