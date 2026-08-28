import 'package:flutter/material.dart';
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
import '../../../shared/models/rhythm_record.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../../memories/presentation/add_memory_screen.dart';
import '../../memories/presentation/all_memories_screen.dart';
import '../../memories/presentation/memory_details_screen.dart';
import '../../moments/presentation/live_moment_screen.dart';
import '../../moments/presentation/moment_form_screen.dart';
import '../../moments/presentation/moments_screen.dart';
import '../../profile/presentation/my_reminders_screen.dart';
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
import '../../daily_review/presentation/today_review_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CurrentFamilyContext? _familyContext;
  Stream<FamilyInsightReport>? _familyInsightReportStream;
  Stream<MomentInstance?>? _activeInstanceStream;

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

  Future<void> _loadCalendar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      final familyInsightReportStream = AppDependencies.familyInsightService
          .watchReport();

      final activeInstanceStream = AppDependencies.momentInstanceRepository
          .watchActiveInstance(familyId: familyContext.familyId);

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _familyInsightReportStream = familyInsightReportStream;
        _activeInstanceStream = activeInstanceStream;
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

    if (_familyContext == null ||
        _familyInsightReportStream == null ||
        _activeInstanceStream == null) {
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
          return _errorScaffold('We could not calculate your family insights.');
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(
                message: 'Loading family moments and insights…',
              ),
            ),
          );
        }

        final report = snapshot.data;

        if (report == null) {
          return _errorScaffold('Your family insight report is unavailable.');
        }

        final allMoments = report.snapshot.moments;
        final rhythmsByMomentId = report.snapshot.rhythmsByMomentId;
        final filteredMoments = _applyFilters(allMoments);

        return StreamBuilder<MomentInstance?>(
          stream: _activeInstanceStream,
          builder: (context, activeSnapshot) {
            if (activeSnapshot.hasError) {
              return _errorScaffold(
                'We could not load the active family Moment.',
              );
            }

            return _calendarScaffold(
              filteredMoments: filteredMoments,
              rhythmsByMomentId: rhythmsByMomentId,
              insightReport: report,
              activeInstance: activeSnapshot.data,
            );
          },
        );
      },
    );
  }

  Widget _calendarScaffold({
    required List<FamilyMoment> filteredMoments,
    required Map<String, RhythmRecord> rhythmsByMomentId,
    required FamilyInsightReport insightReport,
    required MomentInstance? activeInstance,
  }) {
    final familyContext = _familyContext!;
    final bestAvailability = insightReport.bestSharedWindow;
    final latestMemory = insightReport.snapshot.latestMemory;

    return Scaffold(
      backgroundColor: CalendarPalette.background,
      appBar: AppBar(
        title: const Text('Family Calendar'),
        backgroundColor: CalendarPalette.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Review Today',
            onPressed: _openTodayReview,
            icon: const Icon(Icons.fact_check_outlined),
          ),

          TextButton.icon(
            onPressed: _openMomentsPage,
            icon: const Icon(Icons.auto_awesome_motion_outlined, size: 18),
            label: const Text('Manage Moments'),
          ),

          const SizedBox(width: 6),
        ],
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
                moments: filteredMoments,
                currentUserId: familyContext.userId,
                onDaySelected: (day) {
                  setState(() {
                    _selectedDay = day;
                    _focusedDay = day;
                  });

                  _openDaySheet(
                    date: day,
                    moments: filteredMoments,
                    rhythmsByMomentId: rhythmsByMomentId,
                    activeInstance: activeInstance,
                  );
                },
                onPageChanged: (focused) {
                  setState(() {
                    _focusedDay = focused;
                  });
                },
              )
            else if (_viewMode == CalendarViewMode.week)
              CalendarWeekView(
                referenceDay: _focusedDay,
                selectedDay: _selectedDay,
                moments: filteredMoments,
                currentUserId: familyContext.userId,
                onSelectedDay: (day) {
                  setState(() {
                    _selectedDay = day;
                    _focusedDay = day;
                  });

                  _openDaySheet(
                    date: day,
                    moments: filteredMoments,
                    rhythmsByMomentId: rhythmsByMomentId,
                    activeInstance: activeInstance,
                  );
                },
                onPreviousWeek: () {
                  setState(() {
                    _focusedDay = _focusedDay.subtract(const Duration(days: 7));
                    _selectedDay = _focusedDay;
                  });
                },
                onNextWeek: () {
                  setState(() {
                    _focusedDay = _focusedDay.add(const Duration(days: 7));
                    _selectedDay = _focusedDay;
                  });
                },
              )
            else
              CalendarAgendaView(
                moments: filteredMoments,
                rhythmsByMomentId: rhythmsByMomentId,
                currentUserId: familyContext.userId,
                onMomentTap: (moment) {
                  _openMomentDetails(
                    moment: moment,
                    rhythm: rhythmsByMomentId[moment.id],
                    activeInstance: activeInstance,
                  );
                },
              ),

            if (_viewMode != CalendarViewMode.agenda) ...[
              const SizedBox(height: AppSpacing.xl),

              FamilyInsightSection(
                report: insightReport,
                onAddReminder: _scheduleInsightReminder,
                onOpenReminders: () {
                  _openMyRemindersPage();
                },
                onManageMoments: () {
                  _openMomentsPage();
                },
              ),

              const SizedBox(height: AppSpacing.sm),

              CalendarSupportCards(
                availability: bestAvailability,
                memory: latestMemory,
                onAvailabilityTap: bestAvailability == null
                    ? null
                    : () {
                        setState(() {
                          _viewMode = CalendarViewMode.week;
                          _focusedDay = bestAvailability.date;
                          _selectedDay = bestAvailability.date;
                        });
                      },
                onMemoryTap: latestMemory == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                MemoryDetailsScreen(memory: latestMemory),
                          ),
                        );
                      },
                onAddMemoryTap: familyContext.isAdult
                    ? () {
                        _openAddMemoryScreen();
                      }
                    : null,
                onAllMemoriesTap: () {
                  _openAllMemoriesScreen();
                },
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

  List<FamilyMoment> _applyFilters(List<FamilyMoment> moments) {
    final userId = _familyContext!.userId;

    final filtered = moments.where((moment) {
      final categoryMatch = _matchesSelectedCategory(moment);

      final mineMatch =
          !_mineOnly || moment.expectedParticipantIds.contains(userId);

      return categoryMatch && mineMatch;
    }).toList();

    filtered.sort((first, second) => first.startAt.compareTo(second.startAt));

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

  Future<void> _openDaySheet({
    required DateTime date,
    required List<FamilyMoment> moments,
    required Map<String, RhythmRecord> rhythmsByMomentId,
    required MomentInstance? activeInstance,
  }) async {
    final dayMoments = _momentsForDay(moments, date);

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
          rhythmsByMomentId: rhythmsByMomentId,
          currentUserId: _familyContext!.userId,
          onMomentTap: (moment) {
            Navigator.of(sheetContext).pop();

            _openMomentDetails(
              moment: moment,
              rhythm: rhythmsByMomentId[moment.id],
              activeInstance: activeInstance,
            );
          },
        );
      },
    );
  }

  Future<void> _openMomentDetails({
    required FamilyMoment moment,
    required RhythmRecord? rhythm,
    required MomentInstance? activeInstance,
  }) async {
    FamilyMemory? memory;

    try {
      memory = await AppDependencies.memoryRepository.getMemoryForMoment(
        familyId: _familyContext!.familyId,
        momentId: moment.id,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The Moment opened, but its Memory status could not be loaded.',
          ),
        ),
      );
    }

    if (!mounted) return;

    final activeForThisMoment = activeInstance?.momentId == moment.id;

    final canStartNow = _canStartMomentNow(
      moment: moment,
      activeInstance: activeInstance,
    );

    final liveActionLabel = activeForThisMoment
        ? 'Join Active Moment'
        : canStartNow
        ? 'Start This Now'
        : null;

    final liveActionHint = activeInstance != null && !activeForThisMoment
        ? 'Another family Moment is already live. End it before starting a new one.'
        : null;

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
          moment: moment,
          rhythm: rhythm,
          memory: memory,
          currentUserId: _familyContext!.userId,
          canEdit: _familyContext!.isAdult,
          liveActionLabel: liveActionLabel,
          liveActionHint: liveActionHint,
          onLiveAction: activeForThisMoment
              ? () {
                  Navigator.of(sheetContext).pop();
                  _openLiveMoment(activeInstance!);
                }
              : canStartNow
              ? () {
                  Navigator.of(sheetContext).pop();
                  _startMomentNow(moment);
                }
              : null,
          onEditMoment: () {
            Navigator.of(sheetContext).pop();

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MomentFormScreen(initialMoment: moment),
              ),
            );
          },
          onAddMemory:
              moment.status == MomentStatus.completed &&
                  memory == null &&
                  _familyContext!.isAdult
              ? () {
                  Navigator.of(sheetContext).pop();

                  _openAddMemoryScreen(initialMoment: moment);
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

                  _openAddMemoryScreen(initialMoment: moment);
                }
              : null,
        );
      },
    );
  }

  bool _canStartMomentNow({
    required FamilyMoment moment,
    required MomentInstance? activeInstance,
  }) {
    if (!_familyContext!.isAdult ||
        activeInstance != null ||
        _isStartingMoment) {
      return false;
    }

    if (moment.status == MomentStatus.cancelled ||
        moment.status == MomentStatus.completed ||
        moment.status == MomentStatus.missed) {
      return false;
    }

    if (moment.expectedParticipantIds.length < 2) {
      return false;
    }

    return moment.category != MomentCategory.responsibility &&
        moment.category != MomentCategory.memory;
  }

  Future<void> _startMomentNow(FamilyMoment moment) async {
    if (_isStartingMoment) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start this Moment now?'),
          content: Text(
            '“${moment.title}” will become live. '
            'You will be checked in automatically, '
            'and the shared timer will begin.',
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
            moment: moment,
            startedBy: _familyContext!.userId,
            source: MomentInstanceSource.calendar,
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

  Future<void> _openAddMemoryScreen({FamilyMoment? initialMoment}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddMemoryScreen(initialMoment: initialMoment),
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

  Future<void> _scheduleInsightReminder(FamilyInsightItem insight) async {
    if (_isSavingInsightReminder) {
      return;
    }

    if (insight.relatedReminderId != null) {
      await _openMyRemindersPage();
      return;
    }

    final recommendedTime = insight.recommendedReminderAt;

    if (recommendedTime == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No reminder time is available for this recommendation.',
          ),
        ),
      );

      return;
    }

    final familyContext = _familyContext!;
    final now = DateTime.now().toUtc();

    final dueAt = recommendedTime.isAfter(DateTime.now())
        ? recommendedTime
        : DateTime.now().add(const Duration(minutes: 30));

    final action = CareAction(
      id:
          'care_${familyContext.userId}_'
          '${DateTime.now().microsecondsSinceEpoch}',
      familyId: familyContext.familyId,
      momentId: insight.relatedMomentId,
      title: insight.suggestedActions.isEmpty
          ? insight.headline
          : insight.suggestedActions.first,
      reason: <String>[insight.summary, ...insight.reasons].join('\n'),
      assignedMemberId: familyContext.userId,
      dueAt: dueAt.toUtc(),
      status: CareActionStatus.pending,
      source: CareActionSource.calendar,
      evidenceType: EvidenceType.scheduledOnly,
      createdAt: now,
      updatedAt: now,
    );

    setState(() {
      _isSavingInsightReminder = true;
    });

    try {
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
}
