import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';

class LogUnplannedMomentScreen extends StatefulWidget {
  const LogUnplannedMomentScreen({super.key});

  @override
  State<LogUnplannedMomentScreen> createState() =>
      _LogUnplannedMomentScreenState();
}

class _LogUnplannedMomentScreenState extends State<LogUnplannedMomentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  CurrentFamilyContext? _familyContext;
  List<Member> _members = <Member>[];

  final Set<String> _participantIds = <String>{};

  MomentCategory _category = MomentCategory.familyTime;

  int _importanceLevel = 3;
  int _durationMinutes = 45;

  late DateTime _date;
  late TimeOfDay _time;

  bool _saveAsRecurring = false;
  int _expectedIntervalDays = 7;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final initialTime = DateTime.now().subtract(const Duration(hours: 1));

    _date = DateUtils.dateOnly(initialTime);
    _time = TimeOfDay.fromDateTime(initialTime);

    _loadForm();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadForm() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      if (!familyContext.isAdult) {
        throw StateError(
          'Only an adult or family admin can '
          'log a shared unplanned Moment.',
        );
      }

      final members = await AppDependencies.currentFamilyService
          .watchFamilyMembers(familyContext.familyId)
          .first;

      final activeIds = members
          .where((member) => member.isActive)
          .map((member) => member.id)
          .toSet();

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _members = members;
        _participantIds
          ..clear()
          ..addAll(activeIds);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is StateError
            ? error.message.toString()
            : 'We could not prepare the form.';
      });
    }
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 7)),
      lastDate: today,
    );

    if (selected == null) return;

    setState(() {
      _date = DateUtils.dateOnly(selected);
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);

    if (selected == null) return;

    setState(() {
      _time = selected;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final familyContext = _familyContext;

    if (familyContext == null || _isSaving) {
      return;
    }

    if (_participantIds.isEmpty) {
      _showMessage('Choose at least one participant.');
      return;
    }

    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    final end = start.add(Duration(minutes: _durationMinutes));

    if (end.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      _showMessage('The reported Moment cannot end in the future.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result = await AppDependencies.momentOutcomeService
          .logUnplannedMoment(
            familyId: familyContext.familyId,
            createdBy: familyContext.userId,
            title: _titleController.text.trim(),
            category: _category,
            importanceLevel: _importanceLevel,
            participantIds: _participantIds.toList()..sort(),
            actualStartAt: start,
            durationMinutes: _durationMinutes,
            saveAsRecurring: _saveAsRecurring,
            expectedIntervalDays: _expectedIntervalDays,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );

      if (!mounted) return;

      Navigator.of(context).pop(result.instance.id);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error is StateError
            ? error.message.toString()
            : error is ArgumentError
            ? error.message?.toString()
            : 'We could not record this Moment.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
          child: AppLoadingState(message: 'Preparing the Moment form…'),
        ),
      );
    }

    if (_familyContext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Log a Family Moment')),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'This form is unavailable.',
            onRetry: _loadForm,
          ),
        ),
      );
    }

    final activeMembers = _members.where((member) => member.isActive).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Log a Family Moment')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              104,
            ),
            children: [
              Text(
                'What did your family do?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Use this when the Moment happened '
                'without being started or scheduled in Sakan.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Moment name',
                  hintText: 'Evening Tea, Family Walk…',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a Moment name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<MomentCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items:
                    const <MomentCategory>[
                          MomentCategory.tradition,
                          MomentCategory.familyTime,
                          MomentCategory.care,
                          MomentCategory.milestone,
                        ]
                        .map(
                          (category) => DropdownMenuItem<MomentCategory>(
                            value: category,
                            child: Text(_categoryLabel(category)),
                          ),
                        )
                        .toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _category = value;
                        });
                      },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Date'),
                      subtitle: Text(
                        '${_date.day}/${_date.month}/${_date.year}',
                      ),
                      onTap: _isSaving ? null : _pickDate,
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time_outlined),
                      title: const Text('Approximate start'),
                      subtitle: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatTimeOfDay(_time),
                      ),
                      onTap: _isSaving ? null : _pickTime,
                    ),
                    const Divider(),
                    DropdownButtonFormField<int>(
                      initialValue: _durationMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Approximate duration',
                      ),
                      items: const <int>[15, 30, 45, 60, 90, 120]
                          .map(
                            (minutes) => DropdownMenuItem<int>(
                              value: minutes,
                              child: Text('$minutes minutes'),
                            ),
                          )
                          .toList(),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _durationMinutes = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Who participated?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: activeMembers.map((member) {
                  final selected = _participantIds.contains(member.id);

                  return FilterChip(
                    label: Text(member.displayName),
                    selected: selected,
                    onSelected: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              if (value) {
                                _participantIds.add(member.id);
                              } else {
                                _participantIds.remove(member.id);
                              }
                            });
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Importance ($_importanceLevel/5)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: _importanceLevel.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$_importanceLevel',
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _importanceLevel = value.round();
                        });
                      },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Save as a recurring family Moment'),
                subtitle: const Text(
                  'Sakan will create the next occurrence '
                  'and begin learning its rhythm.',
                ),
                value: _saveAsRecurring,
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _saveAsRecurring = value;
                        });
                      },
              ),
              if (_saveAsRecurring) ...[
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<int>(
                  initialValue: _expectedIntervalDays,
                  decoration: const InputDecoration(
                    labelText: 'Expected rhythm',
                  ),
                  items: const <int>[1, 7, 14, 30]
                      .map(
                        (days) => DropdownMenuItem<int>(
                          value: days,
                          child: Text(
                            days == 1
                                ? 'Daily'
                                : days == 7
                                ? 'Weekly'
                                : days == 14
                                ? 'Every 2 weeks'
                                : 'Monthly',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _expectedIntervalDays = value;
                          });
                        },
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _noteController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Optional note',
                  hintText: 'What should the family remember?',
                  alignLabelWithHint: true,
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
                label: 'Record Family Moment',
                icon: Icons.fact_check_outlined,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _categoryLabel(MomentCategory category) {
    return switch (category) {
      MomentCategory.tradition => 'Tradition',
      MomentCategory.familyTime => 'Family Time',
      MomentCategory.care => 'Care',
      MomentCategory.milestone => 'Milestone',
      MomentCategory.responsibility => 'Responsibility',
      MomentCategory.memory => 'Memory',
    };
  }
}
