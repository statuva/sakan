import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/availability_block.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/services/moment_schedule_resolver.dart';
import '../../../shared/utils/moment_visuals.dart';
import '../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/controls/app_pill_segmented_control.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../services/moment_session_timing_service.dart';

class MomentFormScreen extends StatefulWidget {
  const MomentFormScreen({
    this.initialMoment,
    this.draftMoment,
    this.requireConflictFreeTime = false,
    super.key,
  }) : assert(initialMoment == null || draftMoment == null);

  final FamilyMoment? initialMoment;
  final FamilyMoment? draftMoment;
  final bool requireConflictFreeTime;

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
  List<AvailabilityBlock> _availability = <AvailabilityBlock>[];

  final Set<String> _selectedParticipantIds = <String>{};

  MomentType _type = MomentType.recurring;
  MomentCategory _category = MomentCategory.tradition;
  MomentFormat _format = MomentFormat.sharedSession;

  final Set<String> _subjectMemberIds = <String>{};

  int _importanceLevel = 4;
  int _intervalDays = 7;

  DateTime _oneTimeDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );

  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 0);

  bool _hasEndTime = true;
  bool _isDayFlexible = false;
  bool _isArchived = false;

  int _preferredWeekday = DateTime.friday;
  int _preferredDayOfMonth = 1;
  int _preferredMonth = DateTime.january;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _newMomentId;
  String? _errorMessage;

  bool get _isEditing => widget.initialMoment != null;
  bool get _isSimulationDraft => widget.draftMoment != null;

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
        throw StateError('Only an adult or family admin can manage Moments.');
      }

      if (_isSimulationDraft && !familyContext.canUseAi) {
        throw StateError(
          'Only an active adult or family admin can create a Moment from a simulation.',
        );
      }

      _newMomentId ??=
          'moment_${familyContext.userId}_'
          '${DateTime.now().microsecondsSinceEpoch}';

      final formData = await Future.wait<Object>([
        AppDependencies.currentFamilyService
            .watchFamilyMembers(familyContext.familyId)
            .first,
        AppDependencies.scheduleRepository
            .watchFamilyAvailability(familyId: familyContext.familyId)
            .first,
      ]);
      final members = formData[0] as List<Member>;
      final availability = formData[1] as List<AvailabilityBlock>;

      final seedMoment = widget.initialMoment ?? widget.draftMoment;

      if (seedMoment != null) {
        final startLocal = seedMoment.startAt.toLocal();
        final startMinutes = seedMoment.resolvedPreferredStartMinutes;
        final endMinutes = seedMoment.resolvedPreferredEndMinutes;

        _titleController.text = seedMoment.title;
        _locationController.text = seedMoment.location ?? '';
        _notesController.text = seedMoment.notes ?? '';

        _type = seedMoment.type;
        _category = seedMoment.category;
        _format = seedMoment.format;

        _importanceLevel = seedMoment.importanceLevel;
        _intervalDays = seedMoment.expectedIntervalDays ?? 7;

        _oneTimeDate = DateUtils.dateOnly(startLocal);
        _startTime = _timeFromMinutes(startMinutes);
        _hasEndTime = endMinutes != null;

        if (endMinutes != null) {
          _endTime = _timeFromMinutes(endMinutes);
        }

        _isDayFlexible = seedMoment.isDayFlexible;
        _isArchived = seedMoment.isArchived;
        _preferredWeekday =
            seedMoment.preferredWeekday ?? startLocal.weekday;
        _preferredDayOfMonth =
            seedMoment.preferredDayOfMonth ?? startLocal.day;
        _preferredMonth = seedMoment.preferredMonth ?? startLocal.month;

        _selectedParticipantIds
          ..clear()
          ..addAll(seedMoment.expectedParticipantIds);

        _subjectMemberIds
          ..clear()
          ..addAll(seedMoment.subjectMemberIds);

        final activeMemberIds = members
            .where((member) => member.isActive)
            .map((member) => member.id)
            .toSet();
        _selectedParticipantIds.retainWhere(activeMemberIds.contains);
        _subjectMemberIds.retainWhere(activeMemberIds.contains);
      } else {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        _oneTimeDate = DateUtils.dateOnly(tomorrow);
        _preferredWeekday = tomorrow.weekday;
        _preferredDayOfMonth = tomorrow.day;
        _preferredMonth = tomorrow.month;

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
        _availability = availability;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is StateError
            ? error.message.toString()
            : 'We could not prepare the Moment form.';
      });
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _oneTimeDate,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
    );

    if (selected == null) return;

    setState(() {
      _oneTimeDate = DateUtils.dateOnly(selected);
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

  ({
    DateTime start,
    DateTime? end,
    bool flexible,
    int startMinutes,
    int? endMinutes,
  })
  _resolveTiming({DateTime? reference}) {
    final now = reference ?? DateTime.now();
    final interval = _type == MomentType.recurring ? _intervalDays : 0;
    final flexible =
        _type == MomentType.recurring &&
        (_intervalDays == 7 ||
            _intervalDays == 14 ||
            _intervalDays == 30 ||
            _intervalDays == 90) &&
        _isDayFlexible;
    final startMinutes = _minutesFromTime(_startTime);
    final endMinutes = _hasEndTime ? _minutesFromTime(_endTime) : null;
    final exactStart = MomentScheduleResolver.firstExactStart(
      type: _type,
      reference: now,
      startMinutes: startMinutes,
      oneTimeDate: _type == MomentType.singular ? _oneTimeDate : null,
      intervalDays: interval,
      isDayFlexible: flexible,
      preferredWeekday: _preferredWeekday,
      preferredDayOfMonth: _preferredDayOfMonth,
      preferredMonth: _preferredMonth,
    );
    final start =
        exactStart ??
        MomentScheduleResolver.anchorForFlexible(
          reference: now,
          startMinutes: startMinutes,
        );
    final end = MomentScheduleResolver.endForStart(
      start: start,
      endMinutes: endMinutes,
    );

    return (
      start: start,
      end: end,
      flexible: flexible,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );
  }

  MomentSessionTimingNote? _currentTimingNote() {
    if (!widget.requireConflictFreeTime || _selectedParticipantIds.isEmpty) {
      return null;
    }

    final timing = _resolveTiming();
    final end = timing.end;
    if (end == null) {
      return null;
    }

    return MomentSessionTimingService.build(
      expectedParticipantIds: _selectedParticipantIds.toList(),
      availability: _availability,
      start: timing.start,
      end: end,
    );
  }

  Set<String> _conflictsForWindow({
    required List<String> participantIds,
    required List<AvailabilityBlock> availability,
    required DateTime start,
    required DateTime end,
  }) {
    final firstNote = MomentSessionTimingService.build(
      expectedParticipantIds: participantIds,
      availability: availability,
      start: start,
      end: end,
    );
    final conflicts = <String>{...?firstNote?.conflictingMemberIds};
    final localStart = start.toLocal();
    final localEnd = end.toLocal();
    final crossesMidnight = localStart.year != localEnd.year ||
        localStart.month != localEnd.month ||
        localStart.day != localEnd.day;

    if (crossesMidnight) {
      final midnight = DateTime(
        localEnd.year,
        localEnd.month,
        localEnd.day,
      );
      final nextDayNote = MomentSessionTimingService.build(
        expectedParticipantIds: participantIds,
        availability: availability,
        start: midnight,
        end: localEnd,
      );
      conflicts.addAll(
        nextDayNote?.conflictingMemberIds ?? const <String>{},
      );
    }

    return conflicts;
  }

  ({Set<String> memberIds, DateTime? start}) _firstProjectedConflict({
    required FamilyMoment moment,
    required List<AvailabilityBlock> availability,
    required DateTime reference,
  }) {
    final end = moment.endAt;
    if (end == null) {
      return (memberIds: const <String>{}, start: null);
    }

    final duration = end.difference(moment.startAt);
    final checks = moment.type == MomentType.recurring ? 4 : 1;
    var start = moment.startAt.toLocal();

    for (var index = 0; index < checks; index++) {
      final conflicts = _conflictsForWindow(
        participantIds: moment.expectedParticipantIds,
        availability: availability,
        start: start,
        end: start.add(duration),
      );
      if (conflicts.isNotEmpty) {
        return (memberIds: conflicts, start: start);
      }

      final next = MomentScheduleResolver.nextExactStart(
        moment: moment,
        after: start,
        now: reference,
      );
      if (next == null) {
        break;
      }
      start = next;
    }

    return (memberIds: const <String>{}, start: null);
  }

  Future<void> _saveMoment({bool? archivedOverride}) async {
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

    final timing = _resolveTiming();
    final flexible = timing.flexible;
    final startMinutes = timing.startMinutes;
    final endMinutes = timing.endMinutes;
    final startLocal = timing.start;
    final endLocal = timing.end;

    if (_type == MomentType.singular &&
        startLocal.isBefore(
          DateTime.now().subtract(const Duration(minutes: 1)),
        )) {
      _showMessage('Choose a future date and time for a one-time Moment.');
      return;
    }

    if (widget.requireConflictFreeTime && flexible) {
      _showMessage(
        'Choose a specific day so Sakan can check the approved time.',
      );
      return;
    }

    if (widget.requireConflictFreeTime && endLocal == null) {
      _showMessage(
        'Add an end time so Sakan can check for busy-time conflicts.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final initialMoment = widget.initialMoment;
      final now = DateTime.now().toUtc();
      final archived = archivedOverride ?? _isArchived;

      if (_isSimulationDraft) {
        final latestContext = await AppDependencies.currentFamilyService.load();
        if (latestContext.familyId != familyContext.familyId ||
            latestContext.userId != familyContext.userId ||
            !latestContext.canUseAi) {
          throw StateError(
            'Your family access changed. Reopen the simulation before creating this Moment.',
          );
        }

        final latestMembers = await AppDependencies.currentFamilyService
            .watchFamilyMembers(familyContext.familyId)
            .first;
        final activeMemberIds = latestMembers
            .where((member) => member.isActive)
            .map((member) => member.id)
            .toSet();
        final invalidParticipantIds = _selectedParticipantIds
            .where((id) => !activeMemberIds.contains(id))
            .toList(growable: false);
        final invalidSubjectIds = _subjectMemberIds
            .where((id) => !activeMemberIds.contains(id))
            .toList(growable: false);

        if (invalidParticipantIds.isNotEmpty || invalidSubjectIds.isNotEmpty) {
          throw StateError(
            'A selected family member is no longer active. Review the participants and try again.',
          );
        }

        _members = latestMembers;
      }

      final momentId =
          initialMoment?.id ??
          _newMomentId!;

      final moment = FamilyMoment(
        id: momentId,
        familyId: familyContext.familyId,
        title: _titleController.text.trim(),
        type: _type,
        category: _category,
        format: _format,
        subjectMemberIds: _subjectMemberIds.toList(),
        importanceLevel: _importanceLevel,
        expectedParticipantIds: _selectedParticipantIds.toList(),
        startAt: startLocal.toUtc(),
        endAt: endLocal?.toUtc(),
        expectedIntervalDays: _type == MomentType.recurring
            ? _intervalDays
            : null,
        preferredStartMinutes: _type == MomentType.recurring
            ? startMinutes
            : null,
        preferredEndMinutes: _type == MomentType.recurring ? endMinutes : null,
        preferredWeekday:
            _type == MomentType.recurring &&
                (_intervalDays == 7 || _intervalDays == 14) &&
                !flexible
            ? _preferredWeekday
            : null,
        preferredDayOfMonth:
            _type == MomentType.recurring &&
                (_intervalDays == 30 ||
                    _intervalDays == 90 ||
                    _intervalDays == 365) &&
                !flexible
            ? _preferredDayOfMonth
            : null,
        preferredMonth: _type == MomentType.recurring && _intervalDays == 365
            ? _preferredMonth
            : null,
        isDayFlexible: flexible,
        isArchived: archived,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        evidenceType: EvidenceType.manual,
        status: archived ? MomentStatus.cancelled : MomentStatus.scheduled,
        createdBy: initialMoment?.createdBy ?? familyContext.userId,
        createdAt: initialMoment?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.requireConflictFreeTime) {
        final latestAvailability = await AppDependencies.scheduleRepository
            .watchFamilyAvailability(familyId: familyContext.familyId)
            .first;
        _availability = latestAvailability;

        final conflict = _firstProjectedConflict(
          moment: moment,
          availability: latestAvailability,
          reference: DateTime.now(),
        );

        if (conflict.memberIds.isNotEmpty) {
          final names = _members
              .where((member) => conflict.memberIds.contains(member.id))
              .map((member) => member.displayName)
              .toList()
            ..sort();
          final date = conflict.start == null
              ? ''
              : ' on ${DateFormat('EEE, d MMM').format(conflict.start!)}';
          final people = names.isEmpty
              ? 'a selected participant'
              : names.join(', ');
          throw StateError(
            'Choose another time. This plan overlaps $people’s recorded '
            'busy time$date.',
          );
        }
      }

      await AppDependencies.calendarRepository.saveMoment(moment);

      if (archived || flexible) {
        final openInstance = await AppDependencies.momentInstanceRepository
            .getOpenInstanceForMoment(
              familyId: moment.familyId,
              momentId: moment.id,
            );

        // Do not cancel a Moment that is already live. The definition can be
        // archived or made flexible after the active session finishes.
        if (openInstance == null || !openInstance.isActive) {
          await AppDependencies.momentInstanceRepository
              .cancelOpenInstancesForMoment(
                familyId: moment.familyId,
                momentId: moment.id,
                cancelledBy: familyContext.userId,
              );
        }
      } else {
        await AppDependencies.momentInstanceRepository
            .syncScheduledInstanceFromMoment(
              moment: moment,
              createdBy: familyContext.userId,
              source: MomentInstanceSource.calendar,
            );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error is StateError
            ? error.message.toString()
            : 'We could not save this Family Moment.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _toggleArchived() async {
    final nextValue = !_isArchived;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            nextValue ? 'Archive this Moment?' : 'Restore this Moment?',
          ),
          content: Text(
            nextValue
                ? 'Future open occurrences will be cancelled. Completed and missed history will remain.'
                : 'Sakan will restore the definition and create its next exact occurrence when a day is configured.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(nextValue ? 'Archive' : 'Restore'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isArchived = nextValue;
    });

    await _saveMoment(archivedOverride: nextValue);
  }

  Future<void> _deleteMoment() async {
    final initialMoment = widget.initialMoment;

    if (initialMoment == null || _isSaving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete this Moment definition?'),
          content: Text(
            '“${initialMoment.title}” will be removed from the Moment Library. '
            'Use Archive instead when you want to preserve the definition.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
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
      await AppDependencies.momentInstanceRepository
          .cancelOpenInstancesForMoment(
            familyId: initialMoment.familyId,
            momentId: initialMoment.id,
            cancelledBy: _familyContext!.userId,
          );

      await AppDependencies.calendarRepository.deleteMoment(
        familyId: initialMoment.familyId,
        momentId: initialMoment.id,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('We could not delete this Moment.');
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
          child: AppLoadingState(message: 'Preparing the Family Moment…'),
        ),
      );
    }

    if (_familyContext == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing
                ? 'Edit Family Moment'
                : _isSimulationDraft
                ? 'Create This Moment'
                : 'Add Family Moment',
          ),
        ),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'The Moment form is unavailable.',
            onRetry: _loadForm,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Edit Family Moment'
              : _isSimulationDraft
              ? 'Create This Moment'
              : 'Add Family Moment',
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete Moment',
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
                if (_isSimulationDraft) ...[
                  const AppCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.science_outlined),
                      title: Text('From your simulation'),
                      subtitle: Text(
                        'Review every detail. Nothing is created until you '
                        'approve a time with no recorded busy-time conflicts.',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Moment Name',
                    hintText: 'Friday Lunch, Graduation…',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a Moment name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppPillSegmentedControl<MomentType>(
                  segments: const [
                    AppPillSegment(
                      value: MomentType.recurring,
                      label: 'Recurring',
                    ),
                    AppPillSegment(
                      value: MomentType.singular,
                      label: 'One-time',
                    ),
                  ],
                  selectedValue: _type,
                  enabled: !_isSaving,
                  onChanged: (value) {
                    setState(() {
                      _type = value;
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
                                if (value != null) {
                                  setState(() {
                                    _category = value;
                                  });
                                }
                              },
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      DropdownButtonFormField<MomentFormat>(
                        initialValue: _format,
                        decoration: const InputDecoration(
                          labelText: 'How does this Moment happen?',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: MomentFormat.sharedSession,
                            child: Text('Shared session in Sakan'),
                          ),
                          DropdownMenuItem(
                            value: MomentFormat.externalEvent,
                            child: Text('External event / attendance'),
                          ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value == null) return;

                                setState(() {
                                  _format = value;
                                });
                              },
                      ),

                      const SizedBox(height: AppSpacing.lg),
                      const SizedBox(height: AppSpacing.lg),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Importance ($_importanceLevel/5)',
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
                            child: Text(_frequencyLabel(days)),
                          ),
                        )
                        .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _intervalDays = value;
                                if (value == 1 || value == 365) {
                                  _isDayFlexible = false;
                                }
                              });
                            }
                          },
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _buildTimingCard(context),
                if (_isSimulationDraft) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildSimulationTimingCheck(context),
                ],
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

                Text(
                  'Who is this Moment about? (optional)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),

                const SizedBox(height: AppSpacing.xs),

                Text(
                  'Use this for birthdays, graduations, ceremonies, and Moments centered on a specific family member.',
                  style: Theme.of(context).textTheme.bodyMedium,
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
                            value: _subjectMemberIds.contains(member.id),
                            onChanged: _isSaving
                                ? null
                                : (selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _subjectMemberIds.add(member.id);
                                      } else {
                                        _subjectMemberIds.remove(member.id);
                                      }
                                    });
                                  },
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'Dining Room, Park…',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What makes this Moment meaningful?',
                  ),
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
                  label: _isEditing
                      ? 'Save Changes'
                      : _isSimulationDraft
                      ? 'Approve & Create Moment'
                      : 'Save Moment',
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _saveMoment,
                ),
                if (_isEditing) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _toggleArchived,
                    icon: Icon(
                      _isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                    label: Text(
                      _isArchived
                          ? 'Restore this Moment'
                          : 'Archive this Moment',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimulationTimingCheck(BuildContext context) {
    final timing = _resolveTiming();
    final note = _currentTimingNote();
    final conflicts = timing.end == null
        ? const <String>{}
        : _conflictsForWindow(
            participantIds: _selectedParticipantIds.toList(),
            availability: _availability,
            start: timing.start,
            end: timing.end!,
          );
    final conflictingNames = _members
        .where((member) => conflicts.contains(member.id))
        .map((member) => member.displayName)
        .toList()
      ..sort();
    final missingScheduleCount =
        _selectedParticipantIds.length - (note?.membersWithScheduleData ?? 0);

    late final IconData icon;
    late final String title;
    late final String body;

    if (timing.flexible) {
      icon = Icons.event_busy_outlined;
      title = 'Choose a specific day';
      body = 'An exact day and end time are needed before this simulated '
          'Moment can be checked and created.';
    } else if (timing.end == null) {
      icon = Icons.more_time_rounded;
      title = 'Add an end time';
      body = 'Sakan needs the full time range to compare it with recorded '
          'busy periods.';
    } else if (conflicts.isNotEmpty) {
      icon = Icons.schedule_rounded;
      title = 'Choose another time';
      body = 'This time overlaps recorded busy time for '
          '${conflictingNames.join(', ')}.';
    } else if (note == null) {
      icon = Icons.help_outline_rounded;
      title = 'Schedule coverage is incomplete';
      body = 'No selected participant has recorded schedule data. The adult '
          'can still approve the time, but Sakan cannot verify availability.';
    } else if (missingScheduleCount > 0) {
      icon = Icons.event_available_outlined;
      title = 'No recorded conflicts found';
      body = 'The time is clear in the available schedules. '
          '$missingScheduleCount selected '
          '${missingScheduleCount == 1 ? 'participant has' : 'participants have'} '
          'no recorded schedule coverage.';
    } else {
      icon = Icons.event_available_rounded;
      title = 'No recorded busy-time conflicts';
      body = 'The approved time is clear in every selected participant’s '
          'recorded schedule.';
    }

    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(body),
      ),
    );
  }

  Widget _buildTimingCard(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          if (_type == MomentType.singular) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Date'),
              subtitle: Text(DateFormat('d/M/y').format(_oneTimeDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _isSaving ? null : _pickDate,
            ),
            const Divider(),
          ] else ...[
            if (_intervalDays == 7 || _intervalDays == 14) ...[
              DropdownButtonFormField<int>(
                initialValue: _isDayFlexible ? 0 : _preferredWeekday,
                decoration: const InputDecoration(labelText: 'Preferred Day'),
                items: <DropdownMenuItem<int>>[
                  const DropdownMenuItem(value: 0, child: Text('Flexible')),
                  ...List.generate(7, (index) {
                    final weekday = index + 1;
                    return DropdownMenuItem(
                      value: weekday,
                      child: Text(_weekdayLabel(weekday)),
                    );
                  }),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _isDayFlexible = value == 0;
                          if (value != 0) {
                            _preferredWeekday = value;
                          }
                        });
                      },
              ),
              const Divider(),
            ],
            if (_intervalDays == 30 || _intervalDays == 90) ...[
              DropdownButtonFormField<int>(
                initialValue: _isDayFlexible ? 0 : _preferredDayOfMonth,
                decoration: const InputDecoration(
                  labelText: 'Preferred Day of Month',
                ),
                items: <DropdownMenuItem<int>>[
                  const DropdownMenuItem(value: 0, child: Text('Flexible')),
                  ...List.generate(
                    31,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('Day ${index + 1}'),
                    ),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _isDayFlexible = value == 0;
                          if (value != 0) {
                            _preferredDayOfMonth = value;
                          }
                        });
                      },
              ),
              const Divider(),
            ],
            if (_intervalDays == 365) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _preferredMonth,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: List.generate(
                        12,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text(
                            DateFormat.MMMM().format(DateTime(2026, index + 1)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _preferredMonth = value;
                                });
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _preferredDayOfMonth,
                      decoration: const InputDecoration(labelText: 'Day'),
                      items: List.generate(
                        31,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1}'),
                        ),
                      ),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _preferredDayOfMonth = value;
                                });
                              }
                            },
                    ),
                  ),
                ],
              ),
              const Divider(),
            ],
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time_outlined),
            title: const Text('Start Time'),
            subtitle: Text(
              MaterialLocalizations.of(context).formatTimeOfDay(_startTime),
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
                MaterialLocalizations.of(context).formatTimeOfDay(_endTime),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _isSaving ? null : _pickEndTime,
            ),
          if (_type == MomentType.recurring && _isDayFlexible) ...[
            const Divider(),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event_available_outlined),
              title: Text('Exact date chosen later'),
              subtitle: Text(
                'Sakan will keep the Moment in the Library without placing a fake date on the Calendar.',
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _minutesFromTime(TimeOfDay value) {
    return value.hour * 60 + value.minute;
  }

  TimeOfDay _timeFromMinutes(int minutes) {
    final safe = minutes.clamp(0, 1439).toInt();
    return TimeOfDay(hour: safe ~/ 60, minute: safe % 60);
  }

  String _frequencyLabel(int days) {
    return switch (days) {
      1 => 'Daily',
      7 => 'Weekly',
      14 => 'Every 2 weeks',
      30 => 'Monthly',
      90 => 'Every 3 months',
      365 => 'Yearly',
      _ => 'Every $days days',
    };
  }

  String _weekdayLabel(int weekday) {
    final monday = DateTime(2026, 1, 5);
    return DateFormat.EEEE().format(monday.add(Duration(days: weekday - 1)));
  }
}
