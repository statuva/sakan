import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_moment.dart';
import '../../../calendar/presentation/widgets/calendar_palette.dart';
import '../../domain/twin_simulation_result.dart';
import '../digital_twin_visuals.dart';

class SimulatedMomentPatternCard extends StatelessWidget {
  const SimulatedMomentPatternCard({
    required this.moment,
    required this.pattern,
    required this.participantNames,
    required this.onTap,
    super.key,
  });

  final FamilyMoment moment;
  final SimulatedMomentPattern pattern;
  final List<String> participantNames;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currentVisual = twinRhythmVisual(pattern.currentStatus);
    final projectedVisual = twinRhythmVisual(pattern.projectedStatus);

    return Material(
      color: CalendarPalette.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: CalendarPalette.milestone, width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: CalendarPalette.milestoneSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      twinCategoryIcon(moment.category),
                      size: 21,
                      color: CalendarPalette.milestone,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moment.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: CalendarPalette.ink,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pattern.isHypothetical
                              ? 'Hypothetical new Moment'
                              : pattern.direction.label,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: CalendarPalette.milestone,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: CalendarPalette.milestoneSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'SIMULATED',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: CalendarPalette.milestone,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: CalendarPalette.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatusColumn(
                        eyebrow: 'CURRENT',
                        label: pattern.isHypothetical
                            ? 'Not tracked'
                            : currentVisual.label,
                        color: pattern.isHypothetical
                            ? CalendarPalette.inkSoft
                            : currentVisual.color,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: CalendarPalette.inkSoft,
                      size: 20,
                    ),
                    Expanded(
                      child: _StatusColumn(
                        eyebrow: 'PROJECTED',
                        label: projectedVisual.label,
                        color: projectedVisual.color,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                pattern.summary,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CalendarPalette.inkSoft,
                  height: 1.42,
                ),
              ),
              if (pattern.changes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ...pattern.changes
                    .take(2)
                    .map(
                      (change) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.change_circle_outlined,
                              size: 16,
                              color: CalendarPalette.milestone,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                change,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: CalendarPalette.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.group_outlined,
                    size: 17,
                    color: CalendarPalette.inkSoft,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      participantNames.isEmpty
                          ? 'No participants linked'
                          : _participantLine(participantNames),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CalendarPalette.inkSoft,
                      ),
                    ),
                  ),
                  Text(
                    twinConfidenceLabel(pattern.confidence),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: projectedVisual.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: CalendarPalette.inkSoft,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _participantLine(List<String> names) {
    if (names.length <= 4) {
      return names.join(' · ');
    }

    return '${names.take(4).join(' · ')} +${names.length - 4}';
  }
}

class _StatusColumn extends StatelessWidget {
  const _StatusColumn({
    required this.eyebrow,
    required this.label,
    required this.color,
    this.alignEnd = false,
  });

  final String eyebrow;
  final String label;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: CalendarPalette.inkSoft,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.35,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
