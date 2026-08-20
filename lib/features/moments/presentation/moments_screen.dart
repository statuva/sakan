import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/current_family_context.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/utils/moment_visuals.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';
import 'package:sakan/shared/widgets/feedback/app_error_state.dart';
import 'package:sakan/shared/widgets/feedback/app_loading_state.dart';
import 'package:sakan/shared/models/rhythm_record.dart';
import 'moment_form_screen.dart';
import 'package:sakan/core/theme/app_colors.dart';

enum _MomentLibraryFilter { all, recurring, oneTime, care, needsAttention }

class MomentsScreen extends StatefulWidget {
  const MomentsScreen({super.key});

  @override
  State<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends State<MomentsScreen> {
  final _searchController = TextEditingController();

  CurrentFamilyContext? _familyContext;

  Stream<List<FamilyMoment>>? _momentsStream;
  Stream<List<RhythmRecord>>? _rhythmsStream;

  _MomentLibraryFilter _filter = _MomentLibraryFilter.all;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMoments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMoments() async {
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

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load your family moments.';
      });
    }
  }

  bool _needsAttention({required FamilyMoment moment, RhythmRecord? rhythm}) {
    if (moment.status == MomentStatus.missed) {
      return true;
    }

    if (rhythm?.status == RhythmStatus.drifting) {
      return true;
    }

    if (moment.category == MomentCategory.care &&
        moment.status == MomentStatus.scheduled) {
      final daysUntil = moment.startAt
          .toLocal()
          .difference(DateTime.now())
          .inDays;

      return daysUntil >= 0 && daysUntil <= 7;
    }

    return false;
  }

  List<FamilyMoment> _applyFilters({
    required List<FamilyMoment> moments,
    required Map<String, RhythmRecord> rhythmsByMomentId,
  }) {
    final search = _searchController.text.trim().toLowerCase();

    final filtered = moments.where((moment) {
      final matchesSearch =
          search.isEmpty ||
          moment.title.toLowerCase().contains(search) ||
          momentCategoryLabel(moment.category).toLowerCase().contains(search);

      if (!matchesSearch) {
        return false;
      }

      return switch (_filter) {
        _MomentLibraryFilter.all => true,
        _MomentLibraryFilter.recurring => moment.type == MomentType.recurring,
        _MomentLibraryFilter.oneTime => moment.type == MomentType.singular,
        _MomentLibraryFilter.care => moment.category == MomentCategory.care,
        _MomentLibraryFilter.needsAttention => _needsAttention(
          moment: moment,
          rhythm: rhythmsByMomentId[moment.id],
        ),
      };
    }).toList();

    filtered.sort((first, second) {
      final firstAttention = _needsAttention(
        moment: first,
        rhythm: rhythmsByMomentId[first.id],
      );

      final secondAttention = _needsAttention(
        moment: second,
        rhythm: rhythmsByMomentId[second.id],
      );

      if (firstAttention != secondAttention) {
        return firstAttention ? -1 : 1;
      }

      return first.startAt.compareTo(second.startAt);
    });

    return filtered;
  }

  Future<void> _openMomentForm({FamilyMoment? moment}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MomentFormScreen(initialMoment: moment),
      ),
    );
  }

  void _showReadOnlyDetails({
    required FamilyMoment moment,
    RhythmRecord? rhythm,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                moment.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              const SizedBox(height: AppSpacing.md),

              Text(
                '${momentTypeLabel(moment.type)} · '
                '${momentCategoryLabel(moment.category)}',
              ),

              const SizedBox(height: AppSpacing.md),

              Text(
                'Status: '
                '${momentOverviewStatusLabel(moment: moment, rhythm: rhythm)}',
              ),

              const SizedBox(height: AppSpacing.md),

              Text(
                'Expected participants: '
                '${moment.expectedParticipantIds.length}',
              ),

              const SizedBox(height: AppSpacing.md),

              Text(
                DateFormat(
                  'EEEE, d MMMM y · h:mm a',
                ).format(moment.startAt.toLocal()),
              ),

              const SizedBox(height: AppSpacing.xl),

              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading family moments…'),
        ),
      );
    }

    if (_familyContext == null ||
        _momentsStream == null ||
        _rhythmsStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Moments')),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'Family Moments are unavailable.',
            onRetry: _loadMoments,
          ),
        ),
      );
    }

    final canEdit = _familyContext!.isAdult;

    return StreamBuilder<List<FamilyMoment>>(
      stream: _momentsStream,
      builder: (context, momentSnapshot) {
        if (momentSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Family Moments')),
            body: SafeArea(
              child: AppErrorState(
                message: 'We could not load family moments.',
                onRetry: _loadMoments,
              ),
            ),
          );
        }

        return StreamBuilder<List<RhythmRecord>>(
          stream: _rhythmsStream,
          builder: (context, rhythmSnapshot) {
            final moments = momentSnapshot.data ?? <FamilyMoment>[];

            final rhythms = rhythmSnapshot.data ?? <RhythmRecord>[];

            final rhythmsByMomentId = <String, RhythmRecord>{
              for (final rhythm in rhythms) rhythm.momentId: rhythm,
            };

            final filtered = _applyFilters(
              moments: moments,
              rhythmsByMomentId: rhythmsByMomentId,
            );

            final attentionCount = moments
                .where(
                  (moment) => _needsAttention(
                    moment: moment,
                    rhythm: rhythmsByMomentId[moment.id],
                  ),
                )
                .length;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Family Moments'),
                actions: [
                  if (canEdit)
                    IconButton(
                      tooltip: 'Add Family Moment',
                      onPressed: () {
                        _openMomentForm();
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
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
                    Text(
                      '${moments.length} moments · '
                      '$attentionCount need attention',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search family moments',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: AppSpacing.md),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _MomentLibraryFilter.values.map((filter) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xs,
                            ),
                            child: _LibraryFilterChip(
                              filter: filter,
                              selected: _filter == filter,
                              onTap: () {
                                setState(() {
                                  _filter = filter;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    if (filtered.isEmpty)
                      const AppCard(
                        child: Text('No family moments match this view.'),
                      )
                    else
                      ...filtered.map((moment) {
                        final rhythm = rhythmsByMomentId[moment.id];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _MomentLibraryCard(
                            moment: moment,
                            rhythm: rhythm,
                            onTap: () {
                              if (canEdit) {
                                _openMomentForm(moment: moment);
                              } else {
                                _showReadOnlyDetails(
                                  moment: moment,
                                  rhythm: rhythm,
                                );
                              }
                            },
                          ),
                        );
                      }),

                    if (canEdit) ...[
                      const SizedBox(height: AppSpacing.lg),

                      AppPrimaryButton(
                        label: 'Add a Family Moment',
                        icon: Icons.add_rounded,
                        onPressed: () {
                          _openMomentForm();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LibraryFilterChip extends StatelessWidget {
  const _LibraryFilterChip({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final _MomentLibraryFilter filter;
  final bool selected;
  final VoidCallback onTap;

  Color get _color {
    return switch (filter) {
      _MomentLibraryFilter.all => AppColors.textPrimary,
      _MomentLibraryFilter.recurring => AppColors.primary,
      _MomentLibraryFilter.oneTime => AppColors.upcoming,
      _MomentLibraryFilter.care => AppColors.secondary,
      _MomentLibraryFilter.needsAttention => AppColors.warning,
    };
  }

  String get _label {
    return switch (filter) {
      _MomentLibraryFilter.all => 'All',
      _MomentLibraryFilter.recurring => 'Recurring',
      _MomentLibraryFilter.oneTime => 'One-time',
      _MomentLibraryFilter.care => 'Care',
      _MomentLibraryFilter.needsAttention => 'Needs Attention',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(_label),
      selected: selected,
      selectedColor: _color,
      backgroundColor: _color.withAlpha(20),
      side: BorderSide(color: _color.withAlpha(90)),
      labelStyle: TextStyle(
        color: selected ? Colors.white : _color,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) {
        onTap();
      },
    );
  }
}

class _MomentLibraryCard extends StatelessWidget {
  const _MomentLibraryCard({
    required this.moment,
    required this.rhythm,
    required this.onTap,
  });

  final FamilyMoment moment;
  final RhythmRecord? rhythm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeColor = momentTypeColor(moment.type);

    final statusColor = momentOverviewStatusColor(
      moment: moment,
      rhythm: rhythm,
    );

    final statusLabel = momentOverviewStatusLabel(
      moment: moment,
      rhythm: rhythm,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: typeColor, width: 5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      moment.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xs),

              Text(
                '${momentCategoryLabel(moment.category)} · '
                '${moment.type == MomentType.recurring ? _recurrenceText(moment, rhythm) : DateFormat('d MMM y').format(moment.startAt.toLocal())}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Text(
                    'Importance',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  const SizedBox(width: 8),

                  ...List.generate(
                    5,
                    (index) => Icon(
                      Icons.circle,
                      size: 8,
                      color: index < moment.importanceLevel
                          ? AppColors.accent
                          : AppColors.border,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  _SmallInfo(
                    icon: Icons.group_outlined,
                    label:
                        '${moment.expectedParticipantIds.length} participants',
                  ),
                  _SmallInfo(
                    icon: Icons.calendar_today_outlined,
                    label: DateFormat(
                      'EEE, d MMM · h:mm a',
                    ).format(moment.startAt.toLocal()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _recurrenceText(FamilyMoment moment, RhythmRecord? rhythm) {
    final interval =
        moment.expectedIntervalDays ?? rhythm?.expectedIntervalDays ?? 7;

    if (rhythm != null && rhythm.lastOccurrenceAt != null) {
      return '${rhythm.currentGapDays}d since last · '
          'usual ${interval}d';
    }

    return 'Every $interval days';
  }
}

class _SmallInfo extends StatelessWidget {
  const _SmallInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
