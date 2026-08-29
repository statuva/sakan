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
import '../services/digital_twin_interpretation_service.dart';
import 'digital_twin_visuals.dart';
import 'widgets/family_twin_map.dart';
import 'widgets/family_twin_node_sheet.dart';

class DigitalTwinScreen extends StatefulWidget {
  const DigitalTwinScreen({super.key});

  @override
  State<DigitalTwinScreen> createState() => _DigitalTwinScreenState();
}

class _DigitalTwinScreenState extends State<DigitalTwinScreen> {
  static const DigitalTwinInterpretationService _interpretationService =
      DigitalTwinInterpretationService();

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

        return _buildTwin(context: context, report: report);
      },
    );
  }

  Widget _buildTwin({
    required BuildContext context,
    required FamilyInsightReport report,
  }) {
    final snapshot = report.snapshot;

    final recurringMoments =
        snapshot.moments
            .where((moment) => moment.type == MomentType.recurring)
            .toList()
          ..sort((first, second) {
            final firstStatus =
                snapshot.rhythmForMoment(first.id)?.status ??
                RhythmStatus.stillLearning;

            final secondStatus =
                snapshot.rhythmForMoment(second.id)?.status ??
                RhythmStatus.stillLearning;

            final statusResult = _rhythmRank(
              firstStatus,
            ).compareTo(_rhythmRank(secondStatus));

            if (statusResult != 0) {
              return statusResult;
            }

            return first.title.compareTo(second.title);
          });

    final familyInterpretation = _interpretationService.interpretFamily(
      moments: snapshot.moments,
      rhythms: snapshot.rhythms,
      instances: snapshot.instances,
    );

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
              'Understand how each recurring family Moment is changing over time.',
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
            const _SectionHeading(
              title: 'Moment Patterns',
              subtitle:
                  'Each recurring Moment has its own pattern. Tap one for the interpretation and supporting evidence.',
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

                final interpretation = _interpretationService.interpretMoment(
                  moment: moment,
                  rhythm: rhythm,
                  instances: instances,
                );

                final participants = _participantNames(
                  moment: moment,
                  membersById: snapshot.membersById,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _MomentPatternCard(
                    moment: moment,
                    rhythm: rhythm,
                    interpretation: interpretation,
                    participantNames: participants,
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
            const SizedBox(height: AppSpacing.xl),
            _FamilyLearningCard(interpretation: familyInterpretation),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showWhatIfPlaceholder,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Ask “What if…?”'),
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

  Future<void> _showWhatIfPlaceholder() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Ask “What if…?”'),
          content: const Text(
            'This feature will later let your family explore how changing a Moment’s timing, frequency, or participants could affect its recorded rhythm. No simulation or AI request is running yet.',
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
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: CalendarPalette.forestSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.insights_outlined,
                  color: CalendarPalette.forestDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WHAT SAKAN IS LEARNING',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: CalendarPalette.forestDark,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sourceLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CalendarPalette.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: interpretation.themes
                  .map(
                    (theme) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: CalendarPalette.forestSoft,
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
          const SizedBox(height: AppSpacing.lg),
          Text(
            'This describes recorded Moment patterns. '
            'It does not score family wellbeing or individual relationships.',
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
