import 'package:flutter/material.dart';

import '../calendar_types.dart';
import 'calendar_palette.dart';

class CalendarModeSelector extends StatelessWidget {
  const CalendarModeSelector({
    required this.selectedMode,
    required this.onChanged,
    super.key,
  });

  final CalendarViewMode selectedMode;
  final ValueChanged<CalendarViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CalendarPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: CalendarViewMode.values.map((mode) {
          final selected = mode == selectedMode;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? CalendarPalette.forestSoft
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  _label(mode),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? CalendarPalette.forestDark
                        : CalendarPalette.inkSoft,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(CalendarViewMode mode) {
    return switch (mode) {
      CalendarViewMode.month => 'Month',
      CalendarViewMode.week => 'Week',
      CalendarViewMode.agenda => 'Agenda',
    };
  }
}
