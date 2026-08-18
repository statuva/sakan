import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/shared/models/current_family_context.dart';
import 'package:sakan/shared/widgets/feedback/app_error_state.dart';
import 'package:sakan/shared/widgets/feedback/app_loading_state.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final Set<int> _preferredDays = <int>{};
  final Set<String> _activities = <String>{};

  final List<String> _availableActivities = const [
    'Friday Lunch',
    'Family Dinner',
    'Movie Night',
    'Board Games',
    'Family Walk',
    'Grandparents Visit',
    'Family Majlis',
    'Desert Outing',
    'Storytelling',
    'Cooking Together',
  ];

  final List<String> _weekDays = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  CurrentFamilyContext? _familyContext;

  TimeOfDay _preferredStart = const TimeOfDay(hour: 18, minute: 0);

  TimeOfDay _preferredEnd = const TimeOfDay(hour: 21, minute: 0);

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      final member = familyContext.member;

      final startMinutes = member.preferredStartMinutes ?? 1080;

      final endMinutes = member.preferredEndMinutes ?? 1260;

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;

        _preferredDays
          ..clear()
          ..addAll(member.preferredDays);

        _activities
          ..clear()
          ..addAll(member.interests);

        _preferredStart = TimeOfDay(
          hour: startMinutes ~/ 60,
          minute: startMinutes % 60,
        );

        _preferredEnd = TimeOfDay(
          hour: endMinutes ~/ 60,
          minute: endMinutes % 60,
        );

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load your preferences.';
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _preferredStart,
    );

    if (picked == null) return;

    setState(() {
      _preferredStart = picked;
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _preferredEnd,
    );

    if (picked == null) return;

    setState(() {
      _preferredEnd = picked;
    });
  }

  Future<void> _savePreferences() async {
    final familyContext = _familyContext;

    if (familyContext == null || _isSaving) {
      return;
    }

    if (_preferredDays.isEmpty) {
      _showMessage('Choose at least one preferred family day.');
      return;
    }

    final startMinutes = _minutesFromTime(_preferredStart);

    final endMinutes = _minutesFromTime(_preferredEnd);

    if (endMinutes <= startMinutes) {
      _showMessage('Preferred end time must be after the start time.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final days = _preferredDays.toList()..sort();

      final activities = _activities.toList()..sort();

      await AppDependencies.profileRepository.updateFamilyTimePreferences(
        familyId: familyContext.familyId,
        memberId: familyContext.userId,
        preferredDays: days,
        preferredStartMinutes: startMinutes,
        preferredEndMinutes: endMinutes,
        activities: activities,
      );

      if (!mounted) return;

      _showMessage('Family time preferences saved.');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'We could not save your preferences.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  int _minutesFromTime(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  String _formatTime(TimeOfDay time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading your preferences…'),
        ),
      );
    }

    if (_errorMessage != null && _familyContext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Time Preferences')),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage!,
            onRetry: _loadPreferences,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Family Time Preferences')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preferred Family Days',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: AppSpacing.md),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final day = index + 1;

                  return FilterChip(
                    label: Text(_weekDays[index]),
                    selected: _preferredDays.contains(day),
                    onSelected: _isSaving
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected) {
                                _preferredDays.add(day);
                              } else {
                                _preferredDays.remove(day);
                              }
                            });
                          },
                  );
                }),
              ),

              const SizedBox(height: AppSpacing.xl),

              Text(
                'Preferred Family Time',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: AppSpacing.md),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.access_time_outlined),
                  title: const Text('Start Time'),
                  subtitle: Text(_formatTime(_preferredStart)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _isSaving ? null : _pickStartTime,
                ),
              ),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.access_time_filled),
                  title: const Text('End Time'),
                  subtitle: Text(_formatTime(_preferredEnd)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _isSaving ? null : _pickEndTime,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              Text(
                'Preferred Activities',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: AppSpacing.md),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableActivities.map((activity) {
                  return FilterChip(
                    label: Text(activity),
                    selected: _activities.contains(activity),
                    onSelected: _isSaving
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected) {
                                _activities.add(activity);
                              } else {
                                _activities.remove(activity);
                              }
                            });
                          },
                  );
                }).toList(),
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
                label: 'Save Preferences',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _savePreferences,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
