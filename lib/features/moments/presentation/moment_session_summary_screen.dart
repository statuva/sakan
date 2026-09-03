import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_insight_report.dart';
import '../../../shared/models/family_memory.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/models/rhythm_record.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../../digital_twin/services/digital_twin_interpretation_service.dart';
import '../../memories/presentation/add_memory_screen.dart';
import '../../memories/presentation/memory_details_screen.dart';
import 'widgets/moment_session_visuals.dart';

class MomentSessionSummaryScreen extends StatefulWidget {
  const MomentSessionSummaryScreen({
    required this.familyId,
    required this.instanceId,
    super.key,
  });

  final String familyId;
  final String instanceId;

  @override
  State<MomentSessionSummaryScreen> createState() =>
      _MomentSessionSummaryScreenState();
}

class _MomentSessionSummaryScreenState
    extends State<MomentSessionSummaryScreen> {
  static const DigitalTwinInterpretationService _interpretationService =
      DigitalTwinInterpretationService();

  CurrentFamilyContext? _familyContext;
  Stream<MomentInstance?>? _instanceStream;
  Stream<FamilyInsightReport>? _reportStream;

  bool _isLoading = true;
  bool _isOpeningMemory = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      if (familyContext.familyId != widget.familyId) {
        throw StateError('This Moment belongs to a different family.');
      }

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _instanceStream = AppDependencies.momentInstanceRepository
            .watchInstance(
              familyId: widget.familyId,
              instanceId: widget.instanceId,
            );
        _reportStream = AppDependencies.familyInsightService.watchReport();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is StateError
            ? error.message.toString()
            : 'We could not load the Moment summary.';
      });
    }
  }

  Future<void> _openMemory({
    required MomentInstance instance,
    required FamilyMoment moment,
    required FamilyMemory? memory,
  }) async {
    if (_isOpeningMemory) {
      return;
    }

    if (memory != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MemoryDetailsScreen(memory: memory),
        ),
      );
      return;
    }

    if (_familyContext?.isAdult != true) {
      return;
    }

    setState(() {
      _isOpeningMemory = true;
    });

    try {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) =>
              AddMemoryScreen(initialMoment: moment, initialInstance: instance),
        ),
      );

      if (saved == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Family Memory saved.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningMemory = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading Moment summary…'),
        ),
      );
    }

    if (_familyContext == null ||
        _instanceStream == null ||
        _reportStream == null) {
      return Scaffold(
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'The Moment summary is unavailable.',
            onRetry: _loadSummary,
          ),
        ),
      );
    }

    return StreamBuilder<MomentInstance?>(
      stream: _instanceStream,
      builder: (context, instanceSnapshot) {
        if (instanceSnapshot.hasError) {
          return _errorScaffold('We could not load this Moment occurrence.');
        }

        if (instanceSnapshot.connectionState == ConnectionState.waiting &&
            !instanceSnapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(message: 'Reading recorded outcomes…'),
            ),
          );
        }

        final instance = instanceSnapshot.data;

        if (instance == null) {
          return _errorScaffold('This Moment occurrence no longer exists.');
        }

        return StreamBuilder<FamilyInsightReport>(
          stream: _reportStream,
          builder: (context, reportSnapshot) {
            if (reportSnapshot.hasError) {
              return _errorScaffold('We could not update the Moment summary.');
            }

            if (reportSnapshot.connectionState == ConnectionState.waiting &&
                !reportSnapshot.hasData) {
              return const Scaffold(
                body: SafeArea(
                  child: AppLoadingState(
                    message: 'Updating the family rhythm…',
                  ),
                ),
              );
            }

            final report = reportSnapshot.data;

            if (report == null) {
              return _errorScaffold('The family report is unavailable.');
            }

            final moment =
                report.snapshot.momentById(instance.momentId) ??
                _definitionFromInstance(instance);
            final rhythm = report.snapshot.rhythmForMoment(instance.momentId);
            final memory = report.snapshot.memoryForInstance(instance.id);
            final instances = report.snapshot.instancesForMoment(
              instance.momentId,
            );

            return _buildSummary(
              instance: instance,
              moment: moment,
              rhythm: rhythm,
              memory: memory,
              instances: instances,
            );
          },
        );
      },
    );
  }

  Scaffold _buildSummary({
    required MomentInstance instance,
    required FamilyMoment moment,
    required RhythmRecord? rhythm,
    required FamilyMemory? memory,
    required List<MomentInstance> instances,
  }) {
    final durationMinutes = instance.actualDurationMinutes ?? 0;
    final recordedCount = instance.allRecordedParticipantIds.length;
    final expectedCount = instance.expectedParticipantIds.length;
    final interpretationText = moment.type == MomentType.recurring
        ? _interpretationService
              .interpretMoment(
                moment: moment,
                rhythm: rhythm,
                instances: instances,
              )
              .summary
        : 'This one-time Moment is now part of the family history. '
              'It is not used to calculate a recurring rhythm.';
    final summary = _sessionSummary(
      instance: instance,
      interpretation: interpretationText,
    );
    final completed = instance.status == MomentInstanceStatus.completed;
    final statusColor = completed ? AppColors.success : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  completed
                      ? Icons.celebration_outlined
                      : Icons.event_busy_outlined,
                  size: 36,
                  color: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              instance.titleSnapshot,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 2),
            Text(
              completed ? 'Complete!' : _statusLabel(instance.status),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: statusColor),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: momentSessionDurationLabel(durationMinutes),
                  ),
                  const Divider(height: 1),
                  _SummaryRow(
                    icon: Icons.group_outlined,
                    label: 'Participants',
                    value: '$recordedCount of $expectedCount',
                  ),
                  const Divider(height: 1),
                  _SummaryRow(
                    icon: Icons.verified_outlined,
                    label: 'Confirmation',
                    value: momentSessionConfirmationLabel(
                      instance.confirmationLevel,
                    ),
                  ),
                  const Divider(height: 1),
                  _SummaryRow(
                    icon: Icons.insights_outlined,
                    label: moment.type == MomentType.recurring
                        ? 'Current rhythm'
                        : 'Moment type',
                    value: moment.type == MomentType.recurring
                        ? momentSessionRhythmLabel(
                            rhythm?.status ?? RhythmStatus.stillLearning,
                          )
                        : 'One-time',
                  ),
                  const Divider(height: 1),
                  _SummaryRow(
                    icon: Icons.auto_stories_outlined,
                    label: 'Memory',
                    value: memory == null ? 'Not saved' : 'Saved',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF2E5),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.primary.withAlpha(45)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_outlined,
                      size: 19,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SAKAN SUMMARY',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          summary,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (completed && (memory != null || _familyContext!.isAdult)) ...[
              FilledButton(
                onPressed: _isOpeningMemory
                    ? null
                    : () {
                        _openMemory(
                          instance: instance,
                          moment: moment,
                          memory: memory,
                        );
                      },
                child: Text(memory == null ? 'Add Memory' : 'View Memory'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.linen,
                  foregroundColor: AppColors.textPrimary,
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sessionSummary({
    required MomentInstance instance,
    required String interpretation,
  }) {
    final count = instance.allRecordedParticipantIds.length;
    final expected = instance.expectedParticipantIds.length;
    final duration = momentSessionDurationLabel(
      instance.actualDurationMinutes ?? 0,
    );

    final facts = count == 0
        ? 'No participant check-in was recorded, and the session lasted $duration.'
        : '$count of $expected expected ${count == 1 ? 'member was' : 'members were'} recorded, and the session lasted $duration.';

    return '$facts $interpretation';
  }

  FamilyMoment _definitionFromInstance(MomentInstance instance) {
    return FamilyMoment(
      id: instance.momentId,
      familyId: instance.familyId,
      title: instance.titleSnapshot,
      type: instance.typeSnapshot,
      category: instance.categorySnapshot,
      importanceLevel: instance.importanceLevelSnapshot,
      expectedParticipantIds: instance.expectedParticipantIds,
      startAt: instance.scheduledStartAt,
      endAt: instance.scheduledEndAt,
      location: instance.locationSnapshot,
      evidenceType: EvidenceType.manual,
      status: MomentStatus.scheduled,
      createdBy: instance.createdBy,
      createdAt: instance.createdAt,
      updatedAt: instance.updatedAt,
    );
  }

  String _statusLabel(MomentInstanceStatus status) {
    return switch (status) {
      MomentInstanceStatus.proposed => 'Proposed',
      MomentInstanceStatus.scheduled => 'Scheduled',
      MomentInstanceStatus.inviting => 'Ready Room open',
      MomentInstanceStatus.active => 'Still active',
      MomentInstanceStatus.completed => 'Complete!',
      MomentInstanceStatus.missed => 'Missed',
      MomentInstanceStatus.cancelled => 'Cancelled',
    };
  }

  Scaffold _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moment Summary')),
      body: SafeArea(
        child: AppErrorState(message: message, onRetry: _loadSummary),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.secondary.withAlpha(18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: AppColors.secondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
