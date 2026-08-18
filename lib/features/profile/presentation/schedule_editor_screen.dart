import 'package:flutter/material.dart';

import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/shared/widgets/feedback/app_error_state.dart';
import 'package:sakan/shared/widgets/feedback/app_loading_state.dart';
import 'package:sakan/shared/models/schedule_block.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';
import 'package:sakan/shared/models/current_family_context.dart';

class ScheduleEditorScreen extends StatefulWidget {
  const ScheduleEditorScreen({super.key});

  @override
  State<ScheduleEditorScreen> createState() =>
      _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState
    extends State<ScheduleEditorScreen> {
  CurrentFamilyContext? _familyContext;
  Stream<List<ScheduleBlock>>? _scheduleStream;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext =
          await AppDependencies
              .currentFamilyService
              .load();

      final stream = AppDependencies.scheduleRepository
          .watchPersonalSchedule(
        familyId: familyContext.familyId,
        memberId: familyContext.userId,
      );

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _scheduleStream = stream;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'We could not load your schedule.';
      });
    }
  }

  Future<void> _openScheduleEditor({
    required List<ScheduleBlock> blocks,
    ScheduleBlock? existingBlock,
  }) async {
    final familyContext = _familyContext;

    if (familyContext == null ||
        _isSaving) {
      return;
    }

    final draft = await showDialog<_ScheduleDraft>(
      context: context,
      builder: (context) {
        return _ScheduleDialog(
          existingBlock: existingBlock,
        );
      },
    );

    if (draft == null || !mounted) {
      return;
    }

    final hasOverlap = _hasOverlap(
      draft: draft,
      blocks: blocks,
      ignoredBlockId: existingBlock?.id,
    );

    if (hasOverlap) {
      _showMessage(
        'This time overlaps with another '
        'unavailable schedule block.',
      );
      return;
    }

    final now = DateTime.now().toUtc();

    final block = ScheduleBlock(
      id: existingBlock?.id ??
          '${familyContext.userId}_'
              '${DateTime.now().microsecondsSinceEpoch}',
      familyId: familyContext.familyId,
      memberId: familyContext.userId,
      label: draft.label.trim(),
      dayOfWeek: draft.dayOfWeek,
      startMinutes: draft.startMinutes,
      endMinutes: draft.endMinutes,
      isRecurring: true,
      createdAt: existingBlock?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() {
      _isSaving = true;
    });

    try {
      if (existingBlock == null) {
        await AppDependencies.scheduleRepository
            .createScheduleBlock(block);
      } else {
        await AppDependencies.scheduleRepository
            .updateScheduleBlock(block);
      }

      if (!mounted) return;

      _showMessage(
        existingBlock == null
            ? 'Schedule added.'
            : 'Schedule updated.',
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'We could not save this schedule block.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  bool _hasOverlap({
    required _ScheduleDraft draft,
    required List<ScheduleBlock> blocks,
    String? ignoredBlockId,
  }) {
    return blocks.any((block) {
      if (block.id == ignoredBlockId) {
        return false;
      }

      if (block.dayOfWeek != draft.dayOfWeek) {
        return false;
      }

      return draft.startMinutes < block.endMinutes &&
          draft.endMinutes > block.startMinutes;
    });
  }

  Future<void> _deleteScheduleBlock(
    ScheduleBlock block,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete schedule block?',
          ),
          content: Text(
            'Remove "${block.label}" from '
            'your recurring schedule?',
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

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await AppDependencies.scheduleRepository
          .deleteScheduleBlock(
        familyId: block.familyId,
        memberId: block.memberId,
        blockId: block.id,
      );

      if (!mounted) return;

      _showMessage('Schedule deleted.');
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'We could not delete this schedule block.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(
            message: 'Loading your schedule…',
          ),
        ),
      );
    }

    if (_errorMessage != null ||
        _scheduleStream == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Schedule'),
        ),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ??
                'Your schedule is unavailable.',
            onRetry: _loadSchedule,
          ),
        ),
      );
    }

    return StreamBuilder<List<ScheduleBlock>>(
      stream: _scheduleStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('My Schedule'),
            ),
            body: SafeArea(
              child: AppErrorState(
                message:
                    'We could not load your schedule.',
                onRetry: _loadSchedule,
              ),
            ),
          );
        }

        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(
                message:
                    'Loading your schedule…',
              ),
            ),
          );
        }

        final blocks =
            snapshot.data ?? <ScheduleBlock>[];

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Schedule'),
          ),
          floatingActionButton:
              FloatingActionButton(
            onPressed: _isSaving
                ? null
                : () {
                    _openScheduleEditor(
                      blocks: blocks,
                    );
                  },
            child: const Icon(Icons.add_rounded),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(
                AppSpacing.xl,
              ),
              children: [
                AppCard(
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        color: Theme.of(context)
                            .colorScheme
                            .primary,
                      ),
                      const SizedBox(
                        width: AppSpacing.md,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connected to Calendar',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your unavailable times help '
                              'Sakan find shared family windows. '
                              'Other family members will be shown '
                              'only that you are busy, not the '
                              'private schedule label.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: AppSpacing.xl,
                ),

                if (blocks.isEmpty)
                  _EmptyScheduleState(
                    onAdd: _isSaving
                        ? null
                        : () {
                            _openScheduleEditor(
                              blocks: blocks,
                            );
                          },
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recurring unavailable times',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge,
                        ),
                      ),
                      Text(
                        '${blocks.length}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium,
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: AppSpacing.md,
                  ),

                  ...blocks.map(
                    (block) => Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: AppSpacing.md,
                      ),
                      child: _ScheduleBlockCard(
                        block: block,
                        isDisabled: _isSaving,
                        onEdit: () {
                          _openScheduleEditor(
                            blocks: blocks,
                            existingBlock: block,
                          );
                        },
                        onDelete: () {
                          _deleteScheduleBlock(
                            block,
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: AppSpacing.xxl,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyScheduleState extends StatelessWidget {
  const _EmptyScheduleState({
    required this.onAdd,
  });

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 72,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          Text(
            'No schedule added yet',
            style: Theme.of(context)
                .textTheme
                .headlineSmall,
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          Text(
            'Tell Sakan when you are usually busy '
            'so the Calendar can find better family '
            'times.',
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(
            height: AppSpacing.xl,
          ),
          AppPrimaryButton(
            label: 'Add Schedule',
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ScheduleBlockCard extends StatelessWidget {
  const _ScheduleBlockCard({
    required this.block,
    required this.isDisabled,
    required this.onEdit,
    required this.onDelete,
  });

  final ScheduleBlock block;
  final bool isDisabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          child: Text(
            _dayAbbreviation(block.dayOfWeek),
          ),
        ),
        title: Text(block.label),
        subtitle: Text(
          '${_dayName(block.dayOfWeek)}\n'
          '${_formatMinutes(context, block.startMinutes)}'
          '–${_formatMinutes(context, block.endMinutes)}'
          '\nRepeats weekly',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          enabled: !isDisabled,
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            } else if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) {
            return const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ];
          },
        ),
      ),
    );
  }

  static String _dayAbbreviation(int day) {
    return switch (day) {
      1 => 'M',
      2 => 'T',
      3 => 'W',
      4 => 'T',
      5 => 'F',
      6 => 'S',
      7 => 'S',
      _ => '?',
    };
  }

  static String _dayName(int day) {
    return switch (day) {
      1 => 'Monday',
      2 => 'Tuesday',
      3 => 'Wednesday',
      4 => 'Thursday',
      5 => 'Friday',
      6 => 'Saturday',
      7 => 'Sunday',
      _ => 'Unknown day',
    };
  }

  static String _formatMinutes(
    BuildContext context,
    int minutes,
  ) {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(
      TimeOfDay(
        hour: minutes ~/ 60,
        minute: minutes % 60,
      ),
    );
  }
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({
    this.existingBlock,
  });

  final ScheduleBlock? existingBlock;

  @override
  State<_ScheduleDialog> createState() =>
      _ScheduleDialogState();
}

class _ScheduleDialogState
    extends State<_ScheduleDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController
      _labelController;

  late int _dayOfWeek;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  String? _timeError;

  @override
  void initState() {
    super.initState();

    final block = widget.existingBlock;

    _labelController = TextEditingController(
      text: block?.label ?? '',
    );

    _dayOfWeek = block?.dayOfWeek ?? 1;

    _startTime = TimeOfDay(
      hour: (block?.startMinutes ?? 480) ~/ 60,
      minute: (block?.startMinutes ?? 480) % 60,
    );

    _endTime = TimeOfDay(
      hour: (block?.endMinutes ?? 900) ~/ 60,
      minute: (block?.endMinutes ?? 900) % 60,
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );

    if (picked == null) return;

    setState(() {
      _startTime = picked;
      _timeError = null;
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );

    if (picked == null) return;

    setState(() {
      _endTime = picked;
      _timeError = null;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final startMinutes =
        _startTime.hour * 60 + _startTime.minute;

    final endMinutes =
        _endTime.hour * 60 + _endTime.minute;

    if (endMinutes <= startMinutes) {
      setState(() {
        _timeError =
            'End time must be after start time.';
      });
      return;
    }

    Navigator.of(context).pop(
      _ScheduleDraft(
        label: _labelController.text.trim(),
        dayOfWeek: _dayOfWeek,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingBlock == null
            ? 'Add Unavailable Time'
            : 'Edit Unavailable Time',
      ),
      content: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _labelController,
                  textCapitalization:
                      TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    hintText:
                        'School, work, university…',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter a schedule label.';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: AppSpacing.md,
                ),

                DropdownButtonFormField<int>(
                  initialValue: _dayOfWeek,
                  decoration: const InputDecoration(
                    labelText: 'Day',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 1,
                      child: Text('Monday'),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text('Tuesday'),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text('Wednesday'),
                    ),
                    DropdownMenuItem(
                      value: 4,
                      child: Text('Thursday'),
                    ),
                    DropdownMenuItem(
                      value: 5,
                      child: Text('Friday'),
                    ),
                    DropdownMenuItem(
                      value: 6,
                      child: Text('Saturday'),
                    ),
                    DropdownMenuItem(
                      value: 7,
                      child: Text('Sunday'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _dayOfWeek = value;
                    });
                  },
                ),

                const SizedBox(
                  height: AppSpacing.md,
                ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.access_time_outlined,
                  ),
                  title: const Text('Starts'),
                  subtitle: Text(
                    MaterialLocalizations.of(context)
                        .formatTimeOfDay(_startTime),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: _pickStartTime,
                ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.access_time_filled,
                  ),
                  title: const Text('Ends'),
                  subtitle: Text(
                    MaterialLocalizations.of(context)
                        .formatTimeOfDay(_endTime),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: _pickEndTime,
                ),

                if (_timeError != null) ...[
                  const SizedBox(
                    height: AppSpacing.sm,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _timeError!,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .error,
                      ),
                    ),
                  ),
                ],

                const SizedBox(
                  height: AppSpacing.sm,
                ),

                Row(
                  children: [
                    Icon(
                      Icons.repeat_rounded,
                      size: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This unavailable time repeats '
                        'every week.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ScheduleDraft {
  const _ScheduleDraft({
    required this.label,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
  });

  final String label;
  final int dayOfWeek;
  final int startMinutes;
  final int endMinutes;
}
