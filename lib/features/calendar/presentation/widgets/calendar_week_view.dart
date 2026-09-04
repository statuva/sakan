import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_moment.dart';
import 'calendar_moment_style.dart';
import 'calendar_palette.dart';

class CalendarWeekView extends StatelessWidget {
  const CalendarWeekView({
    required this.referenceDay,
    required this.selectedDay,
    required this.moments,
    required this.currentUserId,
    required this.onSelectedDay,
    required this.onPreviousWeek,
    required this.onNextWeek,
    super.key,
  });

  final DateTime referenceDay;
  final DateTime selectedDay;
  final List<FamilyMoment> moments;
  final String currentUserId;
  final ValueChanged<DateTime> onSelectedDay;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  @override
  Widget build(BuildContext context) {
    final days = _weekDays(referenceDay);
    final first = days.first;
    final last = days.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous week',
              onPressed: onPreviousWeek,
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: CalendarPalette.inkSoft,
              ),
            ),
            Expanded(
              child: Text(
                _rangeLabel(first, last),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: CalendarPalette.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next week',
              onPressed: onNextWeek,
              icon: const Icon(
                Icons.chevron_right_rounded,
                color: CalendarPalette.inkSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = days[index];
              final selected = isSameDay(day, selectedDay);
              final today = isSameDay(day, DateTime.now());
              final dayMoments = _momentsForDay(day);
              final visible = dayMoments.take(3).toList();
              final overflow = dayMoments.length - visible.length;

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onSelectedDay(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  width: 102,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: selected
                        ? CalendarPalette.forestSoft
                        : CalendarPalette.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: today
                          ? CalendarPalette.forest
                          : CalendarPalette.border,
                      width: today ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('E').format(day).toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: CalendarPalette.inkSoft,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            '${day.day}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: selected || today
                                      ? CalendarPalette.forestDark
                                      : CalendarPalette.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...visible.map((moment) {
                        final style = calendarMomentStyle(
                          moment,
                          currentUserId: currentUserId,
                        );

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: style.softColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            moment.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: style.color,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        );
                      }),
                      if (overflow > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '+$overflow more',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: CalendarPalette.inkSoft),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<DateTime> _weekDays(DateTime reference) {
    final date = DateUtils.dateOnly(reference);
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return List<DateTime>.generate(
      7,
      (index) => monday.add(Duration(days: index)),
    );
  }

  List<FamilyMoment> _momentsForDay(DateTime day) {
    return moments.where((moment) {
        return isSameDay(moment.startAt.toLocal(), day);
      }).toList()
      ..sort((first, second) => first.startAt.compareTo(second.startAt));
  }

  String _rangeLabel(DateTime first, DateTime last) {
    if (first.month == last.month) {
      return '${first.day}–${last.day} ${DateFormat('MMMM').format(last)}';
    }

    return '${DateFormat('d MMM').format(first)}–${DateFormat('d MMM').format(last)}';
  }
}
