import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/care_action.dart';
import '../../../../shared/widgets/cards/app_card.dart';

class HomeRemindersCard extends StatelessWidget {
  const HomeRemindersCard({
    required this.reminders,
    required this.now,
    required this.onOpen,
    super.key,
  });

  final List<CareAction> reminders;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final pending = reminders.where((item) => !item.isFinished).toList()
      ..sort((first, second) => first.dueAt.compareTo(second.dueAt));

    final visible = pending.take(3).toList(growable: false);

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(24),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Reminders',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      pending.isEmpty
                          ? 'Nothing pending'
                          : '${pending.length} pending',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (visible.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.linen.withAlpha(120),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'You have no pending personal reminders.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...visible.indexed.map((entry) {
              final index = entry.$1;
              final reminder = entry.$2;

              return Column(
                children: [
                  _ReminderRow(reminder: reminder, now: now),
                  if (index != visible.length - 1)
                    const Divider(height: AppSpacing.lg),
                ],
              );
            }),
          if (pending.length > visible.length) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '+${pending.length - visible.length} more',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.reminder, required this.now});

  final CareAction reminder;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final overdue = reminder.isOverdueAt(now);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            overdue
                ? Icons.error_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: overdue ? AppColors.error : AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reminder.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _dueLabel(reminder.dueAt, now),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: overdue ? AppColors.error : AppColors.textSecondary,
                  fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _dueLabel(DateTime dueAt, DateTime reference) {
    final due = dueAt.toLocal();
    final nowLocal = reference.toLocal();
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final difference = dueDay.difference(today).inDays;

    if (due.isBefore(nowLocal)) {
      return 'Overdue · ${DateFormat('d MMM, h:mm a').format(due)}';
    }

    if (difference == 0) {
      return 'Today · ${DateFormat('h:mm a').format(due)}';
    }

    if (difference == 1) {
      return 'Tomorrow · ${DateFormat('h:mm a').format(due)}';
    }

    return DateFormat('d MMM · h:mm a').format(due);
  }
}
