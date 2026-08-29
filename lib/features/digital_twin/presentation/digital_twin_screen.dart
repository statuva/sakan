import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/family_insight_report.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/models/rhythm_record.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../../moments/presentation/live_moment_screen.dart';
import '../../moments/presentation/moment_session_summary_screen.dart';

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
      // Validate the current family before starting the combined stream.
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
          child: AppLoadingState(message: 'Building the family pattern view…'),
        ),
      );
    }

    if (_reportStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Digital Twin')),
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
            appBar: AppBar(title: const Text('Family Digital Twin')),
            body: SafeArea(
              child: AppErrorState(
                message: 'We could not update the family pattern view.',
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
                message: 'Reading confirmed family rhythms…',
              ),
            ),
          );
        }

        final report = snapshot.data;

        if (report == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Family Digital Twin')),
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
    final metrics = report.metrics;
    final activeInstance = snapshot.activeInstance;
    final recentSessions = snapshot.completedInstances.take(4).toList();

    final rhythms = List<RhythmRecord>.from(snapshot.rhythms)
      ..sort((first, second) {
        final statusResult = _rhythmRank(
          first.status,
        ).compareTo(_rhythmRank(second.status));

        if (statusResult != 0) {
          return statusResult;
        }

        return second.currentGapDays.compareTo(first.currentGapDays);
      });

    final insights = <FamilyInsightItem>[
      if (report.primaryInsight != null) report.primaryInsight!,
      ...report.secondaryInsights,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Digital Twin'),
        actions: [
          IconButton(
            tooltip: 'Open Calendar',
            onPressed: () {
              context.go('/calendar');
            },
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            112,
          ),
          children: [
            _OverallStateCard(report: report),

            if (activeInstance != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _ActiveTwinCard(
                instance: activeInstance,
                onOpen: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LiveMomentScreen(
                        familyId: activeInstance.familyId,
                        instanceId: activeInstance.id,
                      ),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            Text(
              'Recorded Family Activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: AppSpacing.md),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.45,
              children: [
                _MetricCard(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Completed Sessions',
                  value: '${metrics.completedInstanceCount}',
                ),
                _MetricCard(
                  icon: Icons.event_busy_outlined,
                  label: 'Missed Occurrences',
                  value: '${metrics.missedInstanceCount}',
                ),
                _MetricCard(
                  icon: Icons.trending_down_rounded,
                  label: 'Drifting Rhythms',
                  value: '${metrics.driftingRhythmCount}',
                ),
                _MetricCard(
                  icon: Icons.auto_stories_outlined,
                  label: 'Saved Memories',
                  value: '${metrics.memoryCount}',
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Family Rhythms',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${rhythms.length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            if (rhythms.isEmpty)
              const AppCard(
                child: Text(
                  'Sakan is still waiting for recurring Moment data.',
                ),
              )
            else
              ...rhythms.take(6).map((rhythm) {
                final moment = snapshot.momentById(rhythm.momentId);

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _RhythmCard(
                    title: moment?.title ?? 'Family Rhythm',
                    rhythm: rhythm,
                  ),
                );
              }),

            const SizedBox(height: AppSpacing.xl),

            Text(
              'Recent Confirmed Sessions',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: AppSpacing.md),

            if (recentSessions.isEmpty)
              const AppCard(
                child: Text(
                  'Complete a live Moment or Today Review to build this history.',
                ),
              )
            else
              ...recentSessions.map(
                (instance) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _RecentSessionCard(
                    instance: instance,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MomentSessionSummaryScreen(
                            familyId: instance.familyId,
                            instanceId: instance.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.xl),

            Text(
              'What Sakan Notices',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: AppSpacing.md),

            if (insights.isEmpty)
              const AppCard(
                child: Text('No major pattern needs attention right now.'),
              )
            else
              ...insights
                  .take(4)
                  .map(
                    (insight) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _TwinInsightCard(
                        insight: insight,
                        onTap: () {
                          context.go('/calendar');
                        },
                      ),
                    ),
                  ),

            const SizedBox(height: AppSpacing.xl),

            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What this Twin means',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'This screen summarizes recorded occurrences, '
                          'check-ins, reminders, Memories, and rhythm history. '
                          'It does not measure family happiness or make a '
                          'psychological judgment.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
}

class _OverallStateCard extends StatelessWidget {
  const _OverallStateCard({required this.report});

  final FamilyInsightReport report;

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(report.overallState);

    return AppCard(
      color: color.withAlpha(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.account_tree_outlined, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Recorded Pattern',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _stateLabel(report.overallState),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: color, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_confidenceLabel(report.overallConfidence)} confidence',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _stateDescription(report.overallState),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  static Color _stateColor(FamilyOverallState state) {
    return switch (state) {
      FamilyOverallState.stillLearning => const Color(0xFF6F7E8D),
      FamilyOverallState.stable => const Color(0xFF1C9A6A),
      FamilyOverallState.drifting => const Color(0xFFC97A13),
      FamilyOverallState.recovering => const Color(0xFF356FD6),
      FamilyOverallState.strengthening => const Color(0xFF0D8B80),
    };
  }

  static String _stateLabel(FamilyOverallState state) {
    return switch (state) {
      FamilyOverallState.stillLearning => 'Still Learning',
      FamilyOverallState.stable => 'Stable',
      FamilyOverallState.drifting => 'Drifting',
      FamilyOverallState.recovering => 'Recovering',
      FamilyOverallState.strengthening => 'Strengthening',
    };
  }

  static String _stateDescription(FamilyOverallState state) {
    return switch (state) {
      FamilyOverallState.stillLearning =>
        'Sakan needs more confirmed occurrences before it can describe the family rhythms with confidence.',
      FamilyOverallState.stable =>
        'The currently recorded recurring Moments are close to their expected patterns.',
      FamilyOverallState.drifting =>
        'At least one recorded family rhythm has moved beyond its expected pattern or has a missed occurrence.',
      FamilyOverallState.recovering =>
        'A previously drifting rhythm has received a new confirmed occurrence within its expected range.',
      FamilyOverallState.strengthening =>
        'Repeated confirmed occurrences are becoming more consistent than the earlier record.',
    };
  }

  static String _confidenceLabel(ConfidenceLevel level) {
    return switch (level) {
      ConfidenceLevel.low => 'Low',
      ConfidenceLevel.medium => 'Medium',
      ConfidenceLevel.high => 'High',
    };
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ActiveTwinCard extends StatelessWidget {
  const _ActiveTwinCard({required this.instance, required this.onOpen});

  final MomentInstance instance;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      color: const Color(0xFFE2F5F2),
      child: Row(
        children: [
          const Icon(
            Icons.play_circle_fill_rounded,
            color: Color(0xFF0D8B80),
            size: 34,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE FAMILY MOMENT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF0D8B80),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  instance.titleSnapshot,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  '${instance.allRecordedParticipantIds.length} participating · Tap to join',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _RhythmCard extends StatelessWidget {
  const _RhythmCard({required this.title, required this.rhythm});

  final String title;
  final RhythmRecord rhythm;

  @override
  Widget build(BuildContext context) {
    final color = _rhythmColor(rhythm.status);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withAlpha(22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _rhythmLabel(rhythm.status),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            rhythm.lastOccurrenceAt == null
                ? 'No confirmed occurrence yet'
                : '${rhythm.currentGapDays} days since the last confirmed occurrence',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Expected every ${rhythm.expectedIntervalDays} days · '
            '${rhythm.occurrenceCount} confirmed · '
            '${_confidenceLabel(rhythm.confidence)} confidence',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static Color _rhythmColor(RhythmStatus status) {
    return switch (status) {
      RhythmStatus.stillLearning => const Color(0xFF6F7E8D),
      RhythmStatus.stable => const Color(0xFF1C9A6A),
      RhythmStatus.drifting => const Color(0xFFC97A13),
      RhythmStatus.recovering => const Color(0xFF356FD6),
      RhythmStatus.strengthening => const Color(0xFF0D8B80),
    };
  }

  static String _rhythmLabel(RhythmStatus status) {
    return switch (status) {
      RhythmStatus.stillLearning => 'Still Learning',
      RhythmStatus.stable => 'Stable',
      RhythmStatus.drifting => 'Drifting',
      RhythmStatus.recovering => 'Recovering',
      RhythmStatus.strengthening => 'Strengthening',
    };
  }

  static String _confidenceLabel(ConfidenceLevel level) {
    return switch (level) {
      ConfidenceLevel.low => 'Low',
      ConfidenceLevel.medium => 'Medium',
      ConfidenceLevel.high => 'High',
    };
  }
}

class _RecentSessionCard extends StatelessWidget {
  const _RecentSessionCard({required this.instance, required this.onTap});

  final MomentInstance instance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = instance.effectiveStartAt.toLocal();

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F5EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.check_rounded, color: Color(0xFF1C9A6A)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instance.titleSnapshot,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '${DateFormat('d MMM y').format(date)} · '
                  '${instance.actualDurationMinutes ?? 0} min · '
                  '${instance.allRecordedParticipantIds.length} recorded',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            _confirmationLabel(instance.confirmationLevel),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  static String _confirmationLabel(MomentConfirmationLevel level) {
    return switch (level) {
      MomentConfirmationLevel.low => 'Low evidence',
      MomentConfirmationLevel.medium => 'Medium',
      MomentConfirmationLevel.high => 'High',
    };
  }
}

class _TwinInsightCard extends StatelessWidget {
  const _TwinInsightCard({required this.insight, required this.onTap});

  final FamilyInsightItem insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.headline,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  insight.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (insight.primaryActionLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${insight.primaryActionLabel} in Calendar',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
