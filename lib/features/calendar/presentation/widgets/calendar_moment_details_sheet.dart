import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_memory.dart';
import '../../../../shared/models/family_moment.dart';
import '../../../../shared/models/model_enums.dart';
import '../../../../shared/models/rhythm_record.dart';
import 'calendar_moment_style.dart';
import 'calendar_palette.dart';

class CalendarMomentDetailsSheet extends StatelessWidget {
  const CalendarMomentDetailsSheet({
    required this.moment,
    required this.rhythm,
    required this.memory,
    required this.currentUserId,
    required this.canEdit,
    required this.onEditMoment,
    this.onAddMemory,
    this.onViewMemory,
    this.onEditMemory,
    super.key,
  });

  final FamilyMoment moment;
  final RhythmRecord? rhythm;
  final FamilyMemory? memory;

  final String currentUserId;
  final bool canEdit;

  final VoidCallback onEditMoment;
  final VoidCallback? onAddMemory;
  final VoidCallback? onViewMemory;
  final VoidCallback? onEditMemory;

  bool get _isCompleted => moment.status == MomentStatus.completed;

  @override
  Widget build(BuildContext context) {
    final localStart = moment.startAt.toLocal();

    final localEnd = moment.endAt?.toLocal();

    final style = calendarMomentStyle(moment, currentUserId: currentUserId);

    final status = calendarStatusStyle(moment: moment, rhythm: rhythm);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: style.softColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(style.icon, color: style.color, size: 21),
                ),

                const SizedBox(width: AppSpacing.md),

                Expanded(
                  child: Text(
                    moment.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: CalendarPalette.ink,
                    ),
                  ),
                ),

                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status.softColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            _DetailRow(
              icon: Icons.calendar_today_outlined,
              title: 'Date',
              value: DateFormat('EEEE, d MMMM y').format(localStart),
            ),

            _DetailRow(
              icon: Icons.access_time_outlined,
              title: 'Time',
              value: localEnd == null
                  ? DateFormat('h:mm a').format(localStart)
                  : '${DateFormat('h:mm a').format(localStart)}'
                        '–'
                        '${DateFormat('h:mm a').format(localEnd)}',
            ),

            _DetailRow(
              icon: Icons.repeat_rounded,
              title: 'Type',
              value: moment.type == MomentType.recurring
                  ? 'Recurring every '
                        '${moment.expectedIntervalDays ?? rhythm?.expectedIntervalDays ?? 7} days'
                  : 'One-time',
            ),

            _DetailRow(icon: style.icon, title: 'Category', value: style.label),

            _DetailRow(
              icon: Icons.group_outlined,
              title: 'Expected Participants',
              value: '${moment.expectedParticipantIds.length}',
            ),

            _DetailRow(
              icon: Icons.priority_high_rounded,
              title: 'Importance',
              value: '${moment.importanceLevel}/5',
            ),

            if (moment.location?.trim().isNotEmpty == true)
              _DetailRow(
                icon: Icons.location_on_outlined,
                title: 'Location',
                value: moment.location!,
              ),

            if (moment.notes?.trim().isNotEmpty == true)
              _DetailRow(
                icon: Icons.notes_outlined,
                title: 'Notes',
                value: moment.notes!,
              ),

            if (_isCompleted) ...[
              const SizedBox(height: AppSpacing.sm),

              _MemoryStatusCard(memory: memory),

              const SizedBox(height: AppSpacing.lg),
            ],

            if (canEdit)
              FilledButton.icon(
                onPressed: onEditMoment,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Moment'),
              ),

            if (_isCompleted &&
                memory == null &&
                canEdit &&
                onAddMemory != null) ...[
              const SizedBox(height: AppSpacing.sm),

              OutlinedButton.icon(
                onPressed: onAddMemory,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Add Memory'),
              ),
            ],

            if (_isCompleted && memory != null && onViewMemory != null) ...[
              const SizedBox(height: AppSpacing.sm),

              OutlinedButton.icon(
                onPressed: onViewMemory,
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('View Memory'),
              ),
            ],

            if (_isCompleted &&
                memory != null &&
                canEdit &&
                onEditMemory != null) ...[
              const SizedBox(height: AppSpacing.xs),

              TextButton.icon(
                onPressed: onEditMemory,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Edit Memory'),
              ),
            ],

            if (!canEdit) ...[
              const SizedBox(height: AppSpacing.sm),

              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemoryStatusCard extends StatelessWidget {
  const _MemoryStatusCard({required this.memory});

  final FamilyMemory? memory;

  @override
  Widget build(BuildContext context) {
    final hasMemory = memory != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: hasMemory
            ? CalendarPalette.forestSoft
            : CalendarPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasMemory
              ? CalendarPalette.forest.withAlpha(70)
              : CalendarPalette.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasMemory
                ? Icons.auto_stories_outlined
                : Icons.bookmark_add_outlined,
            color: hasMemory
                ? CalendarPalette.forestDark
                : CalendarPalette.inkSoft,
          ),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasMemory ? 'Memory saved' : 'No Memory saved yet',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: CalendarPalette.ink),
                ),

                const SizedBox(height: 4),

                Text(
                  hasMemory
                      ? 'A family note has been '
                            'preserved for this '
                            'completed Moment.'
                      : 'Preserve a family note '
                            'after this completed '
                            'Moment.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CalendarPalette.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: CalendarPalette.forest),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: CalendarPalette.inkSoft,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: CalendarPalette.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
