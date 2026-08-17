import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() =>
      _PreferencesScreenState();
}

class _PreferencesScreenState
    extends State<PreferencesScreen> {
  final Set<int> _preferredDays = {5, 6};

  TimeOfDay _preferredStart =
      const TimeOfDay(hour: 18, minute: 0);

  TimeOfDay _preferredEnd =
      const TimeOfDay(hour: 21, minute: 0);

  final Set<String> _activities = {
    'Friday Lunch',
    'Family Dinner',
  };

  final List<String> _availableActivities = [
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

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _preferredStart,
    );

    if (picked != null) {
      setState(() {
        _preferredStart = picked;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _preferredEnd,
    );

    if (picked != null) {
      setState(() {
        _preferredEnd = picked;
      });
    }
  }

  String _format(TimeOfDay time) {
    final hour =
        time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;

    final minute =
        time.minute.toString().padLeft(2, '0');

    final suffix =
        time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $suffix';
  }

  final List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Family Time Preferences',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Preferred Family Days',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),

              const SizedBox(
                height: AppSpacing.md,
              ),

              Wrap(
                spacing: 8,
                children: List.generate(
                  7,
                  (index) {
                    final day = index + 1;

                    final selected =
                        _preferredDays.contains(day);

                    return FilterChip(
                      label: Text(
                        _weekDays[index],
                      ),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          if (selected) {
                            _preferredDays.remove(day);
                          } else {
                            _preferredDays.add(day);
                          }
                        });
                      },
                    );
                  },
                ),
              ),

              const SizedBox(
                height: AppSpacing.xl,
              ),

              Text(
                'Preferred Family Time',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),

              const SizedBox(
                height: AppSpacing.md,
              ),

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.access_time,
                  ),
                  title:
                      const Text('Start Time'),
                  subtitle:
                      Text(_format(_preferredStart)),
                  onTap: _pickStartTime,
                ),
              ),

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.access_time_filled,
                  ),
                  title: const Text('End Time'),
                  subtitle:
                      Text(_format(_preferredEnd)),
                  onTap: _pickEndTime,
                ),
              ),

              const SizedBox(
                height: AppSpacing.xl,
              ),

              Text(
                'Preferred Activities',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),

              const SizedBox(
                height: AppSpacing.md,
              ),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _availableActivities.map(
                  (activity) {
                    final selected =
                        _activities.contains(activity);

                    return FilterChip(
                      label: Text(activity),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          if (selected) {
                            _activities.remove(
                              activity,
                            );
                          } else {
                            _activities.add(
                              activity,
                            );
                          }
                        });
                      },
                    );
                  },
                ).toList(),
              ),

              const SizedBox(
                height: AppSpacing.xxl,
              ),

              AppPrimaryButton(
                label: 'Save Preferences',
                onPressed: () {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Preferences saved.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}