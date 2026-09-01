import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_insight_report.dart';
import '../../../../shared/models/family_moment.dart';
import '../../../../shared/models/member.dart';
import '../../../../shared/models/model_enums.dart';
import '../../../calendar/presentation/widgets/calendar_palette.dart';
import '../../domain/twin_simulation_result.dart';
import '../digital_twin_visuals.dart';

Future<void> showTwinSimulationMomentSheet({
  required BuildContext context,
  required FamilyInsightReport baseReport,
  required DigitalTwinSimulationResult simulation,
  required FamilyMoment moment,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.56,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) {
          return _SimulationMomentSheet(
            baseReport: baseReport,
            simulation: simulation,
            moment: moment,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

Future<void> showTwinSimulationMemberSheet({
  required BuildContext context,
  required FamilyInsightReport baseReport,
  required DigitalTwinSimulationResult simulation,
  required Member member,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.48,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return _SimulationMemberSheet(
            baseReport: baseReport,
            simulation: simulation,
            member: member,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _SimulationMomentSheet extends StatelessWidget {
  const _SimulationMomentSheet({
    required this.baseReport,
    required this.simulation,
    required this.moment,
    required this.scrollController,
  });

  final FamilyInsightReport baseReport;
  final DigitalTwinSimulationResult simulation;
  final FamilyMoment moment;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final pattern = simulation.patternForMoment(moment.id);
    final membersById = baseReport.snapshot.membersById;
    final participantNames =
        moment.expectedParticipantIds
            .map((id) => membersById[id]?.displayName)
            .whereType<String>()
            .toList()
          ..sort();

    if (pattern == null) {
      return _SheetSurface(
        title: moment.title,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [
            Text('This Moment is unchanged by the current simulation.'),
          ],
        ),
      );
    }

    final currentVisual = twinRhythmVisual(pattern.currentStatus);
    final projectedVisual = twinRhythmVisual(pattern.projectedStatus);
    final categoryVisual = twinCategoryVisual(moment.category);

    return _SheetSurface(
      title: moment.title,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _Chip(
                label: 'SIMULATED',
                color: CalendarPalette.milestone,
                background: CalendarPalette.milestoneSoft,
              ),
              _Chip(
                label: categoryVisual.label,
                color: categoryVisual.color,
                background: categoryVisual.background,
              ),
              _Chip(
                label: twinConfidenceLabel(pattern.confidence),
                color: CalendarPalette.inkSoft,
                background: CalendarPalette.surfaceSoft,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: CalendarPalette.surfaceSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatusBlock(
                    title: pattern.isHypothetical ? 'CURRENT' : 'CURRENT',
                    value: pattern.isHypothetical
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
                ),
                Expanded(
                  child: _StatusBlock(
                    title: 'PROJECTED',
                    value: projectedVisual.label,
                    color: projectedVisual.color,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('What this simulation suggests'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            pattern.summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: CalendarPalette.ink,
              height: 1.5,
            ),
          ),
          if (pattern.changes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const _SectionLabel('Changed in this scenario'),
            const SizedBox(height: AppSpacing.sm),
            ...pattern.changes.map(
              (change) => _BulletLine(
                icon: Icons.change_circle_outlined,
                text: change,
                color: CalendarPalette.milestone,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('Simulated participants'),
          const SizedBox(height: AppSpacing.sm),
          if (participantNames.isEmpty)
            const Text('No participants are connected in this projection.')
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: participantNames
                  .map(
                    (name) => Chip(
                      avatar: CircleAvatar(child: Text(_initial(name))),
                      label: Text(name),
                      side: BorderSide.none,
                    ),
                  )
                  .toList(growable: false),
            ),
          if (pattern.assumptions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const _SectionLabel('Assumptions'),
            const SizedBox(height: AppSpacing.sm),
            ...pattern.assumptions.map(
              (assumption) => _BulletLine(
                icon: Icons.info_outline_rounded,
                text: assumption,
                color: CalendarPalette.inkSoft,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: CalendarPalette.milestoneSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Nothing in this simulation has been saved. Exit simulation to '
              'return to the latest recorded Digital Twin.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CalendarPalette.inkSoft,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimulationMemberSheet extends StatelessWidget {
  const _SimulationMemberSheet({
    required this.baseReport,
    required this.simulation,
    required this.member,
    required this.scrollController,
  });

  final FamilyInsightReport baseReport;
  final DigitalTwinSimulationResult simulation;
  final Member member;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final realConnected = baseReport.snapshot.moments
        .where(
          (moment) =>
              moment.type == MomentType.recurring &&
              moment.expectedParticipantIds.contains(member.id),
        )
        .toList(growable: false);

    final simulatedConnected = simulation.simulatedMoments
        .where(
          (moment) =>
              moment.type == MomentType.recurring &&
              moment.expectedParticipantIds.contains(member.id),
        )
        .toList(growable: false);

    final realIds = realConnected.map((moment) => moment.id).toSet();
    final simulatedIds = simulatedConnected.map((moment) => moment.id).toSet();

    final added = simulatedConnected
        .where((moment) => !realIds.contains(moment.id))
        .toList(growable: false);

    final removed = realConnected
        .where((moment) => !simulatedIds.contains(moment.id))
        .toList(growable: false);

    final affected = simulatedConnected
        .where((moment) => simulation.changedMomentIds.contains(moment.id))
        .toList(growable: false);

    return _SheetSurface(
      title: member.displayName,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _Chip(
                label: 'SIMULATED VIEW',
                color: CalendarPalette.milestone,
                background: CalendarPalette.milestoneSoft,
              ),
              if (simulation.isChangedMember(member.id))
                _Chip(
                  label: 'Connection changed',
                  color: CalendarPalette.forestDark,
                  background: CalendarPalette.forestSoft,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: CalendarPalette.surfaceSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _CountBlock(
                    label: 'Current connections',
                    value: realConnected.length,
                  ),
                ),
                Container(width: 1, height: 44, color: CalendarPalette.border),
                Expanded(
                  child: _CountBlock(
                    label: 'Simulated connections',
                    value: simulatedConnected.length,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('Connection changes'),
          const SizedBox(height: AppSpacing.sm),
          if (added.isEmpty && removed.isEmpty && affected.isEmpty)
            Text(
              'This member is not changed by the current simulation.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: CalendarPalette.inkSoft),
            )
          else ...[
            ...added.map(
              (moment) => _BulletLine(
                icon: Icons.add_link_rounded,
                text: 'New simulated connection to ${moment.title}',
                color: CalendarPalette.milestone,
              ),
            ),
            ...removed.map(
              (moment) => _BulletLine(
                icon: Icons.link_off_rounded,
                text: 'Connection removed from ${moment.title}',
                color: CalendarPalette.missed,
              ),
            ),
            ...affected
                .where(
                  (moment) =>
                      !added.any((item) => item.id == moment.id) &&
                      !removed.any((item) => item.id == moment.id),
                )
                .map(
                  (moment) => _BulletLine(
                    icon: Icons.science_outlined,
                    text: '${moment.title} is affected by the scenario',
                    color: CalendarPalette.milestone,
                  ),
                ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            'This view shows only projected Moment connections. It does not '
            'claim that ${member.displayName} will participate or that any '
            'relationship will change.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CalendarPalette.inkSoft,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CalendarPalette.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: CalendarPalette.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: CalendarPalette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1, color: CalendarPalette.border),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.title,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  final String title;
  final String value;
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
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: CalendarPalette.inkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CountBlock extends StatelessWidget {
  const _CountBlock({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: CalendarPalette.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: CalendarPalette.inkSoft),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: CalendarPalette.inkSoft,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CalendarPalette.ink,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
}
