import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/care_action.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import 'reminder_form_screen.dart';
import '../../../shared/widgets/content/app_page_intro.dart';
import '../../../shared/widgets/controls/app_pill_segmented_control.dart';

enum _ReminderView { pending, completed }

class MyRemindersScreen extends StatefulWidget {
  const MyRemindersScreen({super.key});

  @override
  State<MyRemindersScreen> createState() => _MyRemindersScreenState();
}

class _MyRemindersScreenState extends State<MyRemindersScreen> {
  CurrentFamilyContext? _familyContext;

  Stream<List<CareAction>>? _remindersStream;

  _ReminderView _view = _ReminderView.pending;

  bool _isLoading = true;
  bool _isUpdating = false;

  String? _errorMessage;
  String? _lastNotificationSyncKey;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  void _syncReminderNotifications(List<CareAction> reminders) {
    final syncKey = reminders
        .map(
          (reminder) =>
              '${reminder.id}:'
              '${reminder.status.name}:'
              '${reminder.dueAt.millisecondsSinceEpoch}:'
              '${reminder.updatedAt.millisecondsSinceEpoch}',
        )
        .join('|');

    if (_lastNotificationSyncKey == syncKey) {
      return;
    }

    _lastNotificationSyncKey = syncKey;

    unawaited(
      AppDependencies.reminderNotificationService.syncAssignedReminders(
        reminders,
      ),
    );
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      final remindersStream = AppDependencies.careActionRepository
          .watchAssignedCareActions(
            familyId: familyContext.familyId,
            memberId: familyContext.userId,
          );

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _remindersStream = remindersStream;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load your reminders.';
      });
    }
  }

  List<CareAction> _visibleReminders(List<CareAction> reminders) {
    final visible = reminders.where((reminder) {
      return switch (_view) {
        _ReminderView.pending => !reminder.isFinished,
        _ReminderView.completed => reminder.isFinished,
      };
    }).toList();

    if (_view == _ReminderView.pending) {
      visible.sort((first, second) => first.dueAt.compareTo(second.dueAt));
    } else {
      visible.sort((first, second) {
        final firstDate = first.completedAt ?? first.updatedAt;

        final secondDate = second.completedAt ?? second.updatedAt;

        return secondDate.compareTo(firstDate);
      });
    }

    return visible;
  }

  Future<void> _openReminderForm({CareAction? reminder}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReminderFormScreen(initialAction: reminder),
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    _showMessage(reminder == null ? 'Reminder added.' : 'Reminder updated.');
  }

  Future<void> _toggleCompleted(CareAction reminder, bool completed) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final now = DateTime.now().toUtc();

      final updated = reminder.copyWith(
        status: completed
            ? CareActionStatus.completed
            : CareActionStatus.pending,
        evidenceType: completed
            ? EvidenceType.userConfirmed
            : reminder.source == CareActionSource.manual
            ? EvidenceType.manual
            : EvidenceType.scheduledOnly,
        completedAt: completed ? now : null,
        updatedAt: now,
      );

      await AppDependencies.careActionRepository.updateCareAction(updated);
      if (completed) {
        await AppDependencies.reminderNotificationService.cancelReminder(
          updated.id,
        );
      } else {
        await AppDependencies.reminderNotificationService.scheduleReminder(
          updated,
          requestPermission: false,
        );
      }

      if (!mounted) return;

      _showMessage(
        completed
            ? 'Reminder completed.'
            : 'Reminder moved back '
                  'to Pending.',
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'We could not update '
        'this reminder.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _deleteReminder(CareAction reminder) async {
    if (_isUpdating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete reminder?'),
          content: Text('Delete "${reminder.title}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
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
      _isUpdating = true;
    });

    try {
      await AppDependencies.careActionRepository.deleteCareAction(
        familyId: reminder.familyId,
        actionId: reminder.id,
      );

      await AppDependencies.reminderNotificationService.cancelReminder(
        reminder.id,
      );

      if (!mounted) return;

      _showMessage('Reminder deleted.');
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'We could not delete '
        'this reminder.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Scaffold _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Reminders')),
      body: SafeArea(
        child: AppErrorState(message: message, onRetry: _loadReminders),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading your reminders…'),
        ),
      );
    }

    if (_familyContext == null || _remindersStream == null) {
      return _errorScaffold(
        _errorMessage ??
            'Your reminders '
                'are unavailable.',
      );
    }

    return StreamBuilder<List<CareAction>>(
      stream: _remindersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorScaffold(
            'We could not load '
            'your reminders.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(message: 'Loading your reminders…'),
            ),
          );
        }

        final allReminders = snapshot.data ?? <CareAction>[];
        _syncReminderNotifications(allReminders);

        final visibleReminders = _visibleReminders(allReminders);

        final pendingCount = allReminders
            .where((item) => !item.isFinished)
            .length;

        final completedCount = allReminders
            .where((item) => item.isFinished)
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Reminders'),
            actions: [
              IconButton(
                tooltip: 'Add Reminder',
                onPressed: _isUpdating
                    ? null
                    : () {
                        _openReminderForm();
                      },
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                104,
              ),
              children: [
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),

                      const SizedBox(width: AppSpacing.md),

                      Expanded(
                        child: const AppPageIntro(
                          title: 'Your personal to-do list',
                          description:
                              'Keep manual reminders and Sakan suggestions you '
                              'approve in one place.',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                AppPillSegmentedControl<_ReminderView>(
                  segments: [
                    AppPillSegment(
                      value: _ReminderView.pending,
                      label: 'Pending ($pendingCount)',
                    ),
                    AppPillSegment(
                      value: _ReminderView.completed,
                      label: 'Completed ($completedCount)',
                    ),
                  ],
                  selectedValue: _view,
                  enabled: !_isUpdating,
                  onChanged: (value) {
                    setState(() {
                      _view = value;
                    });
                  },
                ),

                const SizedBox(height: AppSpacing.xl),

                if (visibleReminders.isEmpty)
                  _EmptyReminderState(
                    view: _view,
                    onAddReminder: () {
                      _openReminderForm();
                    },
                  )
                else
                  ...visibleReminders.map(
                    (reminder) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _ReminderCard(
                        reminder: reminder,
                        isDisabled: _isUpdating,
                        onCompletedChanged: (completed) {
                          _toggleCompleted(reminder, completed);
                        },
                        onEdit: () {
                          _openReminderForm(reminder: reminder);
                        },
                        onDelete: () {
                          _deleteReminder(reminder);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyReminderState extends StatelessWidget {
  const _EmptyReminderState({required this.view, required this.onAddReminder});

  final _ReminderView view;
  final VoidCallback onAddReminder;

  @override
  Widget build(BuildContext context) {
    final showingPending = view == _ReminderView.pending;

    return AppCard(
      child: Column(
        children: [
          Icon(
            showingPending ? Icons.task_alt_outlined : Icons.history_rounded,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            showingPending ? 'Nothing pending' : 'No completed reminders yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            showingPending
                ? 'Add a personal reminder or '
                      'approve a suggestion from '
                      'another Sakan feature.'
                : 'Completed reminders will '
                      'appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          if (showingPending) ...[
            const SizedBox(height: AppSpacing.xl),

            AppPrimaryButton(
              label: 'Add Reminder',
              icon: Icons.add_task_rounded,
              onPressed: onAddReminder,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.isDisabled,
    required this.onCompletedChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final CareAction reminder;
  final bool isDisabled;

  final ValueChanged<bool> onCompletedChanged;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final completed = reminder.isFinished;

    final overdue = reminder.isOverdueAt(DateTime.now());

    final note = reminder.reason.trim();

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Checkbox(
              value: completed,
              onChanged: isDisabled
                  ? null
                  : (value) {
                      onCompletedChanged(value ?? false);
                    },
            ),
          ),

          const SizedBox(width: AppSpacing.xs),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),

                if (note.isNotEmpty) ...[
                  const SizedBox(height: 5),

                  Text(
                    note,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],

                const SizedBox(height: AppSpacing.sm),

                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 6,
                  children: [
                    _ReminderChip(
                      icon: overdue
                          ? Icons.warning_amber_rounded
                          : Icons.schedule_outlined,
                      label: overdue
                          ? 'Overdue · '
                                '${DateFormat('d MMM · h:mm a').format(reminder.dueAt.toLocal())}'
                          : DateFormat(
                              'EEE, d MMM · h:mm a',
                            ).format(reminder.dueAt.toLocal()),
                      isError: overdue,
                    ),

                    _ReminderChip(
                      icon: _sourceIcon(reminder.source),
                      label: _sourceLabel(reminder.source),
                    ),
                  ],
                ),
              ],
            ),
          ),

          PopupMenuButton<String>(
            enabled: !isDisabled,
            tooltip: 'Reminder options',
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              }

              if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _ReminderChip extends StatelessWidget {
  const _ReminderChip({
    required this.icon,
    required this.label,
    this.isError = false,
  });

  final IconData icon;
  final String label;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _sourceLabel(CareActionSource source) {
  return switch (source) {
    CareActionSource.manual => 'Manual',
    CareActionSource.calendar => 'Calendar',
    CareActionSource.digitalTwin => 'Digital Twin',
    CareActionSource.schedule => 'Schedule',
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
