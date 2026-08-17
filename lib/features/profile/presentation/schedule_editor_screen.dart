import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

class ScheduleEditorScreen extends StatefulWidget {
  const ScheduleEditorScreen({super.key});

  @override
  State<ScheduleEditorScreen> createState() =>
      _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState
    extends State<ScheduleEditorScreen> {
  final List<_ScheduleItem> _schedule = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSchedule,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: _schedule.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(
                    AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 72,
                      ),
                      const SizedBox(
                        height: AppSpacing.lg,
                      ),
                      Text(
                        'No unavailable times yet',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall,
                      ),
                      const SizedBox(
                        height: AppSpacing.sm,
                      ),
                      Text(
                        'Add recurring unavailable times such as work, school or university.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(
                  AppSpacing.lg,
                ),
                itemCount: _schedule.length,
                itemBuilder: (context, index) {
                  final item = _schedule[index];

                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppSpacing.md,
                    ),
                    child: AppCard(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.schedule),
                        ),
                        title: Text(item.title),
                        subtitle: Text(
                          '${item.day}\n${item.start} - ${item.end}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editSchedule(index);
                            } else {
                              setState(() {
                                _schedule.removeAt(index);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _addSchedule() async {
    final item = await showDialog<_ScheduleItem>(
      context: context,
      builder: (_) => const _ScheduleDialog(),
    );

    if (item == null) return;

    setState(() {
      _schedule.add(item);
    });
  }

  Future<void> _editSchedule(int index) async {
    final updated = await showDialog<_ScheduleItem>(
      context: context,
      builder: (_) => _ScheduleDialog(
        initial: _schedule[index],
      ),
    );

    if (updated == null) return;

    setState(() {
      _schedule[index] = updated;
    });
  }
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({
    this.initial,
  });

  final _ScheduleItem? initial;

  @override
  State<_ScheduleDialog> createState() =>
      _ScheduleDialogState();
}

class _ScheduleDialogState
    extends State<_ScheduleDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController
      _titleController;

  String _day = 'Monday';

  TimeOfDay _start =
      const TimeOfDay(hour: 8, minute: 0);

  TimeOfDay _end =
      const TimeOfDay(hour: 15, minute: 0);

  final _days = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.initial?.title ?? '',
    );

    if (widget.initial != null) {
      _day = widget.initial!.day;
      _start = widget.initial!.startTime;
      _end = widget.initial!.endTime;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _start,
    );

    if (picked == null) return;

    setState(() {
      _start = picked;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _end,
    );

    if (picked == null) return;

    setState(() {
      _end = picked;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(
      context,
      _ScheduleItem(
        title: _titleController.text.trim(),
        day: _day,
        startTime: _start,
        endTime: _end,
      ),
    );
  }

  String _format(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0
        ? 12
        : time.hourOfPeriod;

    final minute =
        time.minute.toString().padLeft(2, '0');

    final period =
        time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? 'Add Schedule'
            : 'Edit Schedule',
      ),
      content: SizedBox(
        width: 350,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              TextFormField(
                controller:
                    _titleController,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Activity',
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter a title';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: AppSpacing.md,
              ),

              DropdownButtonFormField(
                initialValue: _day,
                decoration:
                    const InputDecoration(
                  labelText: 'Day',
                ),
                items: _days
                    .map(
                      (day) =>
                          DropdownMenuItem(
                        value: day,
                        child: Text(day),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _day = value;
                  });
                },
              ),

              const SizedBox(
                height: AppSpacing.md,
              ),

              ListTile(
                contentPadding:
                    EdgeInsets.zero,
                title:
                    const Text('Start'),
                subtitle:
                    Text(_format(_start)),
                trailing:
                    const Icon(Icons.access_time),
                onTap: _pickStart,
              ),

              ListTile(
                contentPadding:
                    EdgeInsets.zero,
                title: const Text('End'),
                subtitle:
                    Text(_format(_end)),
                trailing:
                    const Icon(Icons.access_time),
                onTap: _pickEnd,
              ),

              const SizedBox(
                height: AppSpacing.lg,
              ),

              AppPrimaryButton(
                label: 'Save',
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleItem {
  const _ScheduleItem({
    required this.title,
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  final String title;
  final String day;

  final TimeOfDay startTime;
  final TimeOfDay endTime;

  String get start {
    final h = startTime.hourOfPeriod == 0
        ? 12
        : startTime.hourOfPeriod;

    final m = startTime.minute
        .toString()
        .padLeft(2, '0');

    final p = startTime.period ==
            DayPeriod.am
        ? 'AM'
        : 'PM';

    return '$h:$m $p';
  }

  String get end {
    final h = endTime.hourOfPeriod == 0
        ? 12
        : endTime.hourOfPeriod;

    final m =
        endTime.minute.toString().padLeft(2, '0');

    final p =
        endTime.period == DayPeriod.am
            ? 'AM'
            : 'PM';

    return '$h:$m $p';
  }
}

