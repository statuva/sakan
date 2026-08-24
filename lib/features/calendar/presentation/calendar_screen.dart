import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/availability_block.dart';
import '../../../shared/models/care_action.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_memory.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/rhythm_record.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../../memories/presentation/add_memory_screen.dart';
import '../../memories/presentation/all_memories_screen.dart';
import '../../memories/presentation/memory_details_screen.dart';
import '../../moments/presentation/moment_form_screen.dart';
import '../../moments/presentation/moments_screen.dart';
import '../services/calendar_insight_service.dart';
import 'calendar_types.dart';
import 'widgets/ai_recommendation_dialog.dart';
import 'widgets/calendar_agenda_view.dart';
import 'widgets/calendar_day_sheet.dart';
import 'widgets/calendar_filter_bar.dart';
import 'widgets/calendar_mode_selector.dart';
import 'widgets/calendar_moment_details_sheet.dart';
import 'widgets/calendar_month_view.dart';
import 'widgets/calendar_palette.dart';
import 'widgets/calendar_support_cards.dart';
import 'widgets/calendar_week_view.dart';
import 'widgets/sakan_notice_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _insightService = CalendarInsightService();

  CurrentFamilyContext? _familyContext;

  Stream<List<FamilyMoment>>? _momentsStream;
  Stream<List<RhythmRecord>>? _rhythmsStream;
  Stream<List<AvailabilityBlock>>? _availabilityStream;
  Stream<List<Member>>? _membersStream;
  Stream<List<FamilyMemory>>? _memoriesStream;

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

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _momentsStream = AppDependencies.calendarRepository.watchMoments(
          familyId: familyContext.familyId,
        );
        _rhythmsStream = AppDependencies.calendarRepository.watchRhythms(
          familyId: familyContext.familyId,
        );
        _availabilityStream = AppDependencies.scheduleRepository
            .watchFamilyAvailability(familyId: familyContext.familyId);
        _membersStream = AppDependencies.currentFamilyService
            .watchFamilyMembers(familyContext.familyId);
        _memoriesStream = AppDependencies.memoryRepository.watchMemories(
          familyId: familyContext.familyId,
        );
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
        _momentsStream == null ||
        _rhythmsStream == null ||
        _availabilityStream == null ||
        _membersStream == null ||
        _memoriesStream == null) {
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

    return StreamBuilder<List<FamilyMoment>>(
      stream: _momentsStream,
      builder: (context, momentSnapshot) {
        if (momentSnapshot.hasError) {
          return _errorScaffold('We could not load the family moments.');
        }

        if (momentSnapshot.connectionState == ConnectionState.waiting &&
            !momentSnapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(message: 'Loading family moments…'),
            ),
          );
        }

        return StreamBuilder<List<RhythmRecord>>(
          stream: _rhythmsStream,
          builder: (context, rhythmSnapshot) {
            return StreamBuilder<List<AvailabilityBlock>>(
              stream: _availabilityStream,
              builder: (context, availabilitySnapshot) {
                return StreamBuilder<List<Member>>(
                  stream: _membersStream,
                  builder: (context, memberSnapshot) {
                    return StreamBuilder<List<FamilyMemory>>(
                      stream: _memoriesStream,
                      builder: (context, memorySnapshot) {
                        final allMoments =
                            momentSnapshot.data ?? <FamilyMoment>[];
                        final rhythms = rhythmSnapshot.data ?? <RhythmRecord>[];
                        final availability =
                            availabilitySnapshot.data ?? <AvailabilityBlock>[];
                        final members = memberSnapshot.data ?? <Member>[];
                        final memories =
                            memorySnapshot.data ?? <FamilyMemory>[];

                        final rhythmsByMomentId = <String, RhythmRecord>{
                          for (final rhythm in rhythms) rhythm.momentId: rhythm,
                        };

                        final filteredMoments = _applyFilters(allMoments);

                        final recommendation = _insightService
                            .buildRecommendation(
                              moments: allMoments,
                              rhythmsByMomentId: rhythmsByMomentId,
                              availability: availability,
                              members: members,
                              currentUserId: _familyContext!.userId,
                            );

                        final bestAvailability = _insightService
                            .findBestSharedWindow(
                              availability: availability,
                              members: members,
                            );

                        final memory = memories.isEmpty ? null : memories.first;

                        return _calendarScaffold(
                          filteredMoments: filteredMoments,
                          rhythmsByMomentId: rhythmsByMomentId,
                          recommendation: recommendation,
                          bestAvailability: bestAvailability,
                          memory: memory,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _calendarScaffold({
    required List<FamilyMoment> filteredMoments,
    required Map<String, RhythmRecord> rhythmsByMomentId,
    required CalendarRecommendation? recommendation,
    required CalendarAvailabilityWindow? bestAvailability,
    required FamilyMemory? memory,
  }) {
    final familyContext = _familyContext!;

    return Scaffold(
      backgroundColor: CalendarPalette.background,
      appBar: AppBar(
        title: const Text('Family Calendar'),
        backgroundColor: CalendarPalette.background,
        surfaceTintColor: Colors.transparent,
        actions: [
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
                  );
                },
              ),
            if (_viewMode != CalendarViewMode.agenda) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'WHAT SAKAN NOTICES',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: CalendarPalette.inkSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.45,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (recommendation != null)
                SakanNoticeCard(
                  recommendation: recommendation,
                  onOpenRecommendation: () {
                    _openRecommendationDialog(recommendation);
                  },
                )
              else
                _NoNoticeCard(onManageMoments: _openMomentsPage),
              const SizedBox(height: AppSpacing.sm),
              CalendarSupportCards(
                availability: bestAvailability,
                memory: memory,
                onAvailabilityTap: bestAvailability == null
                    ? null
                    : () {
                        setState(() {
                          _viewMode = CalendarViewMode.week;
                          _focusedDay = bestAvailability.date;
                          _selectedDay = bestAvailability.date;
                        });
                      },
                onMemoryTap: memory == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MemoryDetailsScreen(memory: memory),
                          ),
                        );
                      },
                onAddMemoryTap: familyContext.isAdult
                    ? () {
                        _openAddMemoryScreen();
                      }
                    : null,
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
    if (_activeCategoryFilters.isEmpty) return false;

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

  Future<void> _openMomentsPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MomentsScreen()));
  }

  Future<void> _openDaySheet({
    required DateTime date,
    required List<FamilyMoment> moments,
    required Map<String, RhythmRecord> rhythmsByMomentId,
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
            );
          },
        );
      },
    );
  }

  Future<void> _openMomentDetails({
    required FamilyMoment moment,
    required RhythmRecord? rhythm,
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
            'The Moment opened, but its '
            'Memory status could not be loaded.',
          ),
        ),
      );
    }

    if (!mounted) return;

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

  Future<void> _openRecommendationDialog(
    CalendarRecommendation recommendation,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AiRecommendationDialog(
          recommendation: recommendation,
          canSchedule: _familyContext!.isAdult,
          onScheduleReminder: () {
            return _scheduleReminder(recommendation);
          },
        );
      },
    );
  }

  Future<void> _scheduleReminder(CalendarRecommendation recommendation) async {
    final familyContext = _familyContext!;
    final now = DateTime.now().toUtc();

    final action = CareAction(
      id: 'care_${familyContext.userId}_${DateTime.now().microsecondsSinceEpoch}',
      familyId: familyContext.familyId,
      momentId: recommendation.moment.id,
      title: 'Prepare for ${recommendation.moment.title}',
      reason: recommendation.preparationSteps.join(' '),
      assignedMemberId: familyContext.userId,
      dueAt: recommendation.recommendedReminderAt.toUtc(),
      status: CareActionStatus.pending,
      source: CareActionSource.calendar,
      evidenceType: EvidenceType.scheduledOnly,
      createdAt: now,
      updatedAt: now,
    );

    await AppDependencies.careActionRepository.createCareAction(action);

    final notificationService = AppDependencies.reminderNotificationService;

    final notificationScheduled = await notificationService.scheduleReminder(
      action,
      requestPermission: true,
    );

    if (!mounted) return;

    final message = !notificationService.supportsScheduling
        ? 'Reminder added to My Reminders. '
              'Notification delivery must be '
              'tested on Android.'
        : notificationScheduled
        ? 'Reminder added and notification scheduled.'
        : 'Reminder added to My Reminders. '
              'Notifications are currently disabled.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NoNoticeCard extends StatelessWidget {
  const _NoNoticeCard({required this.onManageMoments});

  final VoidCallback onManageMoments;

  @override
  Widget build(BuildContext context) {
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
          Text(
            'No urgent action right now',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: CalendarPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sakan will surface an upcoming milestone, care need, or drifting rhythm when the current data supports it.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: CalendarPalette.inkSoft),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: onManageMoments,
            child: const Text('Manage Moments'),
          ),
        ],
      ),
    );
  }
}
