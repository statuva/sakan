import 'package:flutter/material.dart';

import '../../../../shared/widgets/controls/app_pill_segmented_control.dart';
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
    return AppPillSegmentedControl<CalendarViewMode>(
      segments: const [
        AppPillSegment(value: CalendarViewMode.month, label: 'Month'),
        AppPillSegment(value: CalendarViewMode.week, label: 'Week'),
        AppPillSegment(value: CalendarViewMode.agenda, label: 'Agenda'),
      ],
      selectedValue: selectedMode,
      onChanged: onChanged,
      backgroundColor: CalendarPalette.surfaceSoft,
      selectedColor: CalendarPalette.forestSoft,
      selectedTextColor: CalendarPalette.forestDark,
      unselectedTextColor: CalendarPalette.inkSoft,
    );
  }
}
