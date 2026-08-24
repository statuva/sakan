import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/care_action.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';

class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({this.initialAction, super.key});

  final CareAction? initialAction;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;

  late final TextEditingController _noteController;

  CurrentFamilyContext? _familyContext;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  bool get _isEditing {
    return widget.initialAction != null;
  }

  @override
  void initState() {
    super.initState();

    final initialAction = widget.initialAction;

    _titleController = TextEditingController(text: initialAction?.title ?? '');

    _noteController = TextEditingController(text: initialAction?.reason ?? '');

    final initialDueAt =
        initialAction?.dueAt.toLocal() ??
        DateTime.now().add(const Duration(hours: 1));

    _selectedDate = DateUtils.dateOnly(initialDueAt);

    _selectedTime = TimeOfDay.fromDateTime(initialDueAt);

    _loadContext();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      final initialAction = widget.initialAction;

      if (initialAction != null &&
          initialAction.assignedMemberId != familyContext.userId) {
        throw StateError(
          'You may edit only reminders '
          'assigned to you.',
        );
      }

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _readableError(
          error,
          'We could not prepare '
          'the reminder form.',
        );
      });
    }
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(today.year - 2, 1, 1),
      lastDate: DateTime(today.year + 5, 12, 31),
    );

    if (selected == null) return;

    setState(() {
      _selectedDate = DateUtils.dateOnly(selected);
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (selected == null) return;

    setState(() {
      _selectedTime = selected;
    });
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final familyContext = _familyContext;

    if (familyContext == null || _isSaving) {
      return;
    }

    final dueLocal = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final initialAction = widget.initialAction;

    if (initialAction == null && !dueLocal.isAfter(DateTime.now())) {
      setState(() {
        _errorMessage =
            'Choose a reminder time '
            'in the future.';
      });

      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now().toUtc();

      final action = CareAction(
        id:
            initialAction?.id ??
            'care_'
                '${familyContext.userId}_'
                '${DateTime.now().microsecondsSinceEpoch}',
        familyId: familyContext.familyId,
        momentId: initialAction?.momentId,
        title: _titleController.text.trim(),
        reason: _noteController.text.trim(),
        assignedMemberId: familyContext.userId,
        dueAt: dueLocal.toUtc(),
        status: initialAction?.status ?? CareActionStatus.pending,
        source: initialAction?.source ?? CareActionSource.manual,
        evidenceType: initialAction?.evidenceType ?? EvidenceType.manual,
        completedAt: initialAction?.completedAt,
        createdAt: initialAction?.createdAt ?? now,
        updatedAt: now,
      );

      if (initialAction == null) {
        await AppDependencies.careActionRepository.createCareAction(action);
      } else {
        await AppDependencies.careActionRepository.updateCareAction(action);
      }

      final notificationService = AppDependencies.reminderNotificationService;

      if (action.isFinished ||
          !action.dueAt.toLocal().isAfter(DateTime.now())) {
        await notificationService.cancelReminder(action.id);
      } else {
        await notificationService.scheduleReminder(
          action,
          requestPermission: true,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _readableError(
          error,
          'We could not save '
          'this reminder.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _readableError(Object error, String fallback) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? fallback;
    }

    if (error is StateError) {
      return error.message.toString();
    }

    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Preparing your reminder…'),
        ),
      );
    }

    if (_familyContext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reminder')),
        body: SafeArea(
          child: AppErrorState(
            message:
                _errorMessage ??
                'The reminder form '
                    'is unavailable.',
            onRetry: _loadContext,
          ),
        ),
      );
    }

    final source = widget.initialAction?.source ?? CareActionSource.manual;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Reminder' : 'Add Reminder'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                _isEditing
                    ? 'Update your reminder'
                    : 'Create a personal reminder',
                style: Theme.of(context).textTheme.headlineSmall,
              ),

              const SizedBox(height: AppSpacing.xs),

              Text(
                'Your reminder will appear '
                'only in your personal '
                'My Reminders list.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: AppSpacing.xl),

              TextFormField(
                controller: _titleController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reminder title',
                  hintText: 'Buy a gift, call Grandma…',
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a reminder title.';
                  }

                  if (value.trim().length < 2) {
                    return 'The title is too short.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _noteController,
                enabled: !_isSaving,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText:
                      'Add useful details '
                      'for this reminder.',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
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
                        DateFormat('EEEE, d MMMM y').format(_selectedDate),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _isSaving ? null : _pickDate,
                    ),

                    const Divider(),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time_outlined),
                      title: const Text('Time'),
                      subtitle: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatTimeOfDay(_selectedTime),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _isSaving ? null : _pickTime,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              AppCard(
                child: Row(
                  children: [
                    Icon(
                      _sourceIcon(source),
                      color: Theme.of(context).colorScheme.primary,
                    ),

                    const SizedBox(width: AppSpacing.md),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reminder source',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),

                          const SizedBox(height: 4),

                          Text(
                            _sourceLabel(source),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
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
                label: _isEditing ? 'Save Changes' : 'Add Reminder',
                icon: _isEditing ? Icons.save_outlined : Icons.add_task_rounded,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _saveReminder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _sourceLabel(CareActionSource source) {
  return switch (source) {
    CareActionSource.manual => 'Created manually',
    CareActionSource.calendar => 'Suggested by Calendar',
    CareActionSource.digitalTwin => 'Suggested by Digital Twin',
    CareActionSource.schedule => 'Suggested from your Schedule',
  };
}

IconData _sourceIcon(CareActionSource source) {
  return switch (source) {
    CareActionSource.manual => Icons.edit_note_outlined,
    CareActionSource.calendar => Icons.calendar_month_outlined,
    CareActionSource.digitalTwin => Icons.account_tree_outlined,
    CareActionSource.schedule => Icons.schedule_outlined,
  };
}
