import 'package:flutter/material.dart';

import '../calendar_types.dart';

class CalendarFilterBar extends StatelessWidget {
  const CalendarFilterBar({
    required this.activeCategoryFilters,
    required this.mineOnly,
    required this.onCategoryChanged,
    required this.onMineChanged,
    super.key,
  });

  final Set<CalendarFilter> activeCategoryFilters;
  final bool mineOnly;
  final ValueChanged<Set<CalendarFilter>> onCategoryChanged;
  final ValueChanged<bool> onMineChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: calendarFilterDefinitions.map((definition) {
          final isMine = definition.filter == CalendarFilter.mine;
          final selected = isMine
              ? mineOnly
              : activeCategoryFilters.contains(definition.filter);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                if (isMine) {
                  onMineChanged(!mineOnly);
                  return;
                }

                final updated = Set<CalendarFilter>.from(activeCategoryFilters);

                if (updated.contains(definition.filter)) {
                  updated.remove(definition.filter);
                } else {
                  updated.add(definition.filter);
                }

                onCategoryChanged(updated);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? definition.softColor
                      : definition.softColor.withAlpha(105),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      definition.icon,
                      size: 16,
                      color: selected
                          ? definition.color
                          : definition.color.withAlpha(175),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      definition.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? definition.color
                            : definition.color.withAlpha(175),
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
