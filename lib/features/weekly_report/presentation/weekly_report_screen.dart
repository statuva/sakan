import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/ai/ai_models.dart';
import '../../../shared/utils/moment_visuals.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../domain/family_weekly_report.dart';
import '../services/family_weekly_report_builder.dart';
import '../services/family_weekly_report_snapshot_projector.dart';
import 'widgets/weekly_report_charts.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  CurrentFamilyContext? _familyContext;
  FamilyWeeklyReport? _report;
  Future<SakanAiResult>? _aiNarrative;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();
      if (!familyContext.isAdult) {
        throw StateError('Weekly family reports are available to adults only.');
      }

      final reportReference = DateTime.now();
      final insightReport = await AppDependencies.familyInsightService
          .loadReport();
      final reportSnapshot =
          FamilyWeeklyReportSnapshotProjector.projectLatestCompletedWeek(
            insightReport.snapshot,
            now: reportReference,
          );
      final report = FamilyWeeklyReportBuilder.buildLatestCompletedWeek(
        reportSnapshot,
        now: reportReference,
      );

      if (!mounted) return;
      setState(() {
        _familyContext = familyContext;
        _report = report;
        _aiNarrative = report.hasActivity && familyContext.canUseAi
            ? AppDependencies.sakanAiGateway.generate(
                feature: SakanAiFeature.weeklyReport,
                targetId: report.weekStart.toIso8601String().substring(0, 10),
                grounding: report.toAiPayload(),
              )
            : null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error is StateError
            ? error.message.toString()
            : 'We could not prepare the weekly family report.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Preparing the weekly report…'),
        ),
      );
    }

    final report = _report;
    if (_familyContext == null || report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Weekly Family Report')),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'The weekly report is unavailable.',
            onRetry: _load,
          ),
        ),
      );
    }

    final weekEnd = DateTime(
      report.weekEndExclusive.year,
      report.weekEndExclusive.month,
      report.weekEndExclusive.day - 1,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Weekly Family Report'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.huge,
          ),
          children: [
            Text(
              '${DateFormat('d MMM').format(report.weekStart)}–'
              '${DateFormat('d MMM y').format(weekEnd)}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _WeeklyAiNarrative(
              report: report,
              narrative: _aiNarrative,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!report.hasActivity)
              const _EmptyWeekCard()
            else ...[
              _WeekOverviewCard(report: report),
              const SizedBox(height: AppSpacing.lg),
              _SectionCard(
                title: 'Moment activity',
                subtitle:
                    'Recorded outcomes for each day in the completed week.',
                child: WeeklyActivityChart(days: report.dailyActivity),
              ),
              const SizedBox(height: AppSpacing.lg),
              _PatternSection(patterns: report.momentPatterns),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeeklyAiNarrative extends StatelessWidget {
  const _WeeklyAiNarrative({
    required this.report,
    required this.narrative,
  });

  final FamilyWeeklyReport report;
  final Future<SakanAiResult>? narrative;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SakanAiResult>(
      future: narrative,
      builder: (context, snapshot) {
        final ai = snapshot.data;
        final observations = ai?.reasons ?? const <String>[];
        final nextSteps = ai?.suggestedActions ?? const <String>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ai?.title ?? report.headline,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ai?.text ?? report.interpretation,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (snapshot.hasError) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'AI interpretation is unavailable right now. '
                'The calculated report below is still available.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (observations.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _SectionCard(
                title: 'What Sakan noticed',
                subtitle: 'AI interpretation grounded in the numbers below.',
                child: Column(
                  children: observations
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.insights_outlined,
                                size: 19,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: Text(item)),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
            if (nextSteps.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _SectionCard(
                title: 'A gentle focus for next week',
                subtitle: 'Suggestions only. Nothing is scheduled automatically.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: nextSteps
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text('• $item'),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
            if (ai != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'AI-generated interpretation · charts and totals are calculated by Sakan',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _WeekOverviewCard extends StatelessWidget {
  const _WeekOverviewCard({required this.report});

  final FamilyWeeklyReport report;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Week at a glance',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(child: WeeklyCompletionChart(report: report)),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MetricTile(
                label: 'Occurrences',
                value: '${report.occurrenceCount}',
                color: AppColors.primary,
              ),
              _MetricTile(
                label: 'Completed',
                value: '${report.completedCount}',
                color: AppColors.success,
              ),
              _MetricTile(
                label: 'Missed',
                value: '${report.missedCount}',
                color: AppColors.error,
              ),
              _MetricTile(
                label: 'Unresolved',
                value: '${report.pendingReviewCount}',
                color: AppColors.info,
              ),
              _MetricTile(
                label: 'Participation',
                value: report.participationRate == null
                    ? '—'
                    : '${(report.participationRate! * 100).round()}%',
                color: AppColors.secondary,
              ),
              _MetricTile(
                label: 'Recorded time',
                value: report.totalDurationMinutes == null
                    ? '—'
                    : _durationLabel(report.totalDurationMinutes!),
                color: AppColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _PatternSection extends StatelessWidget {
  const _PatternSection({required this.patterns});

  final List<WeeklyMomentPattern> patterns;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recurring pattern interpretation',
      subtitle:
          'How this week’s recorded evidence relates to each current rhythm.',
      child: patterns.isEmpty
          ? Text(
              'No recurring Moment had an occurrence during this week.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          : Column(
              children: patterns.indexed
                  .map((entry) {
                    final pattern = entry.$2;
                    return Column(
                      children: [
                        _PatternTile(pattern: pattern),
                        if (entry.$1 != patterns.length - 1)
                          const Divider(height: AppSpacing.xl),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
    );
  }
}

class _PatternTile extends StatelessWidget {
  const _PatternTile({required this.pattern});

  final WeeklyMomentPattern pattern;

  @override
  Widget build(BuildContext context) {
    final status = pattern.rhythmStatus;
    final completionRate = pattern.completionRate;
    final statusColor = status == null
        ? AppColors.stillLearning
        : rhythmStatusColor(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pattern.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status == null ? 'Not enough data' : rhythmStatusLabel(status),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          pattern.explanation,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          completionRate == null
              ? 'No resolved outcomes this week'
              : '${(completionRate * 100).round()}% of resolved occurrences '
                    'were completed',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressIndicator(
          value: completionRate ?? 0,
          minHeight: 7,
          borderRadius: BorderRadius.circular(999),
          color: _effectColor(pattern.effect),
          backgroundColor: AppColors.linen,
        ),
      ],
    );
  }

  Color _effectColor(WeeklyPatternEffect effect) {
    return switch (effect) {
      WeeklyPatternEffect.supported => AppColors.success,
      WeeklyPatternEffect.mixed => AppColors.warning,
      WeeklyPatternEffect.underPressure => AppColors.error,
      WeeklyPatternEffect.noNewEvidence => AppColors.stillLearning,
    };
  }
}

class _EmptyWeekCard extends StatelessWidget {
  const _EmptyWeekCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 52,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No Moments were recorded for this completed week.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Scheduled or recorded Moment activity from the current week '
            'will appear in the next report.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
