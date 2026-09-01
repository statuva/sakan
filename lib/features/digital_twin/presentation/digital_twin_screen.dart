import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/family_insight_report.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/rhythm_record.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../../calendar/presentation/widgets/calendar_palette.dart';
import '../domain/digital_twin_interpretation.dart';
import '../domain/twin_simulation_result.dart';
import '../services/digital_twin_interpretation_service.dart';
import '../services/digital_twin_simulation_service.dart';
import 'digital_twin_visuals.dart';
import 'widgets/family_twin_map.dart';
import 'widgets/family_twin_node_sheet.dart';
import 'widgets/simulated_moment_pattern_card.dart';
import 'widgets/simulation_banner.dart';
import 'widgets/simulation_exit_button.dart';
import 'widgets/simulation_node_sheet.dart';
import 'widgets/what_if_scenario_sheet.dart';

class DigitalTwinScreen extends StatefulWidget {
  const DigitalTwinScreen({super.key});

  @override
  State<DigitalTwinScreen> createState() => _DigitalTwinScreenState();
}

class _DigitalTwinScreenState extends State<DigitalTwinScreen> {
  static const DigitalTwinInterpretationService _interpretationService =
      DigitalTwinInterpretationService();

  static const DigitalTwinSimulationService _simulationService =
      DigitalTwinSimulationService();

  Stream<FamilyInsightReport>? _reportStream;

  DigitalTwinSimulationResult? _activeSimulation;
  FamilyInsightReport? _simulationBaseReport;

  bool _isLoading = true;
  bool _isRunningSimulation = false;
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

  Future<void> _openWhatIfBuilder(FamilyInsightReport report) async {
    if (_isRunningSimulation) {
      return;
    }

    final scenario = await showWhatIfScenarioSheet(
      context: context,
      report: report,
    );

    if (scenario == null || !mounted) {
      return;
    }

    setState(() {
      _isRunningSimulation = true;
    });

    try {
      // Keeps the transition visible and leaves room for a future protected
      // AI parser without changing the simulation-state contract.
      await Future<void>.delayed(const Duration(milliseconds: 180));

      final result = _simulationService.simulate(
        baseReport: report,
        scenario: scenario,
      );

      if (!mounted) return;

      setState(() {
        _simulationBaseReport = report;
        _activeSimulation = result;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError || error is ArgumentError
                ? error.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), '')
                : 'We could not run this simulation.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRunningSimulation = false;
        });
      }
    }
  }

  void _exitSimulation() {
    setState(() {
      _activeSimulation = null;
      _simulationBaseReport = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Building the family Moment map…'),
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
                message: 'Reading recorded family patterns…',
              ),
            ),
          );
        }

        final liveReport = snapshot.data;

        if (liveReport == null) {
          return Scaffold(
            body: SafeArea(
              child: AppErrorState(
                message: 'No Digital Twin report is available yet.',
                onRetry: _loadTwin,
              ),
            ),
          );
        }

        final displayReport = _activeSimulation == null
            ? liveReport
            : _simulationBaseReport ?? liveReport;

        return _buildTwin(
          context: context,
          report: displayReport,
          simulation: _activeSimulation,
        );
      },
    );
  }

  Widget _buildTwin({
    required BuildContext context,
    required FamilyInsightReport report,
    required DigitalTwinSimulationResult? simulation,
  }) {
    final snapshot = report.snapshot;
    final displayMoments = simulation?.simulatedMoments ?? snapshot.moments;

    final recurringMoments =
        displayMoments
            .where((moment) => moment.type == MomentType.recurring)
            .toList()
          ..sort((first, second) {
            final firstChanged =
                simulation?.changedMomentIds.contains(first.id) ?? false;
            final secondChanged =
                simulation?.changedMomentIds.contains(second.id) ?? false;

            if (firstChanged != secondChanged) {
              return firstChanged ? -1 : 1;
            }

            final statusResult =
                _rhythmRank(
                  _statusForMoment(
                    report: report,
                    simulation: simulation,
                    moment: first,
                  ),
                ).compareTo(
                  _rhythmRank(
                    _statusForMoment(
                      report: report,
                      simulation: simulation,
                      moment: second,
                    ),
                  ),
                );

            return statusResult != 0
                ? statusResult
                : first.title.compareTo(second.title);
          });

    final familyInterpretation = simulation == null
        ? _interpretationService.interpretFamily(
            moments: snapshot.moments,
            rhythms: snapshot.rhythms,
            instances: snapshot.instances,
          )
        : null;

    final body = ListView(
      key: ValueKey<String>(simulation?.id ?? 'recorded-digital-twin'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        simulation == null ? 118 : 196,
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
          simulation == null ? 'Digital Twin' : 'Digital Twin Simulation',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: CalendarPalette.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          simulation == null
              ? 'Understand how each recurring family Moment is changing over time.'
              : 'Explore one projected change without modifying the family’s real data.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: CalendarPalette.inkSoft,
            height: 1.4,
          ),
        ),
        if (simulation != null) ...[
          const SizedBox(height: AppSpacing.lg),
          SimulationBanner(simulation: simulation),
        ],
        const SizedBox(height: AppSpacing.lg),
        FamilyTwinMap(
          key: ValueKey<String>(simulation?.id ?? 'actual-map'),
          report: report,
          simulation: simulation,
          onMemberTap: (member) {
            if (simulation == null) {
              unawaited(
                showFamilyTwinMemberSheet(
                  context: context,
                  report: report,
                  member: member,
                ),
              );
              return;
            }

            unawaited(
              showTwinSimulationMemberSheet(
                context: context,
                baseReport: report,
                simulation: simulation,
                member: member,
              ),
            );
          },
          onMomentTap: (moment, rhythm, instances) {
            if (simulation == null) {
              unawaited(
                showFamilyTwinMomentSheet(
                  context: context,
                  report: report,
                  moment: moment,
                  rhythm: rhythm,
                  instances: instances,
                ),
              );
              return;
            }

            unawaited(
              showTwinSimulationMomentSheet(
                context: context,
                baseReport: report,
                simulation: simulation,
                moment: moment,
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        _SectionHeading(
          title: simulation == null ? 'Moment Patterns' : 'Projected Patterns',
          subtitle: simulation == null
              ? 'Each recurring Moment has its own pattern. Tap one for the interpretation and supporting evidence.'
              : 'Changed Moments compare the recorded state with this projection. Unaffected Moments remain visible but muted.',
        ),
        const SizedBox(height: AppSpacing.md),
        if (recurringMoments.isEmpty)
          const AppCard(
            child: Text('No recurring Family Moments have been added yet.'),
          )
        else
          ...recurringMoments.map((moment) {
            final rhythm = snapshot.rhythmForMoment(moment.id);
            final instances = snapshot.instancesForMoment(moment.id);
            final participants = _participantNames(
              moment: moment,
              membersById: snapshot.membersById,
            );
            final pattern = simulation?.patternForMoment(moment.id);
            final isAffected = pattern?.isAffected == true;

            final card = isAffected
                ? SimulatedMomentPatternCard(
                    moment: moment,
                    pattern: pattern!,
                    participantNames: participants,
                    onTap: () {
                      unawaited(
                        showTwinSimulationMomentSheet(
                          context: context,
                          baseReport: report,
                          simulation: simulation!,
                          moment: moment,
                        ),
                      );
                    },
                  )
                : _MomentPatternCard(
                    moment: moment,
                    rhythm: rhythm,
                    interpretation: _interpretationService.interpretMoment(
                      moment: moment,
                      rhythm: rhythm,
                      instances: instances,
                    ),
                    participantNames: participants,
                    onTap: () {
                      if (simulation == null) {
                        unawaited(
                          showFamilyTwinMomentSheet(
                            context: context,
                            report: report,
                            moment: moment,
                            rhythm: rhythm,
                            instances: instances,
                          ),
                        );
                      } else {
                        unawaited(
                          showTwinSimulationMomentSheet(
                            context: context,
                            baseReport: report,
                            simulation: simulation,
                            moment: moment,
                          ),
                        );
                      }
                    },
                  );

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: simulation != null && !isAffected
                  ? Opacity(opacity: 0.52, child: card)
                  : card,
            );
          }),
        const SizedBox(height: AppSpacing.xl),
        if (simulation == null)
          _FamilyLearningCard(interpretation: familyInterpretation!)
        else
          _SimulationLearningCard(simulation: simulation),
        if (simulation == null) ...[
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isRunningSimulation
                  ? null
                  : () => _openWhatIfBuilder(report),
              icon: _isRunningSimulation
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                _isRunningSimulation
                    ? 'Running Simulation…'
                    : 'Ask “What if…?”',
              ),
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
      ],
    );

    return Scaffold(
      backgroundColor: CalendarPalette.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: body,
              ),
            ),
            if (simulation != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 90,
                child: Center(
                  child: SimulationExitButton(onPressed: _exitSimulation),
                ),
              ),
          ],
        ),
      ),
    );
  }

  RhythmStatus _statusForMoment({
    required FamilyInsightReport report,
    required DigitalTwinSimulationResult? simulation,
    required FamilyMoment moment,
  }) {
    return simulation?.patternForMoment(moment.id)?.projectedStatus ??
        report.snapshot.rhythmForMoment(moment.id)?.status ??
        RhythmStatus.stillLearning;
  }

  List<String> _participantNames({
    required FamilyMoment moment,
    required Map<String, Member> membersById,
  }) {
    final names = moment.expectedParticipantIds
        .map((id) => membersById[id]?.displayName)
        .whereType<String>()
        .toList();

    names.sort();
    return names;
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
    required this.interpretation,
    required this.participantNames,
    required this.onTap,
  });

  final FamilyMoment moment;
  final RhythmRecord? rhythm;
  final MomentTwinInterpretation interpretation;
  final List<String> participantNames;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = rhythm?.status ?? RhythmStatus.stillLearning;
    final confidence = rhythm?.confidence ?? ConfidenceLevel.low;
    final visual = twinRhythmVisual(status);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  twinCategoryIcon(moment.category),
                  size: 20,
                  color: visual.color,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  moment.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CalendarPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _StatusChip(visual: visual),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            interpretation.summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CalendarPalette.inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
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
              const SizedBox(width: 8),
              Text(
                twinConfidenceLabel(confidence),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: visual.color,
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
    );
  }

  String _participantLine(List<String> names) {
    if (names.length <= 4) {
      return names.join(' · ');
    }

    return '${names.take(4).join(' · ')} +${names.length - 4}';
  }
}

class _FamilyLearningCard extends StatelessWidget {
  const _FamilyLearningCard({required this.interpretation});

  final FamilyTwinInterpretation interpretation;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = switch (interpretation.origin) {
      DigitalTwinInterpretationOrigin.externalAi => 'AI interpretation',
      DigitalTwinInterpretationOrigin.ruleBasedFallback =>
        'Recorded-data summary',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CalendarPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LearningHeader(
            icon: Icons.insights_outlined,
            title: 'WHAT SAKAN IS LEARNING',
            subtitle: sourceLabel,
            color: CalendarPalette.forestDark,
            background: CalendarPalette.forestSoft,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            interpretation.summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: CalendarPalette.ink,
              height: 1.5,
            ),
          ),
          if (interpretation.themes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _ThemeWrap(
              themes: interpretation.themes,
              color: CalendarPalette.forestDark,
              background: CalendarPalette.forestSoft,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            'This describes recorded Moment patterns. It does not score family '
            'wellbeing or individual relationships.',
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

class _SimulationLearningCard extends StatelessWidget {
  const _SimulationLearningCard({required this.simulation});

  final DigitalTwinSimulationResult simulation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CalendarPalette.milestone.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LearningHeader(
            icon: Icons.science_outlined,
            title: 'WHAT THIS SIMULATION SUGGESTS',
            subtitle: 'Local projection · no data saved',
            color: CalendarPalette.milestone,
            background: CalendarPalette.milestoneSoft,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            simulation.familySummary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: CalendarPalette.ink,
              height: 1.5,
            ),
          ),
          if (simulation.familyThemes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _ThemeWrap(
              themes: simulation.familyThemes,
              color: CalendarPalette.milestone,
              background: CalendarPalette.milestoneSoft,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.fact_check_outlined,
                color: CalendarPalette.inkSoft,
              ),
              title: const Text('Projection assumptions'),
              children: simulation.assumptions
                  .map(
                    (assumption) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 7),
                            child: SizedBox(
                              width: 5,
                              height: 5,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: CalendarPalette.milestone,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              assumption,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: CalendarPalette.inkSoft,
                                    height: 1.4,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningHeader extends StatelessWidget {
  const _LearningHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: CalendarPalette.inkSoft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeWrap extends StatelessWidget {
  const _ThemeWrap({
    required this.themes,
    required this.color,
    required this.background,
  });

  final List<String> themes;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: themes
          .map(
            (theme) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                theme,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.visual});

  final TwinStatusVisual visual;

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
