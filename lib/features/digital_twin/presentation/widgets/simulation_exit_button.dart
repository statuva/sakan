import 'package:flutter/material.dart';

import '../../../calendar/presentation/widgets/calendar_palette.dart';

class SimulationExitButton extends StatelessWidget {
  const SimulationExitButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
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
