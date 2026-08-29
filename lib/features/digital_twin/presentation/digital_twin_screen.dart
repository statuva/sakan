import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/family_insight_report.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/models/rhythm_record.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../../calendar/presentation/widgets/calendar_palette.dart';
import 'widgets/family_twin_map.dart';
import 'widgets/family_twin_node_sheet.dart';

class DigitalTwinScreen extends StatefulWidget {
  const DigitalTwinScreen({super.key});

  @override
  State<DigitalTwinScreen> createState() => _DigitalTwinScreenState();
}

class _DigitalTwinScreenState extends State<DigitalTwinScreen> {
  Stream<FamilyInsightReport>? _reportStream;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTwin();
  }

  Future<void> _loadTwin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AppDependencies.currentFamilyService.load();

      if (!mounted) return;

      setState(() {
        _reportStream = AppDependencies.familyInsightService.watchReport();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load the Family Digital Twin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Building the family Moment map...'),
        ),
      );
    }

    if (_reportStream == null) {
      return Scaffold(
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'The Family Digital Twin is unavailable.',
            onRetry: _loadTwin,
          ),
        ),
      );
    }

    return StreamBuilder<FamilyInsightReport>(
      stream: _reportStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: AppErrorState(
                message: 'We could not update the Family Digital Twin.',
                onRetry: _loadTwin,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(
                message: 'Reading the recorded family patterns...',
              ),
            ),
          );
        }

        final report = snapshot.data;

        if (report == null) {
          return Scaffold(
            body: SafeArea(
              child: AppErrorState(
                message: 'No Digital Twin report is available yet.',
                onRetry: _loadTwin,
              ),
            ),
          );
        }

        return _buildTwin(context, report);
      },
    );
  }

  Widget _buildTwin(BuildContext context, FamilyInsightReport report) {
    final snapshot = report.snapshot;

    final recurringMoments =
        snapshot.moments
            .where((moment) => moment.type == MomentType.recurring)
            .toList()
          ..sort((first, second) {
            final firstRhythm = snapshot.rhythmForMoment(first.id);
            final secondRhythm = snapshot.rhythmForMoment(second.id);

            final statusResult =
                _rhythmRank(
                  firstRhythm?.status ?? RhythmStatus.stillLearning,
                ).compareTo(
                  _rhythmRank(
                    secondRhythm?.status ?? RhythmStatus.stillLearning,
                  ),
                );

            if (statusResult != 0) {
              return statusResult;
            }

            return first.title.compareTo(second.title);
          });

    final upcomingOneTime = _upcomingOneTimeEntries(report);

    return Scaffold(
      backgroundColor: CalendarPalette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            118,
          ),
          children: [
            Text(
              'Sakan',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: CalendarPalette.forest,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Digital Twin',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: CalendarPalette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'A visual view of each family Moment, its connections, and its recorded rhythm.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CalendarPalette.inkSoft,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FamilyTwinMap(
              report: report,
              onMemberTap: (member) {
                unawaited(
                  showFamilyTwinMemberSheet(
                    context: context,
                    report: report,
                    member: member,
                  ),
                );
              },
              onMomentTap: (moment, rhythm, instances) {
                unawaited(
                  showFamilyTwinMomentSheet(
                    context: context,
                    report: report,
                    moment: moment,
                    rhythm: rhythm,
                    instances: instances,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            _SectionHeading(
              title: 'Moment Patterns',
              subtitle:
                  'Each recurring Moment has its own state. Sakan does not assign one status to the whole family.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (recurringMoments.isEmpty)
              const AppCard(
                child: Text('No recurring family Moments have been added yet.'),
              )
            else
              ...recurringMoments.map((moment) {
                final rhythm = snapshot.rhythmForMoment(moment.id);
                final instances = snapshot.instancesForMoment(moment.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _MomentPatternCard(
                    moment: moment,
                    rhythm: rhythm,
                    instances: instances,
                    onTap: () {
                      unawaited(
                        showFamilyTwinMomentSheet(
                          context: context,
                          report: report,
                          moment: moment,
                          rhythm: rhythm,
                          instances: instances,
                        ),
                      );
                    },
                  ),
                );
              }),
            if (upcomingOneTime.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const _SectionHeading(
                title: 'Upcoming Family Moments',
                subtitle:
                    'One-time milestones and care Moments are shown separately from recurring rhythms.',
              ),
              const SizedBox(height: AppSpacing.md),
              ...upcomingOneTime.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _UpcomingMomentCard(
                    entry: entry,
                    onTap: () {
                      unawaited(
                        showFamilyTwinMomentSheet(
                          context: context,
                          report: report,
                          moment: entry.moment,
                          rhythm: null,
                          instances: snapshot.instancesForMoment(
                            entry.moment.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (report.primaryInsight == null)
              const _NoInsightCard()
            else
              _TwinNoticeCard(
                insight: report.primaryInsight!,
                onOpen: () {
                  unawaited(_showInsightDetails(report.primaryInsight!));
                },
              ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showWhatIfPlaceholder,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Ask "What if...?"'),
                style: FilledButton.styleFrom(
                  backgroundColor: CalendarPalette.ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_UpcomingMomentEntry> _upcomingOneTimeEntries(
    FamilyInsightReport report,
  ) {
    final snapshot = report.snapshot;
    final result = <_UpcomingMomentEntry>[];
    final seenMomentIds = <String>{};

    for (final instance in snapshot.upcomingInstances) {
      final moment = snapshot.momentById(instance.momentId);

      if (moment == null ||
          moment.type != MomentType.singular ||
          !seenMomentIds.add(moment.id)) {
        continue;
      }

      result.add(
        _UpcomingMomentEntry(
          moment: moment,
          instance: instance,
          hasReminder: snapshot.activeReminderForMoment(moment.id) != null,
        ),
      );
    }

    result.sort(
      (first, second) => first.instance.scheduledStartAt.compareTo(
        second.instance.scheduledStartAt,
      ),
    );

    return result.take(5).toList(growable: false);
  }

  int _rhythmRank(RhythmStatus status) {
    return switch (status) {
      RhythmStatus.drifting => 0,
      RhythmStatus.recovering => 1,
      RhythmStatus.stillLearning => 2,
      RhythmStatus.stable => 3,
      RhythmStatus.strengthening => 4,
    };
  }

  Future<void> _showInsightDetails(FamilyInsightItem insight) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _TwinInsightDialog(insight: insight);
      },
    );
  }

  Future<void> _showWhatIfPlaceholder() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Ask "What if...?"'),
          content: const Text(
            'This feature will later let the family explore how changing a Moment\'s timing, frequency, or participants could affect its recorded rhythm. No simulation is running yet.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: CalendarPalette.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: CalendarPalette.inkSoft,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _MomentPatternCard extends StatelessWidget {
  const _MomentPatternCard({
    required this.moment,
    required this.rhythm,
    required this.instances,
    required this.onTap,
  });

  final FamilyMoment moment;
  final RhythmRecord? rhythm;
  final List<MomentInstance> instances;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _rhythmVisual(rhythm?.status ?? RhythmStatus.stillLearning);

    final completed =
        instances
            .where(
              (instance) => instance.status == MomentInstanceStatus.completed,
            )
            .toList()
          ..sort(
            (first, second) =>
                second.effectiveStartAt.compareTo(first.effectiveStartAt),
          );

    final open = instances.where((instance) => instance.isOpen).toList()
      ..sort(
        (first, second) =>
            first.effectiveStartAt.compareTo(second.effectiveStartAt),
      );

    final latestCompleted = completed.isEmpty ? null : completed.first;
    final nextOpen = open.isEmpty ? null : open.first;
    final interval =
        rhythm?.expectedIntervalDays ?? moment.expectedIntervalDays ?? 7;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.eco_outlined, size: 19, color: visual.color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moment.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: CalendarPalette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _patternSentence(
                        rhythm: rhythm,
                        interval: interval,
                        completedCount: completed.length,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CalendarPalette.inkSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _SmallStatusChip(visual: visual),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _MetadataPill(
                icon: Icons.repeat_rounded,
                text: 'Every $interval days',
              ),
              _MetadataPill(
                icon: Icons.check_circle_outline_rounded,
                text:
                    '${rhythm?.occurrenceCount ?? completed.length} confirmed',
              ),
              _MetadataPill(
                icon: Icons.track_changes_outlined,
                text:
                    '${_confidenceLabel(rhythm?.confidence ?? ConfidenceLevel.low)} confidence',
              ),
            ],
          ),
          if (latestCompleted != null || nextOpen != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: CalendarPalette.border),
            const SizedBox(height: AppSpacing.sm),
            if (latestCompleted != null)
              _QuietLine(
                icon: Icons.history_rounded,
                text: _lastSessionLine(latestCompleted),
              ),
            if (nextOpen != null) ...[
              if (latestCompleted != null)
                const SizedBox(height: AppSpacing.xs),
              _QuietLine(
                icon: Icons.event_outlined,
                text:
                    'Next: ${DateFormat('EEE, d MMM - h:mm a').format(nextOpen.scheduledStartAt.toLocal())}',
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _patternSentence({
    required RhythmRecord? rhythm,
    required int interval,
    required int completedCount,
  }) {
    if (rhythm == null || rhythm.lastOccurrenceAt == null) {
      return completedCount == 0
          ? 'No confirmed session yet. Sakan is waiting for the first recorded occurrence.'
          : '$completedCount recorded sessions. Sakan still needs more history to identify a reliable pattern.';
    }

    return '${rhythm.currentGapDays} days since the last confirmed occurrence, compared with the usual $interval-day rhythm.';
  }

  String _lastSessionLine(MomentInstance instance) {
    final parts = <String>[
      'Last: ${DateFormat('d MMM').format(instance.effectiveStartAt.toLocal())}',
      if (instance.actualDurationMinutes != null)
        '${instance.actualDurationMinutes} min',
      '${instance.allRecordedParticipantIds.length} recorded',
    ];

    return parts.join(' - ');
  }
}

class _UpcomingMomentCard extends StatelessWidget {
  const _UpcomingMomentCard({required this.entry, required this.onTap});

  final _UpcomingMomentEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = entry.instance.scheduledStartAt.toLocal();
    final visual = _categoryVisual(entry.moment.category);

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: visual.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(visual.icon, color: visual.color, size: 21),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.moment.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CalendarPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_relativeDate(local)} - ${DateFormat('h:mm a').format(local)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CalendarPalette.inkSoft,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_categoryLabel(entry.moment.category)} - importance ${entry.moment.importanceLevel}/5 - '
                  '${entry.moment.expectedParticipantIds.length} expected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CalendarPalette.inkSoft,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MetadataPill(
                  icon: entry.hasReminder
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_outlined,
                  text: entry.hasReminder
                      ? 'Preparation reminder added'
                      : 'No preparation reminder yet',
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: CalendarPalette.inkSoft,
          ),
        ],
      ),
    );
  }

  String _relativeDate(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final target = DateUtils.dateOnly(date);
    final days = target.difference(today).inDays;

    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days > 1 && days <= 14) return 'In $days days';
    return DateFormat('d MMM y').format(date);
  }
}

class _TwinNoticeCard extends StatelessWidget {
  const _TwinNoticeCard({required this.insight, required this.onOpen});

  final FamilyInsightItem insight;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final visual = _insightVisual(insight.kind);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CalendarPalette.border),
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
                  color: visual.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(visual.icon, size: 19, color: visual.color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WHAT SAKAN NOTICES',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: CalendarPalette.inkSoft,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      visual.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: visual.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            insight.headline,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: CalendarPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            insight.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CalendarPalette.inkSoft,
              height: 1.45,
            ),
          ),
          if (insight.reasons.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: insight.reasons
                  .take(2)
                  .map((reason) => _FactPill(text: reason, color: visual.color))
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text('View details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TwinInsightDialog extends StatelessWidget {
  const _TwinInsightDialog({required this.insight});

  final FamilyInsightItem insight;

  @override
  Widget build(BuildContext context) {
    final visual = _insightVisual(insight.kind);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 660),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: visual.background,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(visual.icon, color: visual.color),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What Sakan Notices',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: visual.color,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          insight.headline,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: CalendarPalette.ink),
                        ),
                      ],
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
              const SizedBox(height: AppSpacing.md),
              Text(
                insight.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CalendarPalette.inkSoft,
                  height: 1.5,
                ),
              ),
              if (insight.reasons.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'What this is based on',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CalendarPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...insight.reasons.map(
                  (reason) => _InsightBullet(
                    icon: Icons.check_circle_outline_rounded,
                    text: reason,
                    color: visual.color,
                  ),
                ),
              ],
              if (insight.suggestedActions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Possible next steps',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CalendarPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...List.generate(
                  insight.suggestedActions.length,
                  (index) => _InsightBullet(
                    icon: Icons.circle_outlined,
                    text: insight.suggestedActions[index],
                    color: CalendarPalette.forest,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightBullet extends StatelessWidget {
  const _InsightBullet({
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: CalendarPalette.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactPill extends StatelessWidget {
  const _FactPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InsightVisual {
  const _InsightVisual({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
}

_InsightVisual _insightVisual(FamilyInsightKind kind) {
  return switch (kind) {
    FamilyInsightKind.activeMoment => const _InsightVisual(
      label: 'Live Family Moment',
      icon: Icons.play_circle_outline_rounded,
      color: CalendarPalette.strengthening,
      background: CalendarPalette.strengtheningSoft,
    ),
    FamilyInsightKind.reviewNeeded => const _InsightVisual(
      label: 'Today Review Needed',
      icon: Icons.fact_check_outlined,
      color: CalendarPalette.drifting,
      background: CalendarPalette.driftingSoft,
    ),
    FamilyInsightKind.overdueReminder => const _InsightVisual(
      label: 'Overdue Reminder',
      icon: Icons.warning_amber_rounded,
      color: CalendarPalette.missed,
      background: CalendarPalette.missedSoft,
    ),
    FamilyInsightKind.upcomingMilestone => const _InsightVisual(
      label: 'Upcoming Milestone',
      icon: Icons.star_border_rounded,
      color: CalendarPalette.milestone,
      background: CalendarPalette.milestoneSoft,
    ),
    FamilyInsightKind.carePreparation => const _InsightVisual(
      label: 'Care Preparation',
      icon: Icons.favorite_border_rounded,
      color: CalendarPalette.care,
      background: CalendarPalette.careSoft,
    ),
    FamilyInsightKind.sharedMomentOpportunity => const _InsightVisual(
      label: 'Shared Moment Opportunity',
      icon: Icons.groups_2_outlined,
      color: CalendarPalette.forest,
      background: CalendarPalette.forestSoft,
    ),
    FamilyInsightKind.driftingRhythm => const _InsightVisual(
      label: 'Drifting Rhythm',
      icon: Icons.trending_down_rounded,
      color: CalendarPalette.drifting,
      background: CalendarPalette.driftingSoft,
    ),
    FamilyInsightKind.upcomingMoment => const _InsightVisual(
      label: 'Upcoming Moment',
      icon: Icons.event_outlined,
      color: CalendarPalette.upcoming,
      background: CalendarPalette.upcomingSoft,
    ),
  };
}

class _NoInsightCard extends StatelessWidget {
  const _NoInsightCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            color: CalendarPalette.forest,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What Sakan Notices',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CalendarPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No recorded Moment needs special attention right now.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CalendarPalette.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallStatusChip extends StatelessWidget {
  const _SmallStatusChip({required this.visual});

  final _Visual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        visual.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: visual.color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetadataPill extends StatelessWidget {
  const _MetadataPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: CalendarPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CalendarPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: CalendarPalette.inkSoft),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: CalendarPalette.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietLine extends StatelessWidget {
  const _QuietLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: CalendarPalette.inkSoft),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: CalendarPalette.inkSoft),
          ),
        ),
      ],
    );
  }
}

class _UpcomingMomentEntry {
  const _UpcomingMomentEntry({
    required this.moment,
    required this.instance,
    required this.hasReminder,
  });

  final FamilyMoment moment;
  final MomentInstance instance;
  final bool hasReminder;
}

class _Visual {
  const _Visual({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;
}

class _CategoryVisual {
  const _CategoryVisual({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;
}

_Visual _rhythmVisual(RhythmStatus status) {
  return switch (status) {
    RhythmStatus.stillLearning => const _Visual(
      label: 'Still Learning',
      color: CalendarPalette.slate,
      background: CalendarPalette.slateSoft,
    ),
    RhythmStatus.stable => const _Visual(
      label: 'Stable',
      color: CalendarPalette.stable,
      background: CalendarPalette.stableSoft,
    ),
    RhythmStatus.drifting => const _Visual(
      label: 'Drifting',
      color: CalendarPalette.drifting,
      background: CalendarPalette.driftingSoft,
    ),
    RhythmStatus.recovering => const _Visual(
      label: 'Recovering',
      color: CalendarPalette.recovering,
      background: CalendarPalette.recoveringSoft,
    ),
    RhythmStatus.strengthening => const _Visual(
      label: 'Strengthening',
      color: CalendarPalette.strengthening,
      background: CalendarPalette.strengtheningSoft,
    ),
  };
}

_CategoryVisual _categoryVisual(MomentCategory category) {
  return switch (category) {
    MomentCategory.milestone => const _CategoryVisual(
      icon: Icons.star_border_rounded,
      color: CalendarPalette.milestone,
      background: CalendarPalette.milestoneSoft,
    ),
    MomentCategory.care ||
    MomentCategory.responsibility => const _CategoryVisual(
      icon: Icons.favorite_border_rounded,
      color: CalendarPalette.care,
      background: CalendarPalette.careSoft,
    ),
    _ => const _CategoryVisual(
      icon: Icons.event_outlined,
      color: CalendarPalette.upcoming,
      background: CalendarPalette.upcomingSoft,
    ),
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
