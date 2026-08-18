import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

class HubSettingsScreen extends StatefulWidget {
  const HubSettingsScreen({super.key});

  @override
  State<HubSettingsScreen> createState() => _HubSettingsScreenState();
}

class _HubSettingsScreenState extends State<HubSettingsScreen> {
  final _hubNameController = TextEditingController(text: 'Sakan Hub');

  final _locationController = TextEditingController(text: 'Dining Room');

  bool _registered = false;
  bool _manualCheckIn = true;
  bool _saving = false;

  @override
  void dispose() {
    _hubNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Hub settings saved.')));
  }

  void _registerHub() {
    setState(() {
      _registered = true;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Hub registered (demo).')));
  }

  void _removeHub() {
    setState(() {
      _registered = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Hub removed.')));
  }

  void _testHub() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('NFC integration will be connected later.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hub Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hub Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    TextField(
                      controller: _hubNameController,
                      decoration: const InputDecoration(labelText: 'Hub Name'),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              AppCard(
                child: ListTile(
                  leading: Icon(
                    _registered ? Icons.check_circle : Icons.cancel,
                    color: _registered ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    _registered ? 'Hub Registered' : 'No Hub Registered',
                  ),
                  subtitle: Text(
                    _registered
                        ? 'Your family can use NFC check-ins.'
                        : 'Register a Sakan Hub to enable NFC.',
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              SwitchListTile(
                title: const Text('Manual Check-in'),
                subtitle: const Text(
                  'Allow manual family check-ins if the Hub is unavailable.',
                ),
                value: _manualCheckIn,
                onChanged: (value) {
                  setState(() {
                    _manualCheckIn = value;
                  });
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              if (!_registered)
                AppPrimaryButton(
                  label: 'Register Hub',
                  onPressed: _registerHub,
                ),

              if (_registered) ...[
                AppPrimaryButton(label: 'Test Hub', onPressed: _testHub),

                const SizedBox(height: AppSpacing.md),

                OutlinedButton.icon(
                  onPressed: _removeHub,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove Hub'),
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),

              AppPrimaryButton(
                label: 'Save Settings',
                isLoading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
