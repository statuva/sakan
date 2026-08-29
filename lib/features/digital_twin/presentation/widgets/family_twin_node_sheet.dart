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

Future<void> showFamilyTwinMomentSheet({
  required BuildContext context,
  required FamilyInsightReport report,
  required FamilyMoment moment,
  required RhythmRecord? rhythm,
  required List<MomentInstance> instances,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.84,
        child: _TwinMomentSheet(
          report: report,
          moment: moment,
          rhythm: rhythm,
          instances: instances,
        ),
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
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.82,
        child: _TwinMemberSheet(
          report: report,
          member: member,
        ),
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
  });

  final FamilyInsightReport report;
  final FamilyMoment moment;
  final RhythmRecord? rhythm;
  final List<MomentInstance> instances;

  @override
  Widget build(BuildContext context) {
    final membersById = report.snapshot.membersById;
    final orderedInstances = List<MomentInstance>.from(instances)
      ..sort(
        (first, second) =>
            second.effectiveStartAt.compareTo(first.effectiveStartAt),
      );

    final completed = orderedInstances
        .where((instance) => instance.status == MomentInstanceStatus.completed)
        .toList(growable: false);

    final latestCompleted = completed.isEmpty ? null : completed.first;
    final nextOpen = _nextOpenInstance(orderedInstances);
    final status = _momentStatus(
      moment: moment,
      rhythm: rhythm,
      instances: orderedInstances,
    );

    final participantNames = moment.expectedParticipantIds.map((memberId) {
      return membersById[memberId]?.displayName ?? 'Family member';
    }).toList(growable: false);

    final evidence = latestCompleted == null
        ? const <String>[]
        : _evidenceLabels(latestCompleted.evidenceSignals);

    return _SheetSurface(
      title: moment.title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _StatusChip(
                label: status.label,
                color: status.color,
                background: status.background,
              ),
              _NeutralChip(label: _categoryLabel(moment.category)),
              _NeutralChip(label: _typeLabel(moment.type)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _PatternSummary(
            moment: moment,
            rhythm: rhythm,
            completedCount: completed.length,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Expected participants',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: CalendarPalette.inkSoft),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (participantNames.isEmpty)
            Text(
              'No expected participants are recorded.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: CalendarPalette.inkSoft),
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: participantNames
                  .map((name) => _NeutralChip(label: name))
                  .toList(),
            ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'What Sakan knows',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: CalendarPalette.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InformationPanel(
            children: [
              _InformationRow(
                icon: Icons.history_rounded,
                label: 'Last confirmed session',
                value: latestCompleted == null
                    ? 'No confirmed session yet'
                    : _sessionSummary(latestCompleted),
              ),
              _InformationRow(
                icon: Icons.event_outlined,
                label: 'Next occurrence',
                value: nextOpen == null
                    ? 'No open occurrence is scheduled'
                    : _nextOccurrenceSummary(nextOpen),
              ),
              _InformationRow(
                icon: Icons.track_changes_outlined,
                label: 'Recorded confidence',
                value: moment.type == MomentType.recurring
                    ? _confidenceLabel(
                        rhythm?.confidence ?? ConfidenceLevel.low,
                      )
                    : _instanceConfidenceLabel(latestCompleted),
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Recorded evidence',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: CalendarPalette.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (evidence.isEmpty)
            _InformationPanel(
              children: const [
                _EvidenceRow(
                  text: 'No confirmed occurrence evidence has been recorded yet.',
                  positive: false,
                ),
              ],
            )
          else
            _InformationPanel(
              children: [
                ...evidence.map(
                  (label) => _EvidenceRow(text: label),
                ),
                _EvidenceRow(
                  text:
                      '${_confirmationLevelLabel(latestCompleted!.confirmationLevel)} confirmation level',
                  showDivider: false,
                ),
              ],
            ),
          if (orderedInstances.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Recent occurrence record',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CalendarPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...orderedInstances.take(4).map(
                  (instance) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _OccurrenceRow(instance: instance),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  MomentInstance? _nextOpenInstance(
    List<MomentInstance> instances,
  ) {
    final open = instances.where((instance) => instance.isOpen).toList()
      ..sort(
        (first, second) =>
            first.effectiveStartAt.compareTo(second.effectiveStartAt),
      );

    return open.isEmpty ? null : open.first;
  }

  String _sessionSummary(MomentInstance instance) {
    final local = instance.effectiveStartAt.toLocal();
    final duration = instance.actualDurationMinutes;
    final participants = instance.allRecordedParticipantIds.length;

    final parts = <String>[
      DateFormat('d MMM y').format(local),
      if (duration != null) '$duration min',
      '$participants recorded',
    ];

    return parts.join(' - ');
  }

  String _nextOccurrenceSummary(MomentInstance instance) {
    final local = instance.scheduledStartAt.toLocal();

    return '${DateFormat('EEE, d MMM y').format(local)} at '
        '${DateFormat('h:mm a').format(local)} - '
        '${_instanceStatusLabel(instance.status)}';
  }

  String _instanceConfidenceLabel(MomentInstance? instance) {
    if (instance == null) {
      return 'Low - no completed occurrence yet';
    }

    return _confirmationLevelLabel(instance.confirmationLevel);
  }
}

class _TwinMemberSheet extends StatelessWidget {
  const _TwinMemberSheet({
    required this.report,
    required this.member,
  });

  final FamilyInsightReport report;
  final Member member;

  @override
  Widget build(BuildContext context) {
    final snapshot = report.snapshot;
    final connectedMoments = snapshot.moments
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

    final recordedSessions = snapshot.completedInstances.where((instance) {
      return instance.allRecordedParticipantIds.contains(member.id);
    }).toList(growable: false);

    final upcomingConnected = snapshot.upcomingInstances.where((instance) {
      return instance.expectedParticipantIds.contains(member.id);
    }).toList(growable: false);

    return _SheetSurface(
      title: member.displayName,
      leading: _MemberAvatar(member: member),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
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
          _InformationPanel(
            children: [
              _InformationRow(
                icon: Icons.account_tree_outlined,
                label: 'Connected Moments',
                value: '${connectedMoments.length}',
              ),
              _InformationRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Recorded sessions joined',
                value: '${recordedSessions.length}',
              ),
              _InformationRow(
                icon: Icons.event_outlined,
                label: 'Upcoming expected Moments',
                value: '${upcomingConnected.length}',
                showDivider: false,
              ),
            ],
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
            _InformationPanel(
              children: const [
                _EvidenceRow(
                  text: 'This member is not connected to a recorded Moment yet.',
                  positive: false,
                ),
              ],
            )
          else
            ...connectedMoments.map(
              (moment) {
                final rhythm = snapshot.rhythmForMoment(moment.id);
                final status = _momentStatus(
                  moment: moment,
                  rhythm: rhythm,
                  instances: snapshot.instancesForMoment(moment.id),
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: CalendarPalette.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CalendarPalette.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: status.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                moment.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: CalendarPalette.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_typeLabel(moment.type)} - ${status.label}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: CalendarPalette.inkSoft),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({
    required this.title,
    required this.child,
    this.leading,
  });

  final String title;
  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CalendarPalette.background,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: CalendarPalette.surface,
              border: Border(
                bottom: BorderSide(color: CalendarPalette.border),
              ),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          color: CalendarPalette.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PatternSummary extends StatelessWidget {
  const _PatternSummary({
    required this.moment,
    required this.rhythm,
    required this.completedCount,
  });

  final FamilyMoment moment;
  final RhythmRecord? rhythm;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final text = moment.type == MomentType.recurring
        ? _recurringText()
        : _oneTimeText();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: CalendarPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CalendarPalette.inkSoft,
              height: 1.45,
            ),
      ),
    );
  }

  String _recurringText() {
    final record = rhythm;
    final interval = record?.expectedIntervalDays ??
        moment.expectedIntervalDays ??
        7;

    if (record == null || record.lastOccurrenceAt == null) {
      return 'No confirmed session yet - usual $interval days - '
          'tracked over $completedCount past sessions';
    }

    return '${record.currentGapDays}d since last - usual ${record.expectedIntervalDays}d - '
        'tracked over ${record.occurrenceCount} past sessions';
  }

  String _oneTimeText() {
    return 'One-time family Moment - importance ${moment.importanceLevel}/5';
  }
}

class _InformationPanel extends StatelessWidget {
  const _InformationPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CalendarPalette.border),
      ),
      child: Column(children: children),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: CalendarPalette.forest,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: CalendarPalette.inkSoft),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: CalendarPalette.ink),
                    ),
                  ],
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

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.text,
    this.positive = true,
    this.showDivider = true,
  });

  final String text;
  final bool positive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                positive ? Icons.check_rounded : Icons.info_outline_rounded,
                size: 18,
                color: positive
                    ? CalendarPalette.stable
                    : CalendarPalette.inkSoft,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: CalendarPalette.inkSoft),
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

class _OccurrenceRow extends StatelessWidget {
  const _OccurrenceRow({required this.instance});

  final MomentInstance instance;

  @override
  Widget build(BuildContext context) {
    final status = _instanceStatus(instance.status);
    final local = instance.effectiveStartAt.toLocal();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CalendarPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, d MMM y - h:mm a').format(local),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: CalendarPalette.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  _occurrenceSubtitle(instance),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: CalendarPalette.inkSoft),
                ),
              ],
            ),
          ),
          _StatusChip(
            label: status.label,
            color: status.color,
            background: status.background,
          ),
        ],
      ),
    );
  }

  String _occurrenceSubtitle(MomentInstance instance) {
    final parts = <String>[];

    if (instance.actualDurationMinutes != null) {
      parts.add('${instance.actualDurationMinutes} min');
    }

    if (instance.allRecordedParticipantIds.isNotEmpty) {
      parts.add('${instance.allRecordedParticipantIds.length} recorded');
    }

    return parts.isEmpty ? 'No additional record' : parts.join(' - ');
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final name = member.displayName.trim();

    return CircleAvatar(
      radius: 22,
      backgroundColor: CalendarPalette.forestDark,
      foregroundColor: Colors.white,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w800),
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
        color: CalendarPalette.slateSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: CalendarPalette.inkSoft,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
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

class _TwinStatusVisual {
  const _TwinStatusVisual({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;
}

_TwinStatusVisual _momentStatus({
  required FamilyMoment moment,
  required RhythmRecord? rhythm,
  required List<MomentInstance> instances,
}) {
  final active = instances.any(
    (instance) => instance.status == MomentInstanceStatus.active,
  );

  if (active) {
    return const _TwinStatusVisual(
      label: 'Active',
      color: CalendarPalette.strengthening,
      background: CalendarPalette.strengtheningSoft,
    );
  }

  if (moment.type == MomentType.recurring) {
    return switch (rhythm?.status ?? RhythmStatus.stillLearning) {
      RhythmStatus.stillLearning => const _TwinStatusVisual(
          label: 'Still Learning',
          color: CalendarPalette.slate,
          background: CalendarPalette.slateSoft,
        ),
      RhythmStatus.stable => const _TwinStatusVisual(
          label: 'Stable',
          color: CalendarPalette.stable,
          background: CalendarPalette.stableSoft,
        ),
      RhythmStatus.drifting => const _TwinStatusVisual(
          label: 'Drifting',
          color: CalendarPalette.drifting,
          background: CalendarPalette.driftingSoft,
        ),
      RhythmStatus.recovering => const _TwinStatusVisual(
          label: 'Recovering',
          color: CalendarPalette.recovering,
          background: CalendarPalette.recoveringSoft,
        ),
      RhythmStatus.strengthening => const _TwinStatusVisual(
          label: 'Strengthening',
          color: CalendarPalette.strengthening,
          background: CalendarPalette.strengtheningSoft,
        ),
    };
  }

  final newest = List<MomentInstance>.from(instances)
    ..sort(
      (first, second) =>
          second.effectiveStartAt.compareTo(first.effectiveStartAt),
    );

  if (newest.isEmpty) {
    return const _TwinStatusVisual(
      label: 'Upcoming',
      color: CalendarPalette.upcoming,
      background: CalendarPalette.upcomingSoft,
    );
  }

  return _instanceStatus(newest.first.status);
}

_TwinStatusVisual _instanceStatus(MomentInstanceStatus status) {
  return switch (status) {
    MomentInstanceStatus.active => const _TwinStatusVisual(
        label: 'Active',
        color: CalendarPalette.strengthening,
        background: CalendarPalette.strengtheningSoft,
      ),
    MomentInstanceStatus.completed => const _TwinStatusVisual(
        label: 'Completed',
        color: CalendarPalette.stable,
        background: CalendarPalette.stableSoft,
      ),
    MomentInstanceStatus.missed => const _TwinStatusVisual(
        label: 'Missed',
        color: CalendarPalette.missed,
        background: CalendarPalette.missedSoft,
      ),
    MomentInstanceStatus.cancelled => const _TwinStatusVisual(
        label: 'Cancelled',
        color: CalendarPalette.slate,
        background: CalendarPalette.slateSoft,
      ),
    _ => const _TwinStatusVisual(
        label: 'Upcoming',
        color: CalendarPalette.upcoming,
        background: CalendarPalette.upcomingSoft,
      ),
  };
}

List<String> _evidenceLabels(
  List<MomentEvidenceSignal> signals,
) {
  return signals.map((signal) {
    return switch (signal) {
      MomentEvidenceSignal.scheduled => 'Scheduled occurrence recorded',
      MomentEvidenceSignal.hostStarted => 'Session started in Sakan',
      MomentEvidenceSignal.manualCheckIn => 'Manual member check-in recorded',
      MomentEvidenceSignal.multipleCheckIns => 'Multiple member check-ins recorded',
      MomentEvidenceSignal.durationRecorded => 'Session duration recorded',
      MomentEvidenceSignal.bluetoothNearby => 'Bluetooth nearby evidence recorded',
      MomentEvidenceSignal.qrCheckIn => 'QR check-in recorded',
      MomentEvidenceSignal.todayReview => 'Confirmed through Today Review',
      MomentEvidenceSignal.familyNote => 'Family note recorded',
      MomentEvidenceSignal.memoryCreated => 'Memory linked to the occurrence',
    };
  }).toSet().toList(growable: false);
}

String _instanceStatusLabel(MomentInstanceStatus status) {
  return switch (status) {
    MomentInstanceStatus.proposed => 'Proposed',
    MomentInstanceStatus.scheduled => 'Scheduled',
    MomentInstanceStatus.inviting => 'Inviting',
    MomentInstanceStatus.active => 'Active',
    MomentInstanceStatus.completed => 'Completed',
    MomentInstanceStatus.missed => 'Missed',
    MomentInstanceStatus.cancelled => 'Cancelled',
  };
}

String _confirmationLevelLabel(MomentConfirmationLevel level) {
  return switch (level) {
    MomentConfirmationLevel.low => 'Low',
    MomentConfirmationLevel.medium => 'Medium',
    MomentConfirmationLevel.high => 'High',
  };
}

String _confidenceLabel(ConfidenceLevel level) {
  return switch (level) {
    ConfidenceLevel.low => 'Low',
    ConfidenceLevel.medium => 'Medium',
    ConfidenceLevel.high => 'High',
  };
}

String _categoryLabel(MomentCategory category) {
  return switch (category) {
    MomentCategory.tradition => 'Tradition',
    MomentCategory.milestone => 'Milestone',
    MomentCategory.responsibility => 'Responsibility',
    MomentCategory.care => 'Care',
    MomentCategory.familyTime => 'Family Time',
    MomentCategory.memory => 'Memory',
  };
}

String _typeLabel(MomentType type) {
  return switch (type) {
    MomentType.recurring => 'Recurring',
    MomentType.singular => 'One-time',
  };
}

String _roleLabel(FamilyRole role) {
  return switch (role) {
    FamilyRole.admin => 'Family Admin',
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
    FamilyRelationship.other => 'Family Member',
  };
}
