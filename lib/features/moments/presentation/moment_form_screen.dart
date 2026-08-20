import 'package:flutter/material.dart';
import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/current_family_context.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/utils/moment_visuals.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';
import 'package:sakan/shared/widgets/feedback/app_error_state.dart';
import 'package:sakan/shared/widgets/feedback/app_loading_state.dart';

class MomentFormScreen extends StatefulWidget {
  const MomentFormScreen({this.initialMoment, super.key});

  final FamilyMoment? initialMoment;

  @override
  State<MomentFormScreen> createState() => _MomentFormScreenState();
}

class _MomentFormScreenState extends State<MomentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();

  final _locationController = TextEditingController();

  final _notesController = TextEditingController();

  CurrentFamilyContext? _familyContext;
  List<Member> _members = <Member>[];

  final Set<String> _selectedParticipantIds = <String>{};

  MomentType _type = MomentType.recurring;

  MomentCategory _category = MomentCategory.tradition;

  EvidenceType _evidenceType = EvidenceType.scheduledOnly;

  MomentStatus _status = MomentStatus.scheduled;

  int _importanceLevel = 4;
  int _intervalDays = 7;

  DateTime _startDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );

  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);

  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 0);

  bool _hasEndTime = true;
  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  bool get _isEditing => widget.initialMoment != null;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
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
        throw StateError('Only an adult or family admin can manage moments.');
      }

      final members = await AppDependencies.currentFamilyService
          .watchFamilyMembers(familyContext.familyId)
          .first;

      final initialMoment = widget.initialMoment;

      if (initialMoment != null) {
        final startLocal = initialMoment.startAt.toLocal();

        final endLocal = initialMoment.endAt?.toLocal();

        _titleController.text = initialMoment.title;

        _locationController.text = initialMoment.location ?? '';

        _notesController.text = initialMoment.notes ?? '';

        _type = initialMoment.type;
        _category = initialMoment.category;

        _importanceLevel = initialMoment.importanceLevel;

        _intervalDays = initialMoment.expectedIntervalDays ?? 7;

        _evidenceType = initialMoment.evidenceType;

        _status = initialMoment.status;

        _startDate = DateUtils.dateOnly(startLocal);

        _startTime = TimeOfDay.fromDateTime(startLocal);

        _hasEndTime = endLocal != null;

        if (endLocal != null) {
          _endTime = TimeOfDay.fromDateTime(endLocal);
        }

        _selectedParticipantIds
          ..clear()
          ..addAll(initialMoment.expectedParticipantIds);
      } else {
        _selectedParticipantIds
          ..clear()
          ..addAll(
            members
                .where((member) => member.isActive)
                .map((member) => member.id),
          );
      }

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _members = members;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is StateError
            ? error.message
            : 'We could not prepare the moment form.';
      });
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
    );

    if (selected == null) return;

    setState(() {
      _startDate = DateUtils.dateOnly(selected);
    });
  }

  Future<void> _pickStartTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );

    if (selected == null) return;

    setState(() {
      _startTime = selected;
    });
  }

  Future<void> _pickEndTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );

    if (selected == null) return;

    setState(() {
      _endTime = selected;
    });
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveMoment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final familyContext = _familyContext;

    if (familyContext == null || _isSaving) {
      return;
    }

    if (_selectedParticipantIds.isEmpty) {
      _showMessage('Choose at least one expected participant.');
      return;
    }

    if (_type == MomentType.recurring && _intervalDays <= 0) {
      _showMessage('Choose a valid recurrence frequency.');
      return;
    }

    final startLocal = _combineDateAndTime(_startDate, _startTime);

    DateTime? endLocal;

    if (_hasEndTime) {
      endLocal = _combineDateAndTime(_startDate, _endTime);

      if (!endLocal.isAfter(startLocal)) {
        _showMessage('End time must be after the start time.');
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final initialMoment = widget.initialMoment;

      final now = DateTime.now().toUtc();

      final momentId =
          initialMoment?.id ??
          'moment_${familyContext.userId}_'
              '${DateTime.now().microsecondsSinceEpoch}';

      final moment = FamilyMoment(
        id: momentId,
        familyId: familyContext.familyId,
        title: _titleController.text.trim(),
        type: _type,
        category: _category,
        importanceLevel: _importanceLevel,
        expectedParticipantIds: _selectedParticipantIds.toList(),
        startAt: startLocal.toUtc(),
        endAt: endLocal?.toUtc(),
        expectedIntervalDays: _type == MomentType.recurring
            ? _intervalDays
            : null,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        evidenceType: _evidenceType,
        status: _status,
        createdBy: initialMoment?.createdBy ?? familyContext.userId,
        createdAt: initialMoment?.createdAt ?? now,
        updatedAt: now,
      );

      await AppDependencies.calendarRepository.saveMoment(moment);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'We could not save this family moment.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteMoment() async {
    final initialMoment = widget.initialMoment;

    if (initialMoment == null || _isSaving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this moment?'),
          content: Text(
            '“${initialMoment.title}” will be '
            'removed from Moments, Calendar, and '
            'its Rhythm record.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await AppDependencies.calendarRepository.deleteMoment(
        familyId: initialMoment.familyId,
        momentId: initialMoment.id,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      _showMessage('We could not delete this moment.');
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

  List<int> _frequencyValues() {
    final values = <int>{
      1,
      7,
      14,
      30,
      90,
      365,
      _intervalDays,
    }.where((value) => value > 0).toList();

    values.sort();

    return values;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Preparing the family moment…'),
        ),
      );
    }

    if (_familyContext == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Family Moment' : 'Add Family Moment'),
        ),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'The moment form is unavailable.',
            onRetry: _loadForm,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Family Moment' : 'Add Family Moment'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete moment',
              onPressed: _isSaving ? null : _deleteMoment,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Moment Name',
                    hintText: 'Friday Lunch, Graduation…',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a moment name.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                SegmentedButton<MomentType>(
                  segments: const [
                    ButtonSegment(
                      value: MomentType.recurring,
                      icon: Icon(Icons.repeat_rounded),
                      label: Text('Recurring'),
                    ),
                    ButtonSegment(
                      value: MomentType.singular,
                      icon: Icon(Icons.event_outlined),
                      label: Text('One-time'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: _isSaving
                      ? null
                      : (selection) {
                          setState(() {
                            _type = selection.first;
                          });
                        },
                ),

                const SizedBox(height: AppSpacing.lg),

                AppCard(
                  child: Column(
                    children: [
                      DropdownButtonFormField<MomentCategory>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: MomentCategory.values
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(momentCategoryLabel(category)),
                              ),
                            )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }

                                setState(() {
                                  _category = value;
                                });
                              },
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Importance '
                          '($_importanceLevel/5)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),

                      Slider(
                        value: _importanceLevel.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '$_importanceLevel/5',
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                setState(() {
                                  _importanceLevel = value.round();
                                });
                              },
                      ),
                    ],
                  ),
                ),

                if (_type == MomentType.recurring) ...[
                  const SizedBox(height: AppSpacing.lg),

                  DropdownButtonFormField<int>(
                    initialValue: _intervalDays,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    items: _frequencyValues()
                        .map(
                          (days) => DropdownMenuItem(
                            value: days,
                            child: Text(switch (days) {
                              1 => 'Daily',
                              7 => 'Weekly',
                              14 => 'Every 2 weeks',
                              30 => 'Monthly',
                              90 => 'Every 3 months',
                              365 => 'Yearly',
                              _ => 'Every $days days',
                            }),
                          ),
                        )
                        .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _intervalDays = value;
                            });
                          },
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                AppCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: const Text('Date'),
                        subtitle: Text(
                          '${_startDate.day}/'
                          '${_startDate.month}/'
                          '${_startDate.year}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _isSaving ? null : _pickDate,
                      ),

                      const Divider(),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time_outlined),
                        title: const Text('Start Time'),
                        subtitle: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatTimeOfDay(_startTime),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _isSaving ? null : _pickStartTime,
                      ),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Add End Time'),
                        value: _hasEndTime,
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                setState(() {
                                  _hasEndTime = value;
                                });
                              },
                      ),

                      if (_hasEndTime)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.access_time_filled),
                          title: const Text('End Time'),
                          subtitle: Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatTimeOfDay(_endTime),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _isSaving ? null : _pickEndTime,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Expected Participants',
                  style: Theme.of(context).textTheme.titleLarge,
                ),

                const SizedBox(height: AppSpacing.sm),

                AppCard(
                  child: Column(
                    children: _members
                        .where((member) => member.isActive)
                        .map(
                          (member) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(member.displayName),
                            value: _selectedParticipantIds.contains(member.id),
                            onChanged: _isSaving
                                ? null
                                : (selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedParticipantIds.add(member.id);
                                      } else {
                                        _selectedParticipantIds.remove(
                                          member.id,
                                        );
                                      }
                                    });
                                  },
                          ),
                        )
                        .toList(),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                DropdownButtonFormField<EvidenceType>(
                  initialValue: _evidenceType,
                  decoration: const InputDecoration(
                    labelText: 'Evidence Method',
                  ),
                  items: EvidenceType.values
                      .map(
                        (evidence) => DropdownMenuItem(
                          value: evidence,
                          child: Text(evidenceTypeLabel(evidence)),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _evidenceType = value;
                          });
                        },
                ),

                if (_isEditing) ...[
                  const SizedBox(height: AppSpacing.lg),

                  DropdownButtonFormField<MomentStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Moment Status',
                    ),
                    items: MomentStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(momentStatusLabel(status)),
                          ),
                        )
                        .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _status = value;
                            });
                          },
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'Dining Room, School…',
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),

                AppPrimaryButton(
                  label: _isEditing ? 'Save Changes' : 'Save Moment',
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _saveMoment,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
