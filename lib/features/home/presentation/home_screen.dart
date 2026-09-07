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
import '../../../shared/ai/ai_family_insight_service.dart';
import '../../../shared/services/family_insight_surface_selector.dart';
import '../../../shared/services/personalized_family_focus_selector.dart';
import '../../../shared/utils/care_action_id.dart';
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
import '../../weekly_report/services/family_weekly_report_builder.dart';
import '../../weekly_report/services/family_weekly_report_snapshot_projector.dart';
import '../../weekly_report/presentation/widgets/home_weekly_report_card.dart';
import '../data/daily_reflection_library.dart';
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
  bool _needsWeeklyNotificationPermission = false;
  bool _isEnablingWeeklyNotification = false;
  bool? _lastWeeklyNotificationAdultRole;
  Future<void> _weeklyNotificationQueue = Future<void>.value();
  int _weeklyNotificationGeneration = 0;
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

      _lastWeeklyNotificationAdultRole = familyContext.isAdult;
      unawaited(_syncWeeklyReportNotification(familyContext));

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
    _reconcileWeeklyNotificationRole(
      snapshot.currentUserCanManageSharedMoments,
    );
    final readyRoom = _readyRoomForCurrentUser(
      instances: snapshot.instances,
      currentUserId: familyContext.userId,
    );
    final insight = readyRoom == null
        ? FamilyInsightSurfaceSelector.home(report)
        : _readyRoomInsight(readyRoom);
    final aiNarrative = insight == null || !familyContext.canUseAi
        ? null
        : AppDependencies.aiFamilyInsightService.enrich(
            insight: insight,
            familyId: familyContext.familyId,
            memberId: familyContext.userId,
            surface: FamilyInsightSurface.home,
          );
    final reflection = DailyReflectionLibrary.forFamilyDate(
      familyId: familyContext.familyId,
      date: snapshot.generatedAt,
    );
    final weeklyReport = snapshot.currentUserCanManageSharedMoments
        ? FamilyWeeklyReportBuilder.buildLatestCompletedWeek(
            FamilyWeeklyReportSnapshotProjector.projectLatestCompletedWeek(
              snapshot,
            ),
          )
        : null;
    final hasImmediateMoment =
        snapshot.activeInstance != null ||
        readyRoom != null ||
        insight?.actionType == FamilyInsightActionType.startMomentNow;

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
              if (weeklyReport != null && !hasImmediateMoment) ...[
                const SizedBox(height: AppSpacing.xl),
                HomeWeeklyReportCard(
                  report: weeklyReport,
                  onEnableNotifications: _needsWeeklyNotificationPermission
                      ? () {
                          unawaited(_enableWeeklyReportNotification());
                        }
                      : null,
                  isEnablingNotifications: _isEnablingWeeklyNotification,
                  onViewReport: () {
                    context.pushNamed('weeklyReport');
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              HomeWhatMattersCard(
                insight: insight,
                aiNarrative: aiNarrative,
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
              if (weeklyReport != null && hasImmediateMoment) ...[
                const SizedBox(height: AppSpacing.xl),
                HomeWeeklyReportCard(
                  report: weeklyReport,
                  onEnableNotifications: _needsWeeklyNotificationPermission
                      ? () {
                          unawaited(_enableWeeklyReportNotification());
                        }
                      : null,
                  isEnablingNotifications: _isEnablingWeeklyNotification,
                  onViewReport: () {
                    context.pushNamed('weeklyReport');
                  },
                ),
              ],
              if (snapshot.currentUserCanManageSharedMoments &&
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

  Future<void> _syncWeeklyReportNotification(
    CurrentFamilyContext familyContext,
  ) {
    return _enqueueWeeklyNotificationOperation((generation) async {
      await _syncWeeklyReportNotificationNow(
        familyContext: familyContext,
        generation: generation,
      );
    });
  }

  void _reconcileWeeklyNotificationRole(bool isAdult) {
    if (_lastWeeklyNotificationAdultRole == isAdult) {
      return;
    }

    _lastWeeklyNotificationAdultRole = isAdult;
    if (isAdult) {
      unawaited(_syncWeeklyReportNotificationForCurrentMember());
    } else {
      unawaited(_cancelWeeklyReportNotification());
    }
  }

  Future<void> _syncWeeklyReportNotificationForCurrentMember() {
    return _enqueueWeeklyNotificationOperation((generation) async {
      try {
        final familyContext = await AppDependencies.currentFamilyService.load();
        if (!_isWeeklyNotificationGenerationCurrent(generation) ||
            _lastWeeklyNotificationAdultRole != true) {
          return;
        }
        await _syncWeeklyReportNotificationNow(
          familyContext: familyContext,
          generation: generation,
        );
      } catch (error) {
        debugPrint(
          'Could not refresh weekly report notification access: $error',
        );
      }
    });
  }

  Future<void> _cancelWeeklyReportNotification() {
    return _enqueueWeeklyNotificationOperation((generation) async {
      await AppDependencies.reminderNotificationService
          .cancelAllWeeklyReportNotifications();
      if (!_isWeeklyNotificationGenerationCurrent(generation) ||
          _lastWeeklyNotificationAdultRole != false ||
          !mounted) {
        return;
      }
      setState(() {
        _needsWeeklyNotificationPermission = false;
      });
    });
  }

  Future<void> _enableWeeklyReportNotification() async {
    if (_isEnablingWeeklyNotification) {
      return;
    }

    setState(() {
      _isEnablingWeeklyNotification = true;
    });

    try {
      await _enqueueWeeklyNotificationOperation((generation) async {
        try {
          final familyContext = await AppDependencies.currentFamilyService
              .load();
          if (!_isWeeklyNotificationGenerationCurrent(generation)) {
            return;
          }
          if (!familyContext.isAdult ||
              _lastWeeklyNotificationAdultRole != true) {
            await AppDependencies.reminderNotificationService
                .cancelAllWeeklyReportNotifications();
            if (_isWeeklyNotificationGenerationCurrent(generation) && mounted) {
              setState(() {
                _needsWeeklyNotificationPermission = false;
              });
            }
            return;
          }

          final preferences = await AppDependencies.profileRepository
              .getNotificationPreferences(
                familyId: familyContext.familyId,
                memberId: familyContext.userId,
              );
          if (!_isWeeklyNotificationGenerationCurrent(generation) ||
              _lastWeeklyNotificationAdultRole != true) {
            return;
          }

          final notificationService =
              AppDependencies.reminderNotificationService;
          final scheduled = await notificationService
              .syncWeeklyReportNotification(
                familyId: familyContext.familyId,
                memberId: familyContext.userId,
                isAdult: true,
                preferences: preferences,
                requestPermission: true,
              );
          if (!_isWeeklyNotificationGenerationCurrent(generation)) {
            return;
          }
          if (_lastWeeklyNotificationAdultRole != true) {
            await notificationService.cancelAllWeeklyReportNotifications();
            return;
          }
          if (!mounted) {
            return;
          }

          setState(() {
            _needsWeeklyNotificationPermission =
                notificationService.supportsScheduling &&
                preferences.weeklyReports &&
                !scheduled;
          });
          _showMessage(
            !preferences.weeklyReports
                ? 'Weekly report alerts are off in Notification Settings.'
                : scheduled
                ? 'Weekly report alerts are enabled.'
                : 'Android notifications are still disabled.',
          );
        } catch (_) {
          if (_isWeeklyNotificationGenerationCurrent(generation) && mounted) {
            _showMessage('We could not enable weekly report alerts.');
          }
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEnablingWeeklyNotification = false;
        });
      }
    }
  }

  Future<void> _syncWeeklyReportNotificationNow({
    required CurrentFamilyContext familyContext,
    required int generation,
  }) async {
    try {
      final notificationService = AppDependencies.reminderNotificationService;
      if (!familyContext.isAdult || _lastWeeklyNotificationAdultRole != true) {
        await notificationService.cancelAllWeeklyReportNotifications();
        if (_isWeeklyNotificationGenerationCurrent(generation) && mounted) {
          setState(() {
            _needsWeeklyNotificationPermission = false;
          });
        }
        return;
      }

      final preferences = await AppDependencies.profileRepository
          .getNotificationPreferences(
            familyId: familyContext.familyId,
            memberId: familyContext.userId,
          );
      if (!_isWeeklyNotificationGenerationCurrent(generation) ||
          _lastWeeklyNotificationAdultRole != true) {
        return;
      }

      final scheduled = await notificationService.syncWeeklyReportNotification(
        familyId: familyContext.familyId,
        memberId: familyContext.userId,
        isAdult: true,
        preferences: preferences,
        requestPermission: false,
      );
      if (!_isWeeklyNotificationGenerationCurrent(generation)) {
        return;
      }
      if (_lastWeeklyNotificationAdultRole != true) {
        await notificationService.cancelAllWeeklyReportNotifications();
        return;
      }
      if (!mounted) {
        return;
      }

      setState(() {
        _needsWeeklyNotificationPermission =
            notificationService.supportsScheduling &&
            preferences.weeklyReports &&
            !scheduled;
      });
    } catch (error) {
      debugPrint(
        'Could not synchronize the weekly report notification: $error',
      );
    }
  }

  Future<void> _enqueueWeeklyNotificationOperation(
    Future<void> Function(int generation) operation,
  ) {
    final generation = ++_weeklyNotificationGeneration;
    final pending = _weeklyNotificationQueue.then((_) async {
      if (!_isWeeklyNotificationGenerationCurrent(generation)) {
        return;
      }
      await operation(generation);
    });
    _weeklyNotificationQueue = pending.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Could not update weekly report notification: $error');
      },
    );
    return _weeklyNotificationQueue;
  }

  bool _isWeeklyNotificationGenerationCurrent(int generation) {
    return generation == _weeklyNotificationGeneration;
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
          await _createInsightReminder(insight: insight);
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

        case FamilyInsightActionType.openSimulation:
          if (mounted) {
            context.goNamed('digitalTwin');
          }
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
  }) async {
    if (insight.relatedReminderId != null) {
      await _openMyReminders();
      return;
    }

    final freshReport = await AppDependencies.familyInsightService.loadReport();
    FamilyInsightItem? freshInsight;
    for (final candidate in PersonalizedFamilyFocusSelector.selectAll(
      freshReport,
    )) {
      if (candidate.id == insight.id) {
        freshInsight = candidate;
        break;
      }
    }

    if (!mounted) return;

    final currentInsight = freshInsight;
    final recommended = currentInsight?.recommendedActionAt?.toUtc();
    if (currentInsight == null ||
        currentInsight.actionType != FamilyInsightActionType.addReminder ||
        recommended == null ||
        !recommended.isAfter(DateTime.now().toUtc())) {
      _showMessage(
        'The timing changed, so this reminder is no longer safe to schedule.',
      );
      return;
    }

    final relatedInstance = currentInsight.relatedInstanceId == null
        ? null
        : freshReport.snapshot.instanceById(currentInsight.relatedInstanceId!);
    if (relatedInstance != null &&
        recommended
            .add(const Duration(minutes: 30))
            .isAfter(relatedInstance.scheduledStartAt.toUtc())) {
      _showMessage(
        'There is no longer enough time before this Moment for that reminder.',
      );
      return;
    }

    final action = CareAction(
      id: CareActionId.forInsight(
        familyId: _familyContext!.familyId,
        memberId: _familyContext!.userId,
        momentId: currentInsight.relatedMomentId,
        instanceId: currentInsight.relatedInstanceId,
        purpose: 'prepare',
      ),
      familyId: _familyContext!.familyId,
      momentId: currentInsight.relatedMomentId,
      instanceId: currentInsight.relatedInstanceId,
      title: currentInsight.suggestedActions.isEmpty
          ? 'Prepare for ${relatedInstance?.titleSnapshot ?? currentInsight.headline}'
          : currentInsight.suggestedActions.first,
      reason: currentInsight.summary,
      assignedMemberId: _familyContext!.userId,
      dueAt: recommended,
      status: CareActionStatus.pending,
      source: CareActionSource.calendar,
      evidenceType: EvidenceType.scheduledOnly,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    final storedAction = await AppDependencies.careActionRepository
        .createCareActionIfAbsent(action);

    if (storedAction.isFinished) {
      if (mounted) {
        _showMessage('This preparation reminder was already completed.');
      }
      return;
    }

    final notificationService = AppDependencies.reminderNotificationService;
    final notificationScheduled = await notificationService.scheduleReminder(
      storedAction,
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
