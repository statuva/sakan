import 'package:flutter/material.dart';

import '../../../calendar/presentation/widgets/calendar_palette.dart';

class SimulationExitButton extends StatelessWidget {
  const SimulationExitButton({
    required this.onPressed,
    this.onCreate,
    this.hasRecordedConflict = false,
    this.isCreating = false,
    super.key,
  });

  final VoidCallback onPressed;
  final VoidCallback? onCreate;
  final bool hasRecordedConflict;
  final bool isCreating;

  @override
  Widget build(BuildContext context) {
    if (onCreate != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Material(
          color: CalendarPalette.surface,
          elevation: 7,
          shadowColor: Colors.black.withAlpha(45),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CalendarPalette.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isCreating ? null : onCreate,
                    icon: isCreating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            hasRecordedConflict
                                ? Icons.schedule_rounded
                                : Icons.add_task_rounded,
                          ),
                    label: Text(
                      isCreating
                          ? 'Opening…'
                          : hasRecordedConflict
                          ? 'Choose a clear time'
                          : 'Review & create Moment',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: CalendarPalette.ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: isCreating ? null : onPressed,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Exit simulation'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Exit simulation',
      child: Tooltip(
        message: 'Exit simulation',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: CalendarPalette.ink,
              elevation: 7,
              shadowColor: Colors.black.withAlpha(70),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: const SizedBox(
                  width: 58,
                  height: 58,
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: CalendarPalette.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: CalendarPalette.border),
              ),
              child: Text(
                'Exit simulation',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: CalendarPalette.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
