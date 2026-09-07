import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sakan/shared/services/recurring_occurrence_service.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/care_action.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_insight_report.dart';
import '../../../shared/models/family_memory.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/ai/ai_family_insight_service.dart';
import '../../../shared/services/family_insight_surface_selector.dart';
import '../../../shared/services/personalized_family_focus_selector.dart';
import '../../../shared/services/calendar_occurrence_label.dart';
import '../../../shared/utils/care_action_id.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../../daily_review/presentation/today_review_screen.dart';
import '../../memories/presentation/add_memory_screen.dart';
import '../../memories/presentation/all_memories_screen.dart';
import '../../memories/presentation/memory_details_screen.dart';
import '../../moments/presentation/live_moment_screen.dart';
import '../../moments/presentation/moment_form_screen.dart';
import '../../moments/presentation/moment_session_summary_screen.dart';
import '../../moments/presentation/schedule_moment_occurrence_screen.dart';
import '../../moments/presentation/moments_screen.dart';
import '../../profile/presentation/my_reminders_screen.dart';
import 'calendar_instance_projection.dart';
import 'calendar_types.dart';
import 'widgets/active_moment_banner.dart';
import 'widgets/calendar_agenda_view.dart';
import 'widgets/calendar_day_sheet.dart';
import 'widgets/calendar_filter_bar.dart';
import 'widgets/calendar_mode_selector.dart';
import 'widgets/calendar_moment_details_sheet.dart';
import 'widgets/calendar_month_view.dart';
import 'widgets/calendar_palette.dart';
import 'widgets/calendar_support_cards.dart';
import 'widgets/calendar_week_view.dart';
import 'widgets/family_insight_section.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CurrentFamilyContext? _familyContext;
  Stream<FamilyInsightReport>? _familyInsightReportStream;

  CalendarViewMode _viewMode = CalendarViewMode.month;

  Set<CalendarFilter> _activeCategoryFilters = <CalendarFilter>{
    CalendarFilter.tradition,
    CalendarFilter.milestone,
    CalendarFilter.care,
  };

  bool _mineOnly = false;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  bool _isLoading = true;
  bool _isSavingInsightReminder = false;
  bool _isStartingMoment = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  Future<void> _ensureRecurringRange({
    required CurrentFamilyContext familyContext,
    required DateTime focusDate,
  }) async {
    if (!familyContext.isAdult) {
      return;
    }

    try {
      final moments = await AppDependencies.calendarRepository
          .watchMoments(familyId: familyContext.familyId)
          .first;

      final occurrenceService = RecurringOccurrenceService(
        AppDependencies.momentInstanceRepository,
      );

      await occurrenceService.ensureRange(
        moments: moments,
        rangeStart: DateTime(focusDate.year, focusDate.month - 1, 1),
        rangeEnd: DateTime(focusDate.year, focusDate.month + 3, 0, 23, 59, 59),
        createdBy: familyContext.userId,
      );
    } catch (_) {
      // Never block Calendar if recurrence generation fails.
    }
  }

  Future<void> _loadCalendar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      if (familyContext.isAdult) {
        try {
          await AppDependencies.momentInstanceMigrationService
              .backfillCurrentSchedules(
                familyId: familyContext.familyId,
                currentUserId: familyContext.userId,
              );
        } catch (_) {
          // Migration compatibility must never block the Calendar.
          // Existing instance-based data remains fully usable.
        }
      }
      if (mounted) {
        setState(() {
          _familyContext = familyContext;
        });
      }

      await _ensureRecurringRange(
        familyContext: familyContext,
        focusDate: DateTime.now(),
      );

      final reportStream = AppDependencies.familyInsightService.watchReport();

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _familyInsightReportStream = reportStream;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load your family calendar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading your family calendar…'),
        ),
      );
    }

    if (_familyContext == null || _familyInsightReportStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Calendar')),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'Your family calendar is unavailable.',
            onRetry: _loadCalendar,
          ),
        ),
      );
    }

    return StreamBuilder<FamilyInsightReport>(
      stream: _familyInsightReportStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorScaffold(
            'We could not calculate your family calendar and insights.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(
                message: 'Loading family occurrences and insights…',
              ),
            ),
          );
        }

        final report = snapshot.data;

        if (report == null) {
          return _errorScaffold('Your family insight report is unavailable.');
        }

        final allEntries = buildCalendarInstanceEntries(report.snapshot);

        final filteredEntries = _applyFilters(allEntries);

        final entryByCalendarId = <String, CalendarInstanceEntry>{
          for (final entry in allEntries) entry.calendarMoment.id: entry,
        };

        final projectedMoments = filteredEntries
            .map((entry) => entry.calendarMoment)
            .toList(growable: false);

        final agendaMoments = buildAgendaInstanceEntries(
          filteredEntries,
        ).map((entry) => entry.calendarMoment).toList(growable: false);

        final occurrenceLabelsByCalendarId = <String, String>{
          for (final entry in allEntries)
            entry.calendarMoment.id: _calendarOccurrenceLabelForInstance(
              instance: entry.instance,
              definition: entry.definition,
            ),
        };

        return _calendarScaffold(
          report: report,
          projectedMoments: projectedMoments,
          agendaMoments: agendaMoments,
          entryByCalendarId: entryByCalendarId,
          occurrenceLabelsByCalendarId: occurrenceLabelsByCalendarId,
        );
      },
    );
  }

  Widget _calendarScaffold({
    required FamilyInsightReport report,
    required List<FamilyMoment> projectedMoments,
    required List<FamilyMoment> agendaMoments,
    required Map<String, CalendarInstanceEntry> entryByCalendarId,
    required Map<String, String> occurrenceLabelsByCalendarId,
  }) {
    final familyContext = _familyContext!;
    final visibleInsight = FamilyInsightSurfaceSelector.calendar(report);
    final aiNarrative = visibleInsight == null || !familyContext.canUseAi
        ? null
        : AppDependencies.aiFamilyInsightService.enrich(
            insight: visibleInsight,
            familyId: familyContext.familyId,
            memberId: familyContext.userId,
            surface: FamilyInsightSurface.calendar,
          );
    final activeInstance = report.snapshot.activeInstance;
    final memories = List<FamilyMemory>.from(report.snapshot.memories)
      ..sort((first, second) => second.occurredAt.compareTo(first.occurredAt));

    return Scaffold(
      backgroundColor: CalendarPalette.background,
      appBar: AppBar(
        title: const Text('Family Calendar'),
        backgroundColor: CalendarPalette.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            96,
          ),
          children: [
            if (activeInstance != null) ...[
              ActiveMomentBanner(
                instance: activeInstance,
                onOpen: () {
                  _openLiveMoment(activeInstance);
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            CalendarModeSelector(
              selectedMode: _viewMode,
              onChanged: (mode) {
                setState(() {
                  _viewMode = mode;
                });
              },
            ),

            const SizedBox(height: AppSpacing.md),

            CalendarFilterBar(
              activeCategoryFilters: _activeCategoryFilters,
              mineOnly: _mineOnly,
              onCategoryChanged: (filters) {
                if (filters.isEmpty) {
                  return;
                }

                setState(() {
                  _activeCategoryFilters = filters;
                });
              },
              onMineChanged: (value) {
                setState(() {
                  _mineOnly = value;
                });
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            if (_viewMode == CalendarViewMode.month)
              CalendarMonthView(
                focusedDay: _focusedDay,
                selectedDay: _selectedDay,
                moments: projectedMoments,
                currentUserId: familyContext.userId,
                onDaySelected: (day) {
                  setState(() {
                    _selectedDay = day;
                    _focusedDay = day;
                  });

                  _openDaySheet(
                    date: day,
                    projectedMoments: projectedMoments,
                    entryByCalendarId: entryByCalendarId,
                    occurrenceLabelsByCalendarId: occurrenceLabelsByCalendarId,
                    report: report,
                  );
                },
                onPageChanged: (focused) {
                  setState(() {
                    _focusedDay = focused;
                  });

                  final familyContext = _familyContext;

                  if (familyContext != null) {
                    _ensureRecurringRange(
                      familyContext: familyContext,
                      focusDate: focused,
                    );
                  }
                },
              )
            else if (_viewMode == CalendarViewMode.week)
              CalendarWeekView(
                referenceDay: _focusedDay,
                selectedDay: _selectedDay,
                moments: projectedMoments,
                currentUserId: familyContext.userId,
                onSelectedDay: (day) {
                  setState(() {
                    _selectedDay = day;
                    _focusedDay = day;
                  });

                  _openDaySheet(
                    date: day,
                    projectedMoments: projectedMoments,
                    entryByCalendarId: entryByCalendarId,
                    occurrenceLabelsByCalendarId: occurrenceLabelsByCalendarId,
                    report: report,
                  );
                },
                onPreviousWeek: () {
                  final newFocus = _focusedDay.subtract(
                    const Duration(days: 7),
                  );

                  setState(() {
                    _focusedDay = newFocus;
                    _selectedDay = newFocus;
                  });

                  final familyContext = _familyContext;

                  if (familyContext != null) {
                    _ensureRecurringRange(
                      familyContext: familyContext,
                      focusDate: newFocus,
                    );
                  }
                },
                onNextWeek: () {
                  final newFocus = _focusedDay.add(const Duration(days: 7));

                  setState(() {
                    _focusedDay = newFocus;
                    _selectedDay = newFocus;
                  });

                  final familyContext = _familyContext;

                  if (familyContext != null) {
                    _ensureRecurringRange(
                      familyContext: familyContext,
                      focusDate: newFocus,
                    );
                  }
                },
              )
            else
              CalendarAgendaView(
                moments: agendaMoments,
                occurrenceLabelsByMomentId: occurrenceLabelsByCalendarId,
                currentUserId: familyContext.userId,
                onMomentTap: (projected) {
                  final entry = entryByCalendarId[projected.id];

                  if (entry != null) {
                    _openInstanceDetails(entry: entry, report: report);
                  }
                },
              ),

            if (_viewMode != CalendarViewMode.agenda) ...[
              const SizedBox(height: AppSpacing.xl),

              FamilyInsightSection(
                insight: visibleInsight,
                aiNarrative: aiNarrative,
                onPerformAction: (insight) {
                  return _performInsightAction(
                    insight: insight,
                    report: report,
                  );
                },
                onOpenSimulation: () {
                  context.goNamed('digitalTwin');
                },
              ),

              const SizedBox(height: AppSpacing.sm),

              CalendarSupportCards(
                memories: memories,
                onMemoryTap: (memory) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MemoryDetailsScreen(memory: memory),
                    ),
                  );
                },
                onAllMemoriesTap: _openAllMemoriesScreen,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Scaffold _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Calendar')),
      body: SafeArea(
        child: AppErrorState(message: message, onRetry: _loadCalendar),
      ),
    );
  }

  List<CalendarInstanceEntry> _applyFilters(
    List<CalendarInstanceEntry> entries,
  ) {
    final userId = _familyContext!.userId;

    final filtered = entries.where((entry) {
      final moment = entry.calendarMoment;
      final categoryMatch = _matchesSelectedCategory(moment);
      final mineMatch =
          !_mineOnly || moment.expectedParticipantIds.contains(userId);

      return categoryMatch && mineMatch;
    }).toList();

    filtered.sort(
      (first, second) =>
          first.calendarMoment.startAt.compareTo(second.calendarMoment.startAt),
    );

    return filtered;
  }

  bool _matchesSelectedCategory(FamilyMoment moment) {
    if (_activeCategoryFilters.isEmpty) {
      return false;
    }

    if (_activeCategoryFilters.contains(CalendarFilter.milestone) &&
        moment.category == MomentCategory.milestone) {
      return true;
    }

    if (_activeCategoryFilters.contains(CalendarFilter.care) &&
        (moment.category == MomentCategory.care ||
            moment.category == MomentCategory.responsibility)) {
      return true;
    }

    if (_activeCategoryFilters.contains(CalendarFilter.tradition) &&
        (moment.category == MomentCategory.tradition ||
            moment.category == MomentCategory.familyTime ||
            moment.category == MomentCategory.memory)) {
      return true;
    }

    return false;
  }

  List<FamilyMoment> _momentsForDay(List<FamilyMoment> moments, DateTime day) {
    return moments.where((moment) {
      return isSameDay(moment.startAt.toLocal(), day);
    }).toList();
  }

  Future<void> _openDaySheet({
    required DateTime date,
    required List<FamilyMoment> projectedMoments,
    required Map<String, CalendarInstanceEntry> entryByCalendarId,
    required Map<String, String> occurrenceLabelsByCalendarId,
    required FamilyInsightReport report,
  }) async {
    final dayMoments = _momentsForDay(projectedMoments, date);

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: CalendarPalette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return CalendarDaySheet(
          date: date,
          moments: dayMoments,
          occurrenceLabelsByMomentId: occurrenceLabelsByCalendarId,
          currentUserId: _familyContext!.userId,
          onMomentTap: (projected) {
            Navigator.of(sheetContext).pop();

            final entry = entryByCalendarId[projected.id];

            if (entry != null) {
              _openInstanceDetails(entry: entry, report: report);
            }
          },
        );
      },
    );
  }

  Future<void> _openInstanceDetails({
    required CalendarInstanceEntry entry,
    required FamilyInsightReport report,
  }) async {
    FamilyMemory? memory;

    try {
      memory = await AppDependencies.memoryRepository.getMemoryForInstance(
        familyId: entry.instance.familyId,
        instanceId: entry.instance.id,
      );

      memory ??= await AppDependencies.memoryRepository.getMemoryForMoment(
        familyId: entry.instance.familyId,
        momentId: entry.instance.momentId,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The occurrence opened, but its Memory status could not be loaded.',
          ),
        ),
      );
    }

    if (!mounted) return;

    final instance = entry.instance;
    final activeInstance = report.snapshot.activeInstance;
    final isThisActive = activeInstance?.id == instance.id;
    final isReviewable = report.snapshot.reviewableInstances.any(
      (item) => item.id == instance.id,
    );

    String? primaryActionLabel;
    IconData? primaryActionIcon;
    VoidCallback? primaryAction;
    String? actionHint;

    if (isThisActive) {
      primaryActionLabel = 'Join Active Moment';
      primaryActionIcon = Icons.login_rounded;
      primaryAction = () {
        Navigator.of(context).pop();
        _openLiveMoment(instance);
      };
    } else if (_canStartEntryNow(entry, activeInstance)) {
      primaryActionLabel = 'Start This Now';
      primaryActionIcon = Icons.play_arrow_rounded;
      primaryAction = () {
        Navigator.of(context).pop();
        _startMomentNow(entry);
      };
    } else if (isReviewable && _familyContext!.isAdult) {
      primaryActionLabel = 'Review Today';
      primaryActionIcon = Icons.fact_check_outlined;
      primaryAction = () {
        Navigator.of(context).pop();
        _openTodayReview();
      };
    } else if (activeInstance != null && !isThisActive) {
      actionHint =
          'Another family Moment is already live. End it before starting a new one.';
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: CalendarPalette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return CalendarMomentDetailsSheet(
          moment: entry.calendarMoment,
          instance: instance,
          occurrenceLabel: _calendarOccurrenceLabelForInstance(
            instance: instance,
            definition: entry.definition,
          ),
          memory: memory,
          currentUserId: _familyContext!.userId,
          canEditDefinition:
              _familyContext!.isAdult && entry.definition != null,
          primaryActionLabel: primaryActionLabel,
          primaryActionIcon: primaryActionIcon,
          onPrimaryAction: primaryAction,
          primaryActionHint: actionHint,
          onViewSummary: instance.status == MomentInstanceStatus.completed
              ? () {
                  Navigator.of(sheetContext).pop();
                  _openSessionSummary(instance);
                }
              : null,
          onEditMoment: entry.definition == null
              ? null
              : () {
                  Navigator.of(sheetContext).pop();

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MomentFormScreen(initialMoment: entry.definition),
                    ),
                  );
                },
          onAddMemory:
              instance.status == MomentInstanceStatus.completed &&
                  memory == null &&
                  _familyContext!.isAdult
              ? () {
                  Navigator.of(sheetContext).pop();
                  _openAddMemoryScreen(
                    initialMoment: entry.definitionOrSnapshot,
                    initialInstance: instance,
                  );
                }
              : null,
          onViewMemory: memory == null
              ? null
              : () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MemoryDetailsScreen(memory: memory!),
                    ),
                  );
                },
          onEditMemory: memory != null && _familyContext!.isAdult
              ? () {
                  Navigator.of(sheetContext).pop();
                  _openAddMemoryScreen(
                    initialMoment: entry.definitionOrSnapshot,
                    initialInstance: instance,
                  );
                }
              : null,
        );
      },
    );
  }

  bool _canStartEntryNow(
    CalendarInstanceEntry entry,
    MomentInstance? activeInstance,
  ) {
    if (!_familyContext!.isAdult ||
        activeInstance != null ||
        _isStartingMoment) {
      return false;
    }

    final instance = entry.instance;
    final isPlanned =
        instance.status == MomentInstanceStatus.proposed ||
        instance.status == MomentInstanceStatus.scheduled ||
        instance.status == MomentInstanceStatus.inviting;

    if (!isPlanned || instance.expectedParticipantIds.length < 2) {
      return false;
    }

    return instance.categorySnapshot == MomentCategory.tradition ||
        instance.categorySnapshot == MomentCategory.familyTime;
  }

  Future<void> _startMomentNow(CalendarInstanceEntry entry) async {
    if (_isStartingMoment) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start this Moment now?'),
          content: Text(
            '“${entry.instance.titleSnapshot}” will become live. '
            'You will be checked in automatically, and the shared timer will begin.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Not Now'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Moment'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isStartingMoment = true;
    });

    try {
      final instance = await AppDependencies.momentInstanceRepository
          .startMomentNow(
            moment: entry.definitionOrSnapshot,
            startedBy: _familyContext!.userId,
            source: MomentInstanceSource.calendar,
            existingInstanceId: entry.instance.id,
          );

      if (!mounted) return;
      await _openLiveMoment(instance);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'We could not start this Moment.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingMoment = false;
        });
      }
    }
  }

  Future<void> _performInsightAction({
    required FamilyInsightItem insight,
    required FamilyInsightReport report,
  }) async {
    switch (insight.actionType) {
      case FamilyInsightActionType.joinActiveMoment:
        final active = insight.relatedInstanceId == null
            ? report.snapshot.activeInstance
            : report.snapshot.instanceById(insight.relatedInstanceId!);

        if (active != null) {
          await _openLiveMoment(active);
        }
        return;

      case FamilyInsightActionType.reviewToday:
        await _openTodayReview();
        return;

      case FamilyInsightActionType.openReminders:
        await _openMyRemindersPage();
        return;

      case FamilyInsightActionType.addReminder:
        await _scheduleInsightReminder(insight);
        return;

      case FamilyInsightActionType.startMomentNow:
        final instanceId = insight.relatedInstanceId;

        if (instanceId == null) {
          await _openMomentsPage();
          return;
        }

        final entry = buildCalendarInstanceEntries(
          report.snapshot,
          includeCancelled: true,
        ).where((item) => item.instance.id == instanceId).firstOrNull;

        if (entry == null) {
          await _openMomentsPage();
          return;
        }

        await _startMomentNow(entry);
        return;

      case FamilyInsightActionType.scheduleMoment:
        final momentId = insight.relatedMomentId;
        final moment = momentId == null
            ? null
            : report.snapshot.momentById(momentId);

        if (moment == null) {
          await _openMomentsPage();
          return;
        }

        await Navigator.of(context).push(
          MaterialPageRoute(
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
        await _openMomentsPage();
        return;

      case FamilyInsightActionType.none:
        return;
    }
  }

  Future<void> _scheduleInsightReminder(FamilyInsightItem insight) async {
    if (_isSavingInsightReminder) {
      return;
    }

    if (insight.relatedReminderId != null) {
      await _openMyRemindersPage();
      return;
    }

    late final FamilyInsightReport freshReport;
    try {
      freshReport = await AppDependencies.familyInsightService.loadReport();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not refresh the recommendation. Try again.'),
        ),
      );
      return;
    }
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
    final recommendedTime = currentInsight?.recommendedActionAt?.toUtc();
    if (currentInsight == null ||
        currentInsight.actionType != FamilyInsightActionType.addReminder ||
        recommendedTime == null ||
        !recommendedTime.isAfter(DateTime.now().toUtc())) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The timing changed, so this reminder is no longer safe to schedule.',
          ),
        ),
      );
      return;
    }

    final relatedInstance = currentInsight.relatedInstanceId == null
        ? null
        : freshReport.snapshot.instanceById(currentInsight.relatedInstanceId!);
    if (relatedInstance != null &&
        recommendedTime
            .add(const Duration(minutes: 30))
            .isAfter(relatedInstance.scheduledStartAt.toUtc())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'There is no longer enough time before this Moment for that reminder.',
          ),
        ),
      );
      return;
    }

    final familyContext = _familyContext!;
    final now = DateTime.now().toUtc();

    setState(() {
      _isSavingInsightReminder = true;
    });

    try {
      final action = CareAction(
        id: CareActionId.forInsight(
          familyId: familyContext.familyId,
          memberId: familyContext.userId,
          momentId: currentInsight.relatedMomentId,
          instanceId: currentInsight.relatedInstanceId,
          purpose: 'prepare',
        ),
        familyId: familyContext.familyId,
        momentId: currentInsight.relatedMomentId,
        instanceId: currentInsight.relatedInstanceId,
        title: currentInsight.suggestedActions.isEmpty
            ? currentInsight.headline
            : currentInsight.suggestedActions.first,
        reason: currentInsight.summary,
        assignedMemberId: familyContext.userId,
        dueAt: recommendedTime,
        status: CareActionStatus.pending,
        source: CareActionSource.calendar,
        evidenceType: EvidenceType.scheduledOnly,
        createdAt: now,
        updatedAt: now,
      );

      final storedAction = await AppDependencies.careActionRepository
          .createCareActionIfAbsent(action);

      if (storedAction.isFinished) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This preparation reminder was already completed.'),
            ),
          );
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
          : 'Reminder added to My Reminders. Notifications are disabled.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not add this reminder.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingInsightReminder = false;
        });
      }
    }
  }

  Future<void> _openTodayReview() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const TodayReviewScreen()));

    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Today Review saved.')));
    }
  }

  Future<void> _openMomentsPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MomentsScreen()));
  }

  Future<void> _openMyRemindersPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MyRemindersScreen()));
  }

  Future<void> _openLiveMoment(MomentInstance instance) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveMomentScreen(
          familyId: instance.familyId,
          instanceId: instance.id,
        ),
      ),
    );
  }

  Future<void> _openSessionSummary(MomentInstance instance) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MomentSessionSummaryScreen(
          familyId: instance.familyId,
          instanceId: instance.id,
        ),
      ),
    );
  }

  Future<void> _openAddMemoryScreen({
    FamilyMoment? initialMoment,
    MomentInstance? initialInstance,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddMemoryScreen(
          initialMoment: initialMoment,
          initialInstance: initialInstance,
        ),
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Family Memory saved.')));
  }

  Future<void> _openAllMemoriesScreen() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AllMemoriesScreen()));
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

String _calendarOccurrenceLabelForInstance({
  required MomentInstance instance,
  FamilyMoment? definition,
}) {
  return CalendarOccurrenceLabel.forInstance(
    instance: instance,
    definition: definition,
  );
}
