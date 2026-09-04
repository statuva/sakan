import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_moment.dart';
import 'calendar_moment_style.dart';
import 'calendar_palette.dart';

class CalendarDaySheet extends StatelessWidget {
  const CalendarDaySheet({
    required this.date,
    required this.moments,
    required this.occurrenceLabelsByMomentId,
    required this.currentUserId,
    required this.onMomentTap,
    super.key,
  });

  final DateTime date;
  final List<FamilyMoment> moments;
  final Map<String, String> occurrenceLabelsByMomentId;
  final String currentUserId;
  final ValueChanged<FamilyMoment> onMomentTap;

  @override
  Widget build(BuildContext context) {
    final sorted = List<FamilyMoment>.from(moments)
      ..sort((first, second) => first.startAt.compareTo(second.startAt));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEEE, d MMMM').format(date),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: CalendarPalette.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (sorted.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: CalendarPalette.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'No family moments on this day.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...sorted.map((moment) {
                final style = calendarMomentStyle(
                  moment,
                  currentUserId: currentUserId,
                );
                final statusLabel =
                    occurrenceLabelsByMomentId[moment.id] ?? 'Upcoming';
                final local = moment.startAt.toLocal();

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onMomentTap(moment),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: CalendarPalette.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: CalendarPalette.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: style.softColor,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              style.icon,
                              color: style.color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  moment.title,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: CalendarPalette.ink,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${DateFormat('h:mm a').format(local)} · ${moment.expectedParticipantIds.length} expected',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: CalendarPalette.inkSoft,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: style.softColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: style.color,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
