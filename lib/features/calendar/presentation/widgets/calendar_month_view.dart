import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../shared/models/family_moment.dart';
import 'calendar_moment_style.dart';
import 'calendar_palette.dart';

class CalendarMonthView extends StatelessWidget {
  const CalendarMonthView({
    required this.focusedDay,
    required this.selectedDay,
    required this.moments,
    required this.currentUserId,
    required this.onDaySelected,
    required this.onPageChanged,
    super.key,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final List<FamilyMoment> moments;
  final String currentUserId;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CalendarPalette.border),
      ),
      child: TableCalendar<FamilyMoment>(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(day, selectedDay),
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const <CalendarFormat, String>{
          CalendarFormat.month: 'Month',
        },
        startingDayOfWeek: StartingDayOfWeek.monday,
        daysOfWeekHeight: 30,
        rowHeight: 43,
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: CalendarPalette.inkSoft,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: CalendarPalette.inkSoft,
          ),
          titleTextStyle: TextStyle(
            color: CalendarPalette.ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          headerPadding: EdgeInsets.symmetric(vertical: 6),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: CalendarPalette.inkSoft,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: TextStyle(
            color: CalendarPalette.inkSoft,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          cellMargin: const EdgeInsets.all(4),
          defaultTextStyle: const TextStyle(
            color: CalendarPalette.ink,
            fontWeight: FontWeight.w500,
          ),
          weekendTextStyle: const TextStyle(
            color: CalendarPalette.ink,
            fontWeight: FontWeight.w500,
          ),
          selectedDecoration: const BoxDecoration(
            color: CalendarPalette.forestSoft,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: CalendarPalette.forestDark,
            fontWeight: FontWeight.w700,
          ),
          todayDecoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: CalendarPalette.forest, width: 1.4),
          ),
          todayTextStyle: const TextStyle(
            color: CalendarPalette.forestDark,
            fontWeight: FontWeight.w700,
          ),
          markersMaxCount: 3,
          markerDecoration: const BoxDecoration(
            color: CalendarPalette.forest,
            shape: BoxShape.circle,
          ),
        ),
        eventLoader: _momentsForDay,
        calendarBuilders: CalendarBuilders<FamilyMoment>(
          markerBuilder: (context, day, dayMoments) {
            if (dayMoments.isEmpty) return null;

            final styles = dayMoments
                .map(
                  (moment) =>
                      calendarMomentStyle(moment, currentUserId: currentUserId),
                )
                .toList();

            final uniqueColors = <Color>[];
            for (final style in styles) {
              if (!uniqueColors.contains(style.color)) {
                uniqueColors.add(style.color);
              }
            }

            return Positioned(
              bottom: 3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: uniqueColors.take(3).map((color) {
                  return Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1.2),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        onDaySelected: (selected, focused) {
          onDaySelected(selected);
        },
        onPageChanged: onPageChanged,
      ),
    );
  }

  List<FamilyMoment> _momentsForDay(DateTime day) {
    return moments.where((moment) {
      return isSameDay(moment.startAt.toLocal(), day);
    }).toList();
  }
}
