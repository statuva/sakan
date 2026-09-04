import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_memory.dart';
import '../../../../shared/models/family_moment.dart';
import '../../../../shared/models/model_enums.dart';
import '../../../../shared/models/moment_instance.dart';
import 'calendar_moment_style.dart';
import 'calendar_palette.dart';

class CalendarMomentDetailsSheet extends StatelessWidget {
  const CalendarMomentDetailsSheet({
    required this.moment,
    required this.instance,
    required this.memory,
    required this.currentUserId,
    required this.canEditDefinition,
    required this.occurrenceLabel,
    this.primaryActionLabel,
    this.primaryActionIcon,
    this.onPrimaryAction,
    this.primaryActionHint,
    this.onViewSummary,
    this.onEditMoment,
    this.onAddMemory,
    this.onViewMemory,
    this.onEditMemory,
    super.key,
  });

  /// Calendar projection of the concrete occurrence.
  final FamilyMoment moment;
  final MomentInstance instance;
  final FamilyMemory? memory;
  final String occurrenceLabel;

  final String currentUserId;
  final bool canEditDefinition;

  final String? primaryActionLabel;
  final IconData? primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final String? primaryActionHint;

  final VoidCallback? onViewSummary;
  final VoidCallback? onEditMoment;
  final VoidCallback? onAddMemory;
  final VoidCallback? onViewMemory;
  final VoidCallback? onEditMemory;

  bool get _isCompleted {
    return instance.status == MomentInstanceStatus.completed;
  }

  @override
  Widget build(BuildContext context) {
    final scheduledStart = instance.scheduledStartAt.toLocal();
    final scheduledEnd = instance.scheduledEndAt?.toLocal();
    final actualStart = instance.actualStartAt?.toLocal();
    final actualEnd = instance.actualEndAt?.toLocal();

    final style = calendarMomentStyle(moment, currentUserId: currentUserId);

    final status = calendarOccurrenceStatusStyle(occurrenceLabel);

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moment.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: CalendarPalette.ink),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'One concrete family occurrence',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: CalendarPalette.inkSoft,
                        ),
                      ),
                    ],
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
              title: 'Planned Date',
              value: DateFormat('EEEE, d MMMM y').format(scheduledStart),
            ),

            _DetailRow(
              icon: Icons.access_time_outlined,
              title: 'Planned Time',
              value: scheduledEnd == null
                  ? DateFormat('h:mm a').format(scheduledStart)
                  : '${DateFormat('h:mm a').format(scheduledStart)}–'
                        '${DateFormat('h:mm a').format(scheduledEnd)}',
            ),

            if (actualStart != null)
              _DetailRow(
                icon: Icons.play_circle_outline_rounded,
                title: 'Actual Start',
                value: DateFormat('EEEE, d MMM y · h:mm a').format(actualStart),
              ),

            if (actualEnd != null)
              _DetailRow(
                icon: Icons.stop_circle_outlined,
                title: 'Actual End',
                value: DateFormat('EEEE, d MMM y · h:mm a').format(actualEnd),
              ),

            if (instance.actualDurationMinutes != null)
              _DetailRow(
                icon: Icons.timer_outlined,
                title: 'Recorded Duration',
                value: _durationLabel(instance.actualDurationMinutes!),
              ),

            _DetailRow(
              icon: Icons.repeat_rounded,
              title: 'Definition',
              value: moment.type == MomentType.recurring
                  ? 'Recurring every '
                        '${moment.expectedIntervalDays ?? 7} days'
                  : 'One-time',
            ),

            _DetailRow(icon: style.icon, title: 'Category', value: style.label),

            _DetailRow(
              icon: Icons.group_outlined,
              title: 'Participation',
              value:
                  '${instance.allRecordedParticipantIds.length} recorded · '
                  '${instance.expectedParticipantIds.length} expected',
            ),

            if (_isCompleted)
              _DetailRow(
                icon: Icons.verified_outlined,
                title: 'Evidence Confidence',
                value: _confirmationLabel(instance.confirmationLevel),
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

            if (primaryActionLabel != null && onPrimaryAction != null) ...[
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: onPrimaryAction,
                icon: Icon(primaryActionIcon ?? Icons.arrow_forward_rounded),
                label: Text(primaryActionLabel!),
              ),
            ],

            if (primaryActionHint != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                primaryActionHint!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: CalendarPalette.inkSoft),
              ),
            ],

            if (_isCompleted && onViewSummary != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: onViewSummary,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View Session Summary'),
              ),
            ],

            if (_isCompleted) ...[
              const SizedBox(height: AppSpacing.lg),
              _MemoryStatusCard(memory: memory),
            ],

            if (_isCompleted && memory == null && onAddMemory != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: onAddMemory,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Create Memory'),
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

            if (_isCompleted && memory != null && onEditMemory != null) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton.icon(
                onPressed: onEditMemory,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Edit Memory'),
              ),
            ],

            if (canEditDefinition && onEditMoment != null) ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton.icon(
                onPressed: onEditMoment,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Edit Moment Definition'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    }

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (remaining == 0) {
      return hours == 1 ? '1 hour' : '$hours hours';
    }

    return '$hours h $remaining min';
  }

  String _confirmationLabel(MomentConfirmationLevel level) {
    return switch (level) {
      MomentConfirmationLevel.low => 'Low evidence',
      MomentConfirmationLevel.medium => 'Medium evidence',
      MomentConfirmationLevel.high => 'High evidence',
    };
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
                  hasMemory
                      ? 'Memory saved for this occurrence'
                      : 'No Memory saved for this occurrence',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: CalendarPalette.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  hasMemory
                      ? 'The note is linked to this exact completed session.'
                      : 'Preserve a family note from this completed session.',
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
