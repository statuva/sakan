import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/current_family_context.dart';
import 'package:sakan/shared/models/schedule_block.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';
import 'package:sakan/shared/widgets/feedback/app_error_state.dart';
import 'package:sakan/shared/widgets/feedback/app_loading_state.dart';

enum _ScheduleEntryType { oneTime, weekly }

class ScheduleEditorScreen extends StatefulWidget {
  const ScheduleEditorScreen({super.key});

  @override
  State<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends State<ScheduleEditorScreen> {
  CurrentFamilyContext? _familyContext;

  Stream<List<ScheduleBlock>>? _scheduleStream;

  Timer? _expiryTimer;

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadSchedule();

    // Causes one-time entries to disappear
    // shortly after their end time passes.
    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      final scheduleStream = AppDependencies.scheduleRepository
          .watchPersonalSchedule(
            familyId: familyContext.familyId,
            memberId: familyContext.userId,
          );

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _scheduleStream = scheduleStream;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load your schedule.';
      });
    }
  }

  Future<void> _openScheduleEditor({
    required List<ScheduleBlock> blocks,
    required _ScheduleEntryType preferredType,
    ScheduleBlock? existingBlock,
  }) async {
    final familyContext = _familyContext;

    if (familyContext == null || _isSaving) {
      return;
    }

    final draft = await showDialog<_ScheduleDraft>(
      context: context,
      builder: (dialogContext) {
        return _ScheduleDialog(
          existingBlock: existingBlock,
          preferredType: preferredType,
        );
      },
    );

    if (draft == null || !mounted) {
      return;
    }

    final conflictingBlock = _findConflictingBlock(
      draft: draft,
      blocks: blocks,
      ignoredBlockId: existingBlock?.id,
    );

    if (conflictingBlock != null) {
      _showMessage(
        '"${draft.label}" overlaps with '
        '"${conflictingBlock.label}".',
      );

      return;
    }

    final now = DateTime.now().toUtc();

    final isRecurring = draft.type == _ScheduleEntryType.weekly;

    final repeatDays = draft.repeatDays.toList()..sort();

    final block = ScheduleBlock(
      id:
          existingBlock?.id ??
          '${familyContext.userId}_'
              '${DateTime.now().microsecondsSinceEpoch}',
      familyId: familyContext.familyId,
      memberId: familyContext.userId,
      label: draft.label.trim(),
      repeatDays: isRecurring ? repeatDays : const <int>[],
      scheduledDate: isRecurring ? null : draft.scheduledDate,
      startMinutes: draft.startMinutes,
      endMinutes: draft.endMinutes,
      isRecurring: isRecurring,
      createdAt: existingBlock?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() {
      _isSaving = true;
    });

    try {
      if (existingBlock == null) {
        await AppDependencies.scheduleRepository.createScheduleBlock(block);
      } else {
        await AppDependencies.scheduleRepository.updateScheduleBlock(block);
      }

      if (!mounted) return;

      _showMessage(
        existingBlock == null
            ? 'Unavailable time added.'
            : 'Unavailable time updated.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error is ArgumentError
            ? error.message.toString()
            : 'We could not save this '
                  'unavailable time.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  ScheduleBlock? _findConflictingBlock({
    required _ScheduleDraft draft,
    required List<ScheduleBlock> blocks,
    String? ignoredBlockId,
  }) {
    for (final block in blocks) {
      if (block.id == ignoredBlockId) {
        continue;
      }

      if (block.isExpiredAt(DateTime.now())) {
        continue;
      }

      final timesOverlap =
          draft.startMinutes < block.endMinutes &&
          draft.endMinutes > block.startMinutes;

      if (!timesOverlap) {
        continue;
      }

      if (_datePatternsOverlap(draft, block)) {
        return block;
      }
    }

    return null;
  }

  bool _datePatternsOverlap(_ScheduleDraft draft, ScheduleBlock block) {
    final draftIsRecurring = draft.type == _ScheduleEntryType.weekly;

    if (draftIsRecurring && block.isRecurring) {
      return draft.repeatDays.any(block.repeatDays.contains);
    }

    if (!draftIsRecurring && !block.isRecurring) {
      final draftDate = draft.scheduledDate;

      final blockDate = block.scheduledDate;

      if (draftDate == null || blockDate == null) {
        return false;
      }

      return _sameDate(draftDate, blockDate);
    }

    if (!draftIsRecurring && block.isRecurring) {
      final draftDate = draft.scheduledDate;

      return draftDate != null && block.repeatDays.contains(draftDate.weekday);
    }

    final blockDate = block.scheduledDate;

    return blockDate != null && draft.repeatDays.contains(blockDate.weekday);
  }

  Future<void> _deleteScheduleBlock(ScheduleBlock block) async {
    if (_isSaving) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete unavailable time?'),
          content: Text(
            'Remove "${block.label}" '
            'from your schedule?',
          ),
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

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await AppDependencies.scheduleRepository.deleteScheduleBlock(
        familyId: block.familyId,
        memberId: block.memberId,
        blockId: block.id,
      );

      if (!mounted) return;

      _showMessage('Unavailable time deleted.');
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'We could not delete this '
        'unavailable time.',
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
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildScheduleSection({
    required String title,
    required String description,
    required String emptyMessage,
    required List<ScheduleBlock> blocks,
    required List<ScheduleBlock> allBlocks,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${blocks.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xs),

        Text(description, style: Theme.of(context).textTheme.bodyMedium),

        const SizedBox(height: AppSpacing.md),

        if (blocks.isEmpty)
          AppCard(
            child: Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ...blocks.map(
            (block) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _ScheduleBlockCard(
                block: block,
                isDisabled: _isSaving,
                onEdit: () {
                  _openScheduleEditor(
                    blocks: allBlocks,
                    preferredType: block.isRecurring
                        ? _ScheduleEntryType.weekly
                        : _ScheduleEntryType.oneTime,
                    existingBlock: block,
                  );
                },
                onDelete: () {
                  _deleteScheduleBlock(block);
                },
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading your schedule…'),
        ),
      );
    }

    if (_errorMessage != null || _scheduleStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Schedule')),
        body: SafeArea(
          child: AppErrorState(
            message:
                _errorMessage ??
                'Your schedule '
                    'is unavailable.',
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
            appBar: AppBar(title: const Text('My Schedule')),
            body: SafeArea(
              child: AppErrorState(
                message:
                    'We could not load '
                    'your schedule.',
                onRetry: _loadSchedule,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(message: 'Loading your schedule…'),
            ),
          );
        }

        final now = DateTime.now();

        final allBlocks = (snapshot.data ?? <ScheduleBlock>[])
            .where((block) => !block.isExpiredAt(now))
            .toList();

        final oneTimeBlocks =
            allBlocks.where((block) => !block.isRecurring).toList()
              ..sort((first, second) {
                final dateResult = (first.scheduledDate ?? DateTime(9999))
                    .compareTo(second.scheduledDate ?? DateTime(9999));

                if (dateResult != 0) {
                  return dateResult;
                }

                return first.startMinutes.compareTo(second.startMinutes);
              });

        final weeklyBlocks =
            allBlocks.where((block) => block.isRecurring).toList()
              ..sort((first, second) {
                final firstDay = first.repeatDays.isEmpty
                    ? 8
                    : first.repeatDays.first;

                final secondDay = second.repeatDays.isEmpty
                    ? 8
                    : second.repeatDays.first;

                final dayResult = firstDay.compareTo(secondDay);

                if (dayResult != 0) {
                  return dayResult;
                }

                return first.startMinutes.compareTo(second.startMinutes);
              });

        return Scaffold(
          appBar: AppBar(title: const Text('My Schedule')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                120,
              ),
              children: [
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.event_busy_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connected to Calendar',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'One-time appointments '
                              'and weekly routines '
                              'help Sakan find better '
                              'shared family times.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Other family members '
                              'can see only that you '
                              'are busy—not the '
                              'private label.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                Text(
                  'Add unavailable time',
                  style: Theme.of(context).textTheme.titleLarge,
                ),

                const SizedBox(height: AppSpacing.sm),

                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _isSaving
                            ? null
                            : () {
                                _openScheduleEditor(
                                  blocks: allBlocks,
                                  preferredType: _ScheduleEntryType.oneTime,
                                );
                              },
                        icon: const Icon(Icons.event_outlined),
                        label: const Text('One-time'),
                      ),
                    ),

                    const SizedBox(width: AppSpacing.sm),

                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _isSaving
                            ? null
                            : () {
                                _openScheduleEditor(
                                  blocks: allBlocks,
                                  preferredType: _ScheduleEntryType.weekly,
                                );
                              },
                        icon: const Icon(Icons.repeat_rounded),
                        label: const Text('Weekly'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),

                _buildScheduleSection(
                  title: 'One-time',
                  description:
                      'Appointments and temporary '
                      'busy periods. They disappear '
                      'after their end time.',
                  emptyMessage:
                      'No upcoming one-time '
                      'unavailable periods.',
                  blocks: oneTimeBlocks,
                  allBlocks: allBlocks,
                ),

                const SizedBox(height: AppSpacing.xxl),

                _buildScheduleSection(
                  title: 'Weekly routine',
                  description:
                      'School, university, work, '
                      'or other times that repeat '
                      'on selected weekdays.',
                  emptyMessage: 'No weekly routines added.',
                  blocks: weeklyBlocks,
                  allBlocks: allBlocks,
                ),
              ],
            ),
          ),
        );
      },
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
    final timeText =
        '${_formatMinutes(context, block.startMinutes)}'
        '–'
        '${_formatMinutes(context, block.endMinutes)}';

    final subtitle = block.isRecurring
        ? '${_formatRepeatDays(block.repeatDays)}\n'
              '$timeText\n'
              'Repeats weekly'
        : '${block.scheduledDate == null ? 'Date unavailable' : DateFormat('EEEE, d MMM y').format(block.scheduledDate!.toLocal())}\n'
              '$timeText\n'
              'Disappears after it ends';

    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          child: Icon(
            block.isRecurring ? Icons.repeat_rounded : Icons.event_outlined,
          ),
        ),
        title: Text(block.label),
        subtitle: Text(subtitle),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          enabled: !isDisabled,
          tooltip: 'Schedule options',
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
      ),
    );
  }
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({required this.preferredType, this.existingBlock});

  final _ScheduleEntryType preferredType;
  final ScheduleBlock? existingBlock;

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _labelController;

  late _ScheduleEntryType _type;

  late DateTime _scheduledDate;

  late Set<int> _repeatDays;

  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  String? _scheduleError;

  @override
  void initState() {
    super.initState();

    final block = widget.existingBlock;

    _labelController = TextEditingController(text: block?.label ?? '');

    _type = block == null
        ? widget.preferredType
        : block.isRecurring
        ? _ScheduleEntryType.weekly
        : _ScheduleEntryType.oneTime;

    _scheduledDate = _dateOnly(
      block?.scheduledDate?.toLocal() ?? DateTime.now(),
    );

    _repeatDays = block?.repeatDays.toSet() ?? <int>{};

    _startTime = TimeOfDay(
      hour: (block?.startMinutes ?? 480) ~/ 60,
      minute: (block?.startMinutes ?? 480) % 60,
    );

    _endTime = TimeOfDay(
      hour: (block?.endMinutes ?? 540) ~/ 60,
      minute: (block?.endMinutes ?? 540) % 60,
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = _dateOnly(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate.isBefore(today) ? today : _scheduledDate,
      firstDate: today,
      lastDate: DateTime(today.year + 3, 12, 31),
    );

    if (picked == null) return;

    setState(() {
      _scheduledDate = _dateOnly(picked);
      _scheduleError = null;
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );

    if (picked == null) return;

    setState(() {
      _startTime = picked;
      _scheduleError = null;
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
      _scheduleError = null;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final startMinutes = _startTime.hour * 60 + _startTime.minute;

    final endMinutes = _endTime.hour * 60 + _endTime.minute;

    if (endMinutes <= startMinutes) {
      setState(() {
        _scheduleError =
            'End time must be after '
            'the start time.';
      });

      return;
    }

    if (_type == _ScheduleEntryType.weekly && _repeatDays.isEmpty) {
      setState(() {
        _scheduleError =
            'Choose at least one '
            'repeat day.';
      });

      return;
    }

    if (_type == _ScheduleEntryType.oneTime) {
      final endDateTime = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        endMinutes ~/ 60,
        endMinutes % 60,
      );

      if (!endDateTime.isAfter(DateTime.now())) {
        setState(() {
          _scheduleError =
              'Choose a date and time '
              'that ends in the future.';
        });

        return;
      }
    }

    Navigator.of(context).pop(
      _ScheduleDraft(
        label: _labelController.text.trim(),
        type: _type,
        repeatDays: Set<int>.from(_repeatDays),
        scheduledDate: _type == _ScheduleEntryType.oneTime
            ? _scheduledDate
            : null,
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
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<_ScheduleEntryType>(
                  segments: const [
                    ButtonSegment<_ScheduleEntryType>(
                      value: _ScheduleEntryType.oneTime,
                      icon: Icon(Icons.event_outlined),
                      label: Text('One-time'),
                    ),
                    ButtonSegment<_ScheduleEntryType>(
                      value: _ScheduleEntryType.weekly,
                      icon: Icon(Icons.repeat_rounded),
                      label: Text('Weekly'),
                    ),
                  ],
                  selected: <_ScheduleEntryType>{_type},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _type = selection.first;
                      _scheduleError = null;
                    });
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                TextFormField(
                  controller: _labelController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    hintText: 'Doctor, School, Work…',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a schedule label.';
                    }

                    if (value.trim().length < 2) {
                      return 'The label is too short.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                if (_type == _ScheduleEntryType.oneTime) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Date'),
                    subtitle: Text(
                      DateFormat('EEEE, d MMMM y').format(_scheduledDate),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickDate,
                  ),

                  Text(
                    'This entry will stop '
                    'affecting your availability '
                    'after its end time.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  Text(
                    'Repeats on',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: List.generate(7, (index) {
                      final day = index + 1;

                      return FilterChip(
                        label: Text(_shortDayName(day)),
                        selected: _repeatDays.contains(day),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _repeatDays.add(day);
                            } else {
                              _repeatDays.remove(day);
                            }

                            _scheduleError = null;
                          });
                        },
                      );
                    }),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  Text(
                    'Choose every weekday when '
                    'this routine normally happens.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_outlined),
                  title: const Text('Starts'),
                  subtitle: Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatTimeOfDay(_startTime),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickStartTime,
                ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_filled),
                  title: const Text('Ends'),
                  subtitle: Text(
                    MaterialLocalizations.of(context).formatTimeOfDay(_endTime),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickEndTime,
                ),

                if (_scheduleError != null) ...[
                  const SizedBox(height: AppSpacing.sm),

                  Text(
                    _scheduleError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
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
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _ScheduleDraft {
  const _ScheduleDraft({
    required this.label,
    required this.type,
    required this.repeatDays,
    required this.scheduledDate,
    required this.startMinutes,
    required this.endMinutes,
  });

  final String label;

  final _ScheduleEntryType type;

  final Set<int> repeatDays;

  final DateTime? scheduledDate;

  final int startMinutes;
  final int endMinutes;
}

String _shortDayName(int day) {
  return switch (day) {
    1 => 'Mon',
    2 => 'Tue',
    3 => 'Wed',
    4 => 'Thu',
    5 => 'Fri',
    6 => 'Sat',
    7 => 'Sun',
    _ => '?',
  };
}

String _fullDayName(int day) {
  return switch (day) {
    1 => 'Monday',
    2 => 'Tuesday',
    3 => 'Wednesday',
    4 => 'Thursday',
    5 => 'Friday',
    6 => 'Saturday',
    7 => 'Sunday',
    _ => 'Unknown',
  };
}

String _formatRepeatDays(List<int> days) {
  final sortedDays = days.toSet().toList()..sort();

  if (sortedDays.length == 7) {
    return 'Every day';
  }

  if (_sameIntegerLists(sortedDays, const <int>[1, 2, 3, 4, 5])) {
    return 'Weekdays';
  }

  if (_sameIntegerLists(sortedDays, const <int>[6, 7])) {
    return 'Weekend';
  }

  return sortedDays.map(_fullDayName).join(', ');
}

bool _sameIntegerLists(List<int> first, List<int> second) {
  if (first.length != second.length) {
    return false;
  }

  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }

  return true;
}

String _formatMinutes(BuildContext context, int minutes) {
  return MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _sameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
