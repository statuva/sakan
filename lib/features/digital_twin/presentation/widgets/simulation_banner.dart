import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../calendar/presentation/widgets/calendar_palette.dart';
import '../../domain/twin_simulation_result.dart';

class SimulationBanner extends StatelessWidget {
  const SimulationBanner({required this.simulation, super.key});

  final DigitalTwinSimulationResult simulation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: CalendarPalette.milestoneSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CalendarPalette.milestone.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: CalendarPalette.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.science_outlined,
                  size: 20,
                  color: CalendarPalette.milestone,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SIMULATION',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: CalendarPalette.milestone,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      simulation.scenarioTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: CalendarPalette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            simulation.scenarioSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: CalendarPalette.inkSoft),
          ),
          const SizedBox(height: 5),
          Text(
            'Based on the family data available at '
            '${DateFormat('d MMM · h:mm a').format(simulation.baseGeneratedAt.toLocal())}. '
            'Nothing in this view has been saved.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CalendarPalette.inkSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
