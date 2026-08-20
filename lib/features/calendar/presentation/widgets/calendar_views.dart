import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';

import 'calendar_visuals.dart';

class CalendarMonthView extends StatelessWidget {
  const CalendarMonthView({
    required this.focusedDay,
    required this.selectedDay,
    required this.moments,
    required this.onDaySelected,
    required this.onPageChanged,
    super.key,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final List<FamilyMoment> moments;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  List<FamilyMoment> _eventsForDay(DateTime day) {
    return moments
        .where((moment) => isSameDay(moment.startAt.toLocal(), day))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return TableCalendar<FamilyMoment>(
      firstDay: DateTime.utc(2024, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      startingDayOfWeek: StartingDayOfWeek.sunday,
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const <CalendarFormat, String>{
        CalendarFormat.month: 'Month',
      },
      headerVisible: false,
      rowHeight: 43,
      daysOfWeekHeight: 26,
      eventLoader: _eventsForDay,
      onDaySelected: onDaySelected,
      onPageChanged: onPageChanged,
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: true,
        outsideTextStyle: TextStyle(color: Color(0xFFB7AFA2), fontSize: 13),
        defaultTextStyle: TextStyle(
          color: CalendarPalette.ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        weekendTextStyle: TextStyle(
          color: CalendarPalette.ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        selectedTextStyle: TextStyle(
          color: CalendarPalette.forestDark,
          fontWeight: FontWeight.w700,
        ),
        todayTextStyle: TextStyle(
          color: CalendarPalette.forestDark,
          fontWeight: FontWeight.w700,
        ),
        selectedDecoration: BoxDecoration(
          color: CalendarPalette.forestSoft,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: CalendarPalette.forest, width: 1.5),
          ),
        ),
        markersMaxCount: 3,
        markerSize: 5,
        markerMargin: EdgeInsets.symmetric(horizontal: 1),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: CalendarPalette.inkSoft,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        weekendStyle: TextStyle(
          color: CalendarPalette.inkSoft,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
      calendarBuilders: CalendarBuilders<FamilyMoment>(
        markerBuilder: (context, day, dayMoments) {
          if (dayMoments.isEmpty) return null;

          final uniqueCategories = <MomentCategory>[];
          for (final moment in dayMoments) {
            if (!uniqueCategories.contains(moment.category)) {
              uniqueCategories.add(moment.category);
            }
          }

          return Positioned(
            bottom: 5,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: uniqueCategories.take(3).map((category) {
                return Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: categoryStyleForCategory(category).color,
                    shape: BoxShape.circle,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class CalendarWeekView extends StatelessWidget {
  const CalendarWeekView({
    required this.focusedDay,
    required this.moments,
    required this.onDaySelected,
    super.key,
  });

  final DateTime focusedDay;
  final List<FamilyMoment> moments;
  final ValueChanged<DateTime> onDaySelected;

  List<DateTime> _weekDays() {
    final sunday = focusedDay.subtract(Duration(days: focusedDay.weekday % 7));
    return List<DateTime>.generate(
      7,
      (index) => DateUtils.dateOnly(sunday.add(Duration(days: index))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _weekDays();

    return SizedBox(
      height: 136,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 4),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final isToday = DateUtils.isSameDay(day, DateTime.now());
          final dayMoments =
              moments
                  .where(
                    (moment) =>
                        DateUtils.isSameDay(moment.startAt.toLocal(), day),
                  )
                  .toList()
                ..sort((a, b) => a.startAt.compareTo(b.startAt));

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onDaySelected(day),
            child: Container(
              width: 98,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isToday
                    ? CalendarPalette.forestSoft
                    : CalendarPalette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isToday
                      ? CalendarPalette.forest
                      : CalendarPalette.ink.withAlpha(15),
                ),
                boxShadow: CalendarPalette.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        DateFormat('E').format(day).substring(0, 1),
                        style: const TextStyle(
                          color: CalendarPalette.inkSoft,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          color: isToday
                              ? CalendarPalette.forestDark
                              : CalendarPalette.ink,
                          fontSize: 13,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...dayMoments.take(3).map((moment) {
                    final style = categoryStyleForMoment(moment);
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
                        style: TextStyle(
                          color: style.textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                  if (dayMoments.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '+${dayMoments.length - 3} more',
                        style: const TextStyle(
                          color: CalendarPalette.inkSoft,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CalendarAgendaView extends StatelessWidget {
  const CalendarAgendaView({
    required this.moments,
    required this.onMomentTap,
    super.key,
  });

  final List<FamilyMoment> moments;
  final ValueChanged<FamilyMoment> onMomentTap;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final upcoming =
        moments
            .where(
              (moment) =>
                  !DateUtils.dateOnly(moment.startAt.toLocal()).isBefore(today),
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

    if (upcoming.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'Nothing upcoming in this view.',
            style: TextStyle(color: CalendarPalette.inkSoft),
          ),
        ),
      );
    }

    return Column(
      children: upcoming.map((moment) {
        final style = categoryStyleForMoment(moment);
        final start = moment.startAt.toLocal();
        final daysOut = DateUtils.dateOnly(start).difference(today).inDays;
        final whenLabel = switch (daysOut) {
          0 => 'Today',
          1 => 'Tomorrow',
          _ => 'In $daysOut days',
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Material(
            color: CalendarPalette.surface,
            borderRadius: BorderRadius.circular(18),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onMomentTap(moment),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: CalendarPalette.ink.withAlpha(15)),
                  boxShadow: CalendarPalette.softShadow,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: style.softColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(style.icon, color: style.textColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            moment.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: CalendarPalette.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$whenLabel · ${DateFormat('h:mm a').format(start)}',
                            style: const TextStyle(
                              color: CalendarPalette.inkSoft,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: CalendarPalette.inkSoft,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

Future<void> showCalendarDaySheet({
  required BuildContext context,
  required DateTime day,
  required List<FamilyMoment> moments,
  required ValueChanged<FamilyMoment> onMomentTap,
}) {
  final dayMoments =
      moments
          .where((moment) => DateUtils.isSameDay(moment.startAt.toLocal(), day))
          .toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));

  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: CalendarPalette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMMM d').format(day),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: CalendarPalette.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (dayMoments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No family moments on this day yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CalendarPalette.inkSoft),
                ),
              )
            else
              ...dayMoments.map((moment) {
                final style = categoryStyleForMoment(moment);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onMomentTap(moment);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CalendarPalette.surfaceSoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: style.softColor,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              style.icon,
                              color: style.textColor,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  moment.title,
                                  style: const TextStyle(
                                    color: CalendarPalette.ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${DateFormat('h:mm a').format(moment.startAt.toLocal())} · ${moment.expectedParticipantIds.length} expected',
                                  style: const TextStyle(
                                    color: CalendarPalette.inkSoft,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: CalendarPalette.inkSoft,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    },
  );
}
