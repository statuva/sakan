import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/care_action.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_insight_report.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../../daily_review/presentation/today_review_screen.dart';
import '../../moments/presentation/live_moment_screen.dart';
import '../../moments/presentation/moment_session_preview_screen.dart';
import '../../moments/presentation/moment_waiting_room_screen.dart';
import '../../moments/presentation/moments_screen.dart';
import '../../moments/services/moment_session_preparation_service.dart';
import '../../moments/presentation/schedule_moment_occurrence_screen.dart';
import '../../profile/presentation/my_reminders_screen.dart';
import '../data/daily_reflection_library.dart';
import '../services/home_priority_selector.dart';
import 'quick_start_moment_screen.dart';
import 'widgets/home_daily_reflection.dart';
import 'widgets/home_greeting.dart';
import 'widgets/home_reminders_card.dart';
import 'widgets/home_together_now_card.dart';
import 'widgets/home_what_matters_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CurrentFamilyContext? _familyContext;
  Stream<FamilyInsightReport>? _reportStream;

  bool _isLoading = true;
  bool _isPerformingAction = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  Future<void> _loadHome() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();
      final reportStream = AppDependencies.familyInsightService.watchReport();

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _reportStream = reportStream;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load your family Home.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Preparing your family Home…'),
        ),
      );
    }

    if (_familyContext == null || _reportStream == null) {
      return Scaffold(
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'Your family Home is unavailable.',
            onRetry: _loadHome,
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
                message: 'We could not update your family Home.',
                onRetry: _loadHome,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(
                message: 'Reading what matters right now…',
              ),
            ),
          );
        }

        final report = snapshot.data;

        if (report == null) {
          return Scaffold(
            body: SafeArea(
              child: AppErrorState(
                message: 'No family Home report is available yet.',
                onRetry: _loadHome,
              ),
            ),
          );
        }

        return _buildHome(report);
      },
    );
  }

  Widget _buildHome(FamilyInsightReport report) {
    final familyContext = _familyContext!;
    final snapshot = report.snapshot;
    final readyRoom = _readyRoomForCurrentUser(
      instances: snapshot.instances,
      currentUserId: familyContext.userId,
    );
    final insight = readyRoom == null
        ? HomePrioritySelector.select(report)
        : _readyRoomInsight(readyRoom);
    final reflection = DailyReflectionLibrary.forFamilyDate(
      familyId: familyContext.familyId,
      date: snapshot.generatedAt,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHome,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              118,
            ),
            children: [
              HomeGreeting(
                displayName: familyContext.member.displayName,
                now: snapshot.generatedAt,
              ),
              if (reflection != null)
                HomeDailyReflection(reflection: reflection),
              const SizedBox(height: AppSpacing.xl),
              HomeTogetherNowCard(
                members: snapshot.activeMembers,
                activeInstance: snapshot.activeInstance,
              ),
              const SizedBox(height: AppSpacing.xl),
              HomeWhatMattersCard(
                insight: insight,
                nextInstance: snapshot.nextInstance,
                isPerformingAction: _isPerformingAction,
                onAction: insight == null
                    ? null
                    : () {
                        unawaited(
                          _performInsightAction(
                            insight: insight,
                            report: report,
                          ),
                        );
                      },
                onOpenCalendar: () {
                  context.go('/calendar');
                },
              ),
              if (familyContext.isAdult &&
                  snapshot.activeInstance == null &&
                  readyRoom == null) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isPerformingAction ? null : _openQuickStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start a Moment Now'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              HomeRemindersCard(
                reminders: snapshot.currentUserReminders,
                now: snapshot.generatedAt,
                onOpen: _openMyReminders,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performInsightAction({
    required FamilyInsightItem insight,
    required FamilyInsightReport report,
  }) async {
    if (_isPerformingAction) {
      return;
    }

    setState(() {
      _isPerformingAction = true;
    });

    try {
      switch (insight.actionType) {
        case FamilyInsightActionType.joinActiveMoment:
          final instance = insight.relatedInstanceId == null
              ? report.snapshot.activeInstance
              : report.snapshot.instanceById(insight.relatedInstanceId!);

          if (instance == null) {
            _showMessage('The shared Moment could not be found.');
            return;
          }

          if (instance.status == MomentInstanceStatus.inviting) {
            await _openReadyRoom(instance: instance, report: report);
          } else {
            await _openLiveMoment(instance);
          }
          return;

        case FamilyInsightActionType.startMomentNow:
          await _startRecommendedMoment(insight: insight, report: report);
          return;

        case FamilyInsightActionType.reviewToday:
          await Navigator.of(context, rootNavigator: true).push<void>(
            MaterialPageRoute<void>(builder: (_) => const TodayReviewScreen()),
          );
          return;

        case FamilyInsightActionType.openReminders:
          await _openMyReminders();
          return;

        case FamilyInsightActionType.addReminder:
          await _createInsightReminder(insight: insight, report: report);
          return;

        case FamilyInsightActionType.scheduleMoment:
          final momentId = insight.relatedMomentId;
          final moment = momentId == null
              ? null
              : report.snapshot.momentById(momentId);

          if (moment == null) {
            await _openMoments();
            return;
          }

          await Navigator.of(context, rootNavigator: true).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ScheduleMomentOccurrenceScreen(moment: moment),
            ),
          );
          return;

        case FamilyInsightActionType.manageMoments:
          await _openMoments();
          return;

        case FamilyInsightActionType.none:
          if (mounted) {
            context.go('/calendar');
          }
          return;
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error is StateError
            ? error.message.toString()
            : 'We could not complete this action.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingAction = false;
        });
      }
    }
  }

  Future<void> _startRecommendedMoment({
    required FamilyInsightItem insight,
    required FamilyInsightReport report,
  }) async {
    final instanceId = insight.relatedInstanceId;

    if (instanceId == null) {
      _showMessage('This recommendation has no occurrence to start.');
      return;
    }

    final instance = report.snapshot.instanceById(instanceId);

    if (instance == null) {
      _showMessage('This Moment occurrence could not be found.');
      return;
    }

    final moment =
        report.snapshot.momentById(instance.momentId) ??
        _definitionFromInstance(instance);

    await openMomentSessionPreview(
      context: context,
      moment: moment,
      existingInstance: instance,
      source: MomentInstanceSource.familyInsight,
      useRootNavigator: true,
    );
  }

  Future<void> _createInsightReminder({
    required FamilyInsightItem insight,
    required FamilyInsightReport report,
  }) async {
    if (insight.relatedReminderId != null) {
      await _openMyReminders();
      return;
    }

    final nowLocal = DateTime.now();
    final recommended = insight.recommendedActionAt?.toLocal();
    final dueAt = recommended != null && recommended.isAfter(nowLocal)
        ? recommended
        : nowLocal.add(const Duration(minutes: 30));

    final relatedInstance = insight.relatedInstanceId == null
        ? null
        : report.snapshot.instanceById(insight.relatedInstanceId!);

    final action = CareAction(
      id:
          'care_${_familyContext!.userId}_'
          '${DateTime.now().microsecondsSinceEpoch}',
      familyId: _familyContext!.familyId,
      momentId: insight.relatedMomentId,
      instanceId: insight.relatedInstanceId,
      title: insight.suggestedActions.isEmpty
          ? 'Prepare for ${relatedInstance?.titleSnapshot ?? insight.headline}'
          : insight.suggestedActions.first,
      reason: <String>[insight.summary, ...insight.reasons].join('\n'),
      assignedMemberId: _familyContext!.userId,
      dueAt: dueAt.toUtc(),
      status: CareActionStatus.pending,
      source: CareActionSource.calendar,
      evidenceType: EvidenceType.scheduledOnly,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    await AppDependencies.careActionRepository.createCareAction(action);

    final notificationService = AppDependencies.reminderNotificationService;
    final notificationScheduled = await notificationService.scheduleReminder(
      action,
      requestPermission: true,
    );

    if (!mounted) return;

    final message = !notificationService.supportsScheduling
        ? 'Reminder added to My Reminders.'
        : notificationScheduled
        ? 'Reminder added and notification scheduled.'
        : 'Reminder added. Notifications are currently disabled.';

    _showMessage(message);
  }

  MomentInstance? _readyRoomForCurrentUser({
    required List<MomentInstance> instances,
    required String currentUserId,
  }) {
    final readyRooms =
        instances.where((instance) {
          return instance.status == MomentInstanceStatus.inviting &&
              instance.expectedParticipantIds.contains(currentUserId);
        }).toList()..sort(
          (first, second) => second.updatedAt.compareTo(first.updatedAt),
        );

    return readyRooms.isEmpty ? null : readyRooms.first;
  }

  FamilyInsightItem _readyRoomInsight(MomentInstance instance) {
    return FamilyInsightItem(
      id: 'ready_room_${instance.id}',
      kind: FamilyInsightKind.activeMoment,
      actionType: FamilyInsightActionType.joinActiveMoment,
      priority: -1,
      headline: '${instance.titleSnapshot} is getting ready',
      summary:
          'The Ready Room is open. Join before an adult starts the shared timer.',
      reasons: const <String>[
        'Joining now lets the host see that you are ready.',
      ],
      suggestedActions: const <String>['Join Session'],
      confidence: ConfidenceLevel.high,
      relatedMomentId: instance.momentId,
      relatedInstanceId: instance.id,
      recommendedActionAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _openReadyRoom({
    required MomentInstance instance,
    required FamilyInsightReport report,
  }) async {
    final moment =
        report.snapshot.momentById(instance.momentId) ??
        _definitionFromInstance(instance);
    final preparationService = MomentSessionPreparationService();
    final preparedSession = await preparationService.loadPreparedSession(
      familyId: instance.familyId,
      instanceId: instance.id,
    );

    if (!mounted) return;

    if (preparedSession == null) {
      _showMessage('The Ready Room is no longer open.');
      return;
    }

    final active = await Navigator.of(context, rootNavigator: true)
        .push<MomentInstance>(
          MaterialPageRoute<MomentInstance>(
            builder: (_) => MomentWaitingRoomScreen(
              moment: moment,
              source: instance.source,
              preparedSession: preparedSession,
            ),
          ),
        );

    if (!mounted || active == null) {
      return;
    }

    await _openLiveMoment(active);
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

  Future<void> _openQuickStart() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => const QuickStartMomentScreen()),
    );
  }

  Future<void> _openMyReminders() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MyRemindersScreen()),
    );
  }

  Future<void> _openMoments() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MomentsScreen()),
    );
  }

  Future<void> _openLiveMoment(MomentInstance instance) async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LiveMomentScreen(
          familyId: instance.familyId,
          instanceId: instance.id,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
