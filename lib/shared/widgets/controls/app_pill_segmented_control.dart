import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class AppPillSegment<T> {
  const AppPillSegment({required this.value, required this.label});

  final T value;
  final String label;
}

class AppPillSegmentedControl<T> extends StatelessWidget {
  const AppPillSegmentedControl({
    required this.segments,
    required this.selectedValue,
    required this.onChanged,
    this.enabled = true,
    this.backgroundColor,
    this.selectedColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    super.key,
  }) : assert(segments.length > 1);

  final List<AppPillSegment<T>> segments;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final bool enabled;

  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final resolvedBackground = backgroundColor ?? AppColors.linen;

    final resolvedSelected = selectedColor ?? AppColors.hubSand;

    final resolvedSelectedText = selectedTextColor ?? AppColors.textPrimary;

    final resolvedUnselectedText =
        unselectedTextColor ?? colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: segments
            .map((segment) {
              final selected = segment.value == selectedValue;

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  enabled: enabled,
                  label: segment.label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: enabled
                        ? () {
                            if (!selected) {
                              onChanged(segment.value);
                            }
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 170),
                      curve: Curves.easeOut,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? resolvedSelected : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        segment.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected
                              ? resolvedSelectedText
                              : resolvedUnselectedText,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}
