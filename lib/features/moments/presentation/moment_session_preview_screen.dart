import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/availability_block.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../services/moment_conversation_prompt_library.dart';
import '../services/moment_session_preparation_service.dart';
import '../services/moment_session_timing_service.dart';
import 'live_moment_screen.dart';
import 'moment_waiting_room_screen.dart';
import 'widgets/moment_session_visuals.dart';

Future<void> openMomentSessionPreview({
  required BuildContext context,
  required FamilyMoment moment,
  required MomentInstanceSource source,
  MomentInstance? existingInstance,
  bool saveDefinitionBeforeStart = false,
  bool replaceCurrentRoute = false,
  bool useRootNavigator = true,
}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => MomentSessionPreviewScreen(
      moment: moment,
      source: source,
      existingInstance: existingInstance,
      saveDefinitionBeforeStart: saveDefinitionBeforeStart,
    ),
  );

  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);

  if (replaceCurrentRoute) {
    return navigator.pushReplacement<void, void>(route);
  }

  return navigator.push<void>(route);
}

class MomentSessionPreviewScreen extends StatefulWidget {
  const MomentSessionPreviewScreen({
    required this.moment,
    required this.source,
    this.existingInstance,
    this.saveDefinitionBeforeStart = false,
    super.key,
  });

  final FamilyMoment moment;
  final MomentInstanceSource source;
  final MomentInstance? existingInstance;
  final bool saveDefinitionBeforeStart;

  @override
  State<MomentSessionPreviewScreen> createState() =>
      _MomentSessionPreviewScreenState();
}

class _MomentSessionPreviewScreenState
    extends State<MomentSessionPreviewScreen> {
  final MomentSessionPreparationService _preparationService =
      MomentSessionPreparationService();

  CurrentFamilyContext? _familyContext;
  Stream<List<AvailabilityBlock>>? _availabilityStream;

  bool _isLoading = true;
  bool _isPreparing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      if (familyContext.familyId != widget.moment.familyId) {
        throw StateError('This Moment belongs to a different family.');
      }

      if (!familyContext.isAdult) {
        throw StateError(
          'Only an adult or family admin can prepare a shared Moment.',
        );
      }

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _availabilityStream = AppDependencies.scheduleRepository
            .watchFamilyAvailability(familyId: familyContext.familyId);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is StateError
            ? error.message.toString()
            : 'We could not prepare this Moment.';
      });
    }
  }

  Future<void> _getReady() async {
    final familyContext = _familyContext;

    if (familyContext == null || _isPreparing) {
      return;
    }

    setState(() {
      _isPreparing = true;
    });

    try {
      final prepared = await _preparationService.prepare(
        moment: widget.moment,
        preparedBy: familyContext.userId,
        source: widget.source,
        existingInstanceId: widget.existingInstance?.id,
      );

      if (!mounted) return;

      final active = await Navigator.of(context).push<MomentInstance>(
        MaterialPageRoute<MomentInstance>(
          builder: (_) => MomentWaitingRoomScreen(
            moment: widget.moment,
            source: widget.source,
            preparedSession: prepared,
            saveDefinitionBeforeStart: widget.saveDefinitionBeforeStart,
          ),
        ),
      );

      if (!mounted || active == null) {
        return;
      }

      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => LiveMomentScreen(
            familyId: active.familyId,
            instanceId: active.id,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'We could not open the Ready Room.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPreparing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Preparing the session preview…'),
        ),
      );
    }

    if (_familyContext == null || _availabilityStream == null) {
      return Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'The session preview is unavailable.',
            onRetry: _loadPreview,
          ),
        ),
      );
    }

    return StreamBuilder<List<AvailabilityBlock>>(
      stream: _availabilityStream,
      builder: (context, snapshot) {
        final availability = snapshot.data ?? const <AvailabilityBlock>[];

        return _buildPreview(availability);
      },
    );
  }

  Widget _buildPreview(List<AvailabilityBlock> availability) {
    final moment = widget.moment;
    final plannedStart =
        widget.existingInstance == null &&
            widget.source == MomentInstanceSource.spontaneous
        ? DateTime.now()
        : momentSessionPlannedStart(
            moment: moment,
            instance: widget.existingInstance,
          );
    final durationMinutes = momentSessionPlannedDurationMinutes(
      moment: moment,
      instance: widget.existingInstance,
    );
    final plannedEnd =
        widget.existingInstance == null &&
            widget.source == MomentInstanceSource.spontaneous
        ? plannedStart.add(Duration(minutes: durationMinutes))
        : momentSessionPlannedEnd(
            moment: moment,
            instance: widget.existingInstance,
          );
    final timingNote = MomentSessionTimingService.build(
      expectedParticipantIds: moment.expectedParticipantIds,
      availability: availability,
      start: plannedStart,
      end: plannedEnd,
    );
    final categoryColor = momentSessionCategoryColor(moment.category);
    final conversationPrompt = MomentConversationPromptLibrary.promptFor(
      moment: moment,
      date: DateTime.now(),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Session Preview'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            112,
          ),
          children: [
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: categoryColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    momentSessionCategoryIcon(moment.category),
                    color: categoryColor,
                    size: 27,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        momentSessionDateLabel(plannedStart),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        moment.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (timingNote != null) ...[
              const SizedBox(height: AppSpacing.xl),
              _TimingNoteCard(note: timingNote),
            ],
            const SizedBox(height: AppSpacing.md),
            _SessionFactsCard(
              durationLabel: momentSessionDurationLabel(durationMinutes),
              participantCount: moment.expectedParticipantIds.length,
              rhythmLabel: momentSessionFrequencyLabel(moment),
            ),
            const SizedBox(height: AppSpacing.md),
            _SoftInformationCard(
              icon: Icons.favorite_border_rounded,
              eyebrow: 'Moment intention',
              text: MomentConversationPromptLibrary.intentionFor(moment),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SoftInformationCard(
              icon: Icons.chat_bubble_outline_rounded,
              eyebrow: 'Optional conversation starter',
              text: '“$conversationPrompt”',
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: FilledButton(
          onPressed: _isPreparing ? null : _getReady,
          child: _isPreparing
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : const Text('Get Ready'),
        ),
      ),
    );
  }
}

class _TimingNoteCard extends StatelessWidget {
  const _TimingNoteCard({required this.note});

  final MomentSessionTimingNote note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  note.body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionFactsCard extends StatelessWidget {
  const _SessionFactsCard({
    required this.durationLabel,
    required this.participantCount,
    required this.rhythmLabel,
  });

  final String durationLabel;
  final int participantCount;
  final String rhythmLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _FactRow(
            icon: Icons.timer_outlined,
            label: 'Planned duration',
            value: durationLabel,
          ),
          const Divider(height: 1),
          _FactRow(
            icon: Icons.group_outlined,
            label: 'Expected participants',
            value:
                '$participantCount ${participantCount == 1 ? 'member' : 'members'}',
          ),
          const Divider(height: 1),
          _FactRow(
            icon: Icons.repeat_rounded,
            label: 'Usual rhythm',
            value: rhythmLabel,
          ),
          const Divider(height: 1),
          const _FactRow(
            icon: Icons.touch_app_outlined,
            label: 'Confirmation',
            value: 'Manual check-in',
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.linen,
              borderRadius: BorderRadius.circular(11),
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

class _SoftInformationCard extends StatelessWidget {
  const _SoftInformationCard({
    required this.icon,
    required this.eyebrow,
    required this.text,
  });

  final IconData icon;
  final String eyebrow;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.secondary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.secondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.45,
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
