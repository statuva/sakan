import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/services/moment_schedule_resolver.dart';
import '../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';

class ScheduleMomentOccurrenceScreen extends StatefulWidget {
  const ScheduleMomentOccurrenceScreen({required this.moment, super.key});

  final FamilyMoment moment;

  @override
  State<ScheduleMomentOccurrenceScreen> createState() =>
      _ScheduleMomentOccurrenceScreenState();
}

class _ScheduleMomentOccurrenceScreenState
    extends State<ScheduleMomentOccurrenceScreen> {
  CurrentFamilyContext? _familyContext;

  DateTime _date = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );

  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 0);

  bool _hasEndTime = true;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final context = await AppDependencies.currentFamilyService.load();

      if (!context.isAdult) {
        throw StateError(
          'Only an adult or family admin can schedule a shared occurrence.',
        );
      }

      final startMinutes = widget.moment.resolvedPreferredStartMinutes;
      final endMinutes = widget.moment.resolvedPreferredEndMinutes;

      if (!mounted) return;

      setState(() {
        _familyContext = context;
        _startTime = _timeFromMinutes(startMinutes);
        _hasEndTime = endMinutes != null;

        if (endMinutes != null) {
          _endTime = _timeFromMinutes(endMinutes);
        }

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is StateError
            ? error.message.toString()
            : 'We could not prepare this occurrence.';
      });
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );

    if (selected != null) {
      setState(() {
        _date = DateUtils.dateOnly(selected);
      });
    }
  }

  Future<void> _pickStart() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );

    if (selected != null) {
      setState(() {
        _startTime = selected;
      });
    }
  }

  Future<void> _pickEnd() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );

    if (selected != null) {
      setState(() {
        _endTime = selected;
      });
    }
  }

  Future<void> _save() async {
    final context = _familyContext;

    if (context == null || _isSaving) {
      return;
    }

    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _startTime.hour,
      _startTime.minute,
    );

    if (start.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
      _showMessage('Choose a future date and time.');
      return;
    }

    final end = MomentScheduleResolver.endForStart(
      start: start,
      endMinutes: _hasEndTime ? _endTime.hour * 60 + _endTime.minute : null,
    );

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await AppDependencies.momentInstanceRepository.scheduleOccurrence(
        moment: widget.moment,
        scheduledStartAt: start.toUtc(),
        scheduledEndAt: end?.toUtc(),
        createdBy: context.userId,
        source: MomentInstanceSource.manual,
      );

      if (!mounted) return;
      Navigator.of(this.context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error is StateError
            ? error.message.toString()
            : 'We could not schedule this occurrence.';
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
          child: AppLoadingState(message: 'Preparing the occurrence…'),
        ),
      );
    }

    if (_familyContext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Schedule Moment')),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'Scheduling is unavailable.',
            onRetry: _load,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule Moment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              widget.moment.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Choose the exact date for this occurrence. The recurring definition stays flexible.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Date'),
                    subtitle: Text(DateFormat('EEEE, d MMMM y').format(_date)),
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
                    onTap: _isSaving ? null : _pickStart,
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
                      onTap: _isSaving ? null : _pickEnd,
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
              label: 'Schedule Occurrence',
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  TimeOfDay _timeFromMinutes(int minutes) {
    final safe = minutes.clamp(0, 1439).toInt();
    return TimeOfDay(hour: safe ~/ 60, minute: safe % 60);
  }
}
