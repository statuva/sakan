import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_insight_report.dart';
import '../../../../shared/models/family_moment.dart';
import '../../../../shared/models/member.dart';
import '../../../../shared/models/model_enums.dart';
import '../../../../shared/models/moment_instance.dart';
import '../../../../shared/models/rhythm_record.dart';
import '../../../calendar/presentation/widgets/calendar_palette.dart';
import '../../domain/digital_twin_interpretation.dart';
import '../../services/digital_twin_interpretation_service.dart';
import '../digital_twin_visuals.dart';

const DigitalTwinInterpretationService _interpretationService =
    DigitalTwinInterpretationService();

Future<void> showFamilyTwinMomentSheet({
  required BuildContext context,
  required FamilyInsightReport report,
  required FamilyMoment moment,
  required RhythmRecord? rhythm,
  required List<MomentInstance> instances,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.84,
        minChildSize: 0.58,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _TwinMomentSheet(
            report: report,
            moment: moment,
            rhythm: rhythm,
            instances: instances,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

Future<void> showFamilyTwinMemberSheet({
  required BuildContext context,
  required FamilyInsightReport report,
  required Member member,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.48,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return _TwinMemberSheet(
            report: report,
            member: member,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _TwinMomentSheet extends StatelessWidget {
  const _TwinMomentSheet({
    required this.report,
    required this.moment,
    required this.rhythm,
    required this.instances,
    required this.scrollController,
  });

  final FamilyInsightReport report;
  final FamilyMoment moment;
  final RhythmRecord? rhythm;
  final List<MomentInstance> instances;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final orderedInstances = List<MomentInstance>.from(instances)
      ..sort(
        (first, second) =>
            second.effectiveStartAt.compareTo(first.effectiveStartAt),
      );

    final completed = orderedInstances
        .where((instance) => instance.status == MomentInstanceStatus.completed)
        .toList(growable: false);

    final missedCount = orderedInstances
        .where((instance) => instance.status == MomentInstanceStatus.missed)
        .length;

    final latestCompleted = completed.isEmpty ? null : completed.first;
    final nextOpen = _nextOpenInstance(orderedInstances);
    final status = rhythm?.status ?? RhythmStatus.stillLearning;
    final visual = twinRhythmVisual(status);
    final categoryVisual = twinCategoryVisual(moment.category);
    final confidence = rhythm?.confidence ?? ConfidenceLevel.low;

    final interpretation = _interpretationService.interpretMoment(
      moment: moment,
      rhythm: rhythm,
      instances: orderedInstances,
    );

    final membersById = report.snapshot.membersById;

    final participants =
        moment.expectedParticipantIds
            .map((id) => membersById[id])
            .whereType<Member>()
            .toList()
          ..sort(
            (first, second) => first.displayName.compareTo(second.displayName),
          );

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
              _LabelChip(
                label: visual.label,
                color: visual.color,
                background: visual.background,
              ),
              _CategoryChip(visual: categoryVisual),
              _NeutralChip(
                label: twinFrequencyLabel(
                  rhythm?.expectedIntervalDays ?? moment.expectedIntervalDays,
                ),
              ),
              _NeutralChip(label: twinConfidenceLabel(confidence)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Participants',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: CalendarPalette.inkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (participants.isEmpty)
            Text(
              'No active family members are currently linked to this Moment.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: CalendarPalette.inkSoft),
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: participants
                  .map(
                    (member) => Chip(
                      avatar: CircleAvatar(
                        child: Text(_initial(member.displayName)),
                      ),
                      label: Text(member.displayName),
                      side: BorderSide.none,
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: AppSpacing.xl),
          _InterpretationPanel(interpretation: interpretation),
          const SizedBox(height: AppSpacing.lg),
          _EvidenceExpansion(
            moment: moment,
            rhythm: rhythm,
            instances: orderedInstances,
            completedCount: completed.length,
            missedCount: missedCount,
            latestCompleted: latestCompleted,
            nextOpen: nextOpen,
          ),
        ],
      ),
    );
  }

  MomentInstance? _nextOpenInstance(List<MomentInstance> instances) {
    final open = instances.where((instance) => instance.isOpen).toList()
      ..sort(
        (first, second) =>
            first.effectiveStartAt.compareTo(second.effectiveStartAt),
      );

    return open.isEmpty ? null : open.first;
  }
}

class _InterpretationPanel extends StatelessWidget {
  const _InterpretationPanel({required this.interpretation});

  final MomentTwinInterpretation interpretation;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = switch (interpretation.origin) {
      DigitalTwinInterpretationOrigin.externalAi => 'AI interpretation',
      DigitalTwinInterpretationOrigin.ruleBasedFallback =>
        'Sakan interpretation',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: CalendarPalette.forestSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 19,
                color: CalendarPalette.forestDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'What this means for your family',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CalendarPalette.forestDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            interpretation.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CalendarPalette.ink,
              height: 1.5,
            ),
          ),
          if (interpretation.themes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: interpretation.themes
                  .map(
                    (theme) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(170),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        theme,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: CalendarPalette.forestDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            '$sourceLabel · grounded in recorded Moment data',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: CalendarPalette.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _EvidenceExpansion extends StatelessWidget {
  const _EvidenceExpansion({
    required this.moment,
    required this.rhythm,
    required this.instances,
    required this.completedCount,
    required this.missedCount,
    required this.latestCompleted,
    required this.nextOpen,
  });

  final FamilyMoment moment;
  final RhythmRecord? rhythm;
  final List<MomentInstance> instances;
  final int completedCount;
  final int missedCount;
  final MomentInstance? latestCompleted;
  final MomentInstance? nextOpen;

  @override
  Widget build(BuildContext context) {
    final averageParticipation = _averageParticipationText();
    final averageDuration = _averageDurationText();

    return Container(
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CalendarPalette.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 2,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          leading: const Icon(
            Icons.fact_check_outlined,
            color: CalendarPalette.forest,
          ),
          title: Text(
            'How Sakan knows this',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: CalendarPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            'Open the recorded facts and recent history.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: CalendarPalette.inkSoft),
          ),
          children: [
            _FactLine(label: 'Confirmed sessions', value: '$completedCount'),
            if (missedCount > 0)
              _FactLine(label: 'Missed occurrences', value: '$missedCount'),
            _FactLine(
              label: 'Usual rhythm',
              value: twinFrequencyLabel(
                rhythm?.expectedIntervalDays ?? moment.expectedIntervalDays,
              ),
            ),
            if (rhythm?.lastOccurrenceAt != null)
              _FactLine(
                label: 'Since last confirmed session',
                value: '${rhythm!.currentGapDays} days',
              ),
            if (averageParticipation != null)
              _FactLine(
                label: 'Average recorded participation',
                value: averageParticipation,
              ),
            if (averageDuration != null)
              _FactLine(
                label: 'Average session duration',
                value: averageDuration,
              ),
            _FactLine(
              label: 'Recorded confidence',
              value: twinConfidenceLabel(
                rhythm?.confidence ?? ConfidenceLevel.low,
              ),
            ),
            _FactLine(
              label: 'Next occurrence',
              value: nextOpen == null
                  ? 'No open occurrence scheduled'
                  : DateFormat(
                      'EEE, d MMM y · h:mm a',
                    ).format(nextOpen!.scheduledStartAt.toLocal()),
              showDivider: false,
            ),
            if (latestCompleted != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Latest recorded evidence',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: CalendarPalette.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._evidenceLabels(latestCompleted!.evidenceSignals).map(
                (label) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: CalendarPalette.stable,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (instances.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Recent history',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: CalendarPalette.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...instances
                  .take(4)
                  .map((instance) => _OccurrenceLine(instance: instance)),
            ],
          ],
        ),
      ),
    );
  }

  String? _averageParticipationText() {
    var recordedTotal = 0;
    var expectedTotal = 0;

    for (final instance in instances) {
      if (instance.status != MomentInstanceStatus.completed) {
        continue;
      }

      final expected = instance.expectedParticipantIds.toSet();

      if (expected.isEmpty) {
        continue;
      }

      recordedTotal += instance.allRecordedParticipantIds
          .toSet()
          .intersection(expected)
          .length;

      expectedTotal += expected.length;
    }

    if (expectedTotal == 0) {
      return null;
    }

    final percent = (recordedTotal / expectedTotal * 100).round();

    return '$percent% of expected members';
  }

  String? _averageDurationText() {
    final durations = instances
        .where((instance) => instance.status == MomentInstanceStatus.completed)
        .map((instance) => instance.actualDurationMinutes)
        .whereType<int>()
        .toList(growable: false);

    if (durations.isEmpty) {
      return null;
    }

    final total = durations.fold<int>(0, (sum, value) => sum + value);

    return '${(total / durations.length).round()} min';
  }
}

class _OccurrenceLine extends StatelessWidget {
  const _OccurrenceLine({required this.instance});

  final MomentInstance instance;

  @override
  Widget build(BuildContext context) {
    final visual = _instanceVisual(instance.status);

    final details = <String>[
      DateFormat('d MMM y').format(instance.effectiveStartAt.toLocal()),
      if (instance.actualDurationMinutes != null)
        '${instance.actualDurationMinutes} min',
      if (instance.allRecordedParticipantIds.isNotEmpty)
        '${instance.allRecordedParticipantIds.length} recorded',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: CalendarPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: visual.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              details.join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            visual.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: visual.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TwinMemberSheet extends StatelessWidget {
  const _TwinMemberSheet({
    required this.report,
    required this.member,
    required this.scrollController,
  });

  final FamilyInsightReport report;
  final Member member;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final snapshot = report.snapshot;

    final connectedMoments =
        snapshot.moments
            .where(
              (moment) => moment.expectedParticipantIds.contains(member.id),
            )
            .toList()
          ..sort((first, second) {
            if (first.type != second.type) {
              return first.type == MomentType.recurring ? -1 : 1;
            }

            return first.title.compareTo(second.title);
          });

    final joinedSessions = snapshot.completedInstances.where((instance) {
      return instance.allRecordedParticipantIds.contains(member.id);
    }).length;

    final upcoming = snapshot.upcomingInstances
        .where(
          (instance) => instance.expectedParticipantIds.contains(member.id),
        )
        .length;

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
              _NeutralChip(label: _roleLabel(member.role)),
              _NeutralChip(label: _relationshipLabel(member.relationship)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: CalendarPalette.surfaceSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _FactLine(
                  label: 'Connected Moments',
                  value: '${connectedMoments.length}',
                ),
                _FactLine(
                  label: 'Recorded sessions joined',
                  value: '$joinedSessions',
                ),
                _FactLine(
                  label: 'Upcoming expected Moments',
                  value: '$upcoming',
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Connected Moments',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: CalendarPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (connectedMoments.isEmpty)
            Text(
              'This member is not connected to a recorded Family Moment yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: CalendarPalette.inkSoft),
            )
          else
            ...connectedMoments.map((moment) {
              final rhythm = snapshot.rhythmForMoment(moment.id);

              final visual = twinRhythmVisual(
                rhythm?.status ?? RhythmStatus.stillLearning,
              );

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: CalendarPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CalendarPalette.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      twinCategoryIcon(moment.category),
                      size: 19,
                      color: moment.type == MomentType.recurring
                          ? visual.color
                          : CalendarPalette.upcoming,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        moment.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (moment.type == MomentType.recurring)
                      Text(
                        visual.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: visual.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              );
            }),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'This view reports recorded participation only. '
            'It does not score or judge an individual family member.',
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

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CalendarPalette.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 9),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: CalendarPalette.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CalendarPalette.ink,
                  fontWeight: FontWeight.w700,
                ),
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

class _LabelChip extends StatelessWidget {
  const _LabelChip({
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
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.visual});

  final TwinCategoryVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: 14, color: visual.color),
          const SizedBox(width: 5),
          Text(
            visual.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: visual.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeutralChip extends StatelessWidget {
  const _NeutralChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CalendarPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: CalendarPalette.inkSoft,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CalendarPalette.inkSoft,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CalendarPalette.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: CalendarPalette.border),
      ],
    );
  }
}

TwinStatusVisual _instanceVisual(MomentInstanceStatus status) {
  return switch (status) {
    MomentInstanceStatus.completed => const TwinStatusVisual(
      label: 'Completed',
      color: CalendarPalette.stable,
      background: CalendarPalette.stableSoft,
    ),
    MomentInstanceStatus.missed => const TwinStatusVisual(
      label: 'Missed',
      color: CalendarPalette.missed,
      background: CalendarPalette.missedSoft,
    ),
    MomentInstanceStatus.active => const TwinStatusVisual(
      label: 'Active',
      color: CalendarPalette.strengthening,
      background: CalendarPalette.strengtheningSoft,
    ),
    MomentInstanceStatus.cancelled => const TwinStatusVisual(
      label: 'Cancelled',
      color: CalendarPalette.slate,
      background: CalendarPalette.slateSoft,
    ),
    _ => const TwinStatusVisual(
      label: 'Scheduled',
      color: CalendarPalette.upcoming,
      background: CalendarPalette.upcomingSoft,
    ),
  };
}

List<String> _evidenceLabels(List<MomentEvidenceSignal> signals) {
  final labels = <String>[];

  for (final signal in signals) {
    final label = switch (signal) {
      MomentEvidenceSignal.scheduled => 'A scheduled occurrence was recorded',
      MomentEvidenceSignal.hostStarted =>
        'A family member started the session in Sakan',
      MomentEvidenceSignal.manualCheckIn =>
        'At least one manual member check-in was recorded',
      MomentEvidenceSignal.multipleCheckIns =>
        'Multiple member check-ins were recorded',
      MomentEvidenceSignal.durationRecorded =>
        'The session duration was recorded',
      MomentEvidenceSignal.bluetoothNearby =>
        'Optional Bluetooth nearby evidence was recorded',
      MomentEvidenceSignal.qrCheckIn => 'A QR check-in was recorded',
      MomentEvidenceSignal.todayReview =>
        'The outcome was confirmed through Today Review',
      MomentEvidenceSignal.familyNote => 'A family note was added',
      MomentEvidenceSignal.memoryCreated =>
        'A Memory was linked to the occurrence',
    };

    if (!labels.contains(label)) {
      labels.add(label);
    }
  }

  return labels;
}

String _roleLabel(FamilyRole role) {
  return switch (role) {
    FamilyRole.admin => 'Admin',
    FamilyRole.adult => 'Adult',
    FamilyRole.child => 'Child',
  };
}

String _relationshipLabel(FamilyRelationship relationship) {
  return switch (relationship) {
    FamilyRelationship.parent => 'Parent',
    FamilyRelationship.child => 'Child',
    FamilyRelationship.grandparent => 'Grandparent',
    FamilyRelationship.sibling => 'Sibling',
    FamilyRelationship.guardian => 'Guardian',
    FamilyRelationship.relative => 'Relative',
    FamilyRelationship.other => 'Family member',
  };
}

String _initial(String name) {
  final trimmed = name.trim();

  return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
}
