import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/core/theme/app_colors.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/features/memories/presentation/add_memory_screen.dart';
import 'package:sakan/features/memories/presentation/memory_details_screen.dart';
import 'package:sakan/shared/models/current_family_context.dart';
import 'package:sakan/shared/models/family_memory.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/rhythm_record.dart';
import 'package:sakan/shared/utils/moment_visuals.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';
import 'package:sakan/shared/widgets/feedback/app_error_state.dart';
import 'package:sakan/shared/widgets/feedback/app_loading_state.dart';

import 'moment_form_screen.dart';

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
  Stream<List<FamilyMemory>>? _memoriesStream;

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

        _memoriesStream = AppDependencies.memoryRepository.watchMemories(
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

  Future<void> _openMemoryEditor(FamilyMoment moment) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddMemoryScreen(initialMoment: moment)),
    );

    if (saved != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Family Memory saved.')));
  }

  Future<void> _openMemory(FamilyMemory memory) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemoryDetailsScreen(memory: memory)),
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
      builder: (sheetContext) {
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
                  Navigator.of(sheetContext).pop();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }

  Scaffold _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Moments')),
      body: SafeArea(
        child: AppErrorState(message: message, onRetry: _loadMoments),
      ),
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
        _rhythmsStream == null ||
        _memoriesStream == null) {
      return _errorScaffold(_errorMessage ?? 'Family Moments are unavailable.');
    }

    final canEdit = _familyContext!.isAdult;

    return StreamBuilder<List<FamilyMoment>>(
      stream: _momentsStream,
      builder: (context, momentSnapshot) {
        if (momentSnapshot.hasError) {
          return _errorScaffold('We could not load family moments.');
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
            if (rhythmSnapshot.hasError) {
              return _errorScaffold('We could not load family rhythms.');
            }

            return StreamBuilder<List<FamilyMemory>>(
              stream: _memoriesStream,
              builder: (context, memorySnapshot) {
                if (memorySnapshot.hasError) {
                  return _errorScaffold('We could not load family memories.');
                }

                if (memorySnapshot.connectionState == ConnectionState.waiting &&
                    !memorySnapshot.hasData) {
                  return const Scaffold(
                    body: SafeArea(
                      child: AppLoadingState(
                        message: 'Loading family memories…',
                      ),
                    ),
                  );
                }

                final moments = momentSnapshot.data ?? <FamilyMoment>[];

                final rhythms = rhythmSnapshot.data ?? <RhythmRecord>[];

                final memories = memorySnapshot.data ?? <FamilyMemory>[];

                final rhythmsByMomentId = <String, RhythmRecord>{
                  for (final rhythm in rhythms) rhythm.momentId: rhythm,
                };

                final memoriesByMomentId = <String, FamilyMemory>{};

                // watchMemories returns newest first.
                // putIfAbsent keeps the newest record
                // if older duplicate data exists.
                for (final memory in memories) {
                  memoriesByMomentId.putIfAbsent(memory.momentId, () => memory);
                }

                final filtered = _applyFilters(
                  moments: moments,
                  rhythmsByMomentId: rhythmsByMomentId,
                );

                final attentionCount = moments.where((moment) {
                  return _needsAttention(
                    moment: moment,
                    rhythm: rhythmsByMomentId[moment.id],
                  );
                }).length;

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
                            child: Text(
                              'No family moments '
                              'match this view.',
                            ),
                          )
                        else
                          ...filtered.map((moment) {
                            final rhythm = rhythmsByMomentId[moment.id];

                            final memory = memoriesByMomentId[moment.id];

                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: _MomentLibraryCard(
                                moment: moment,
                                rhythm: rhythm,
                                memory: memory,
                                canManageMemory: canEdit,
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
                                onAddMemory:
                                    moment.status == MomentStatus.completed &&
                                        memory == null &&
                                        canEdit
                                    ? () {
                                        _openMemoryEditor(moment);
                                      }
                                    : null,
                                onViewMemory: memory == null
                                    ? null
                                    : () {
                                        _openMemory(memory);
                                      },
                                onEditMemory: memory != null && canEdit
                                    ? () {
                                        _openMemoryEditor(moment);
                                      }
                                    : null,
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
    required this.memory,
    required this.canManageMemory,
    required this.onTap,
    this.onAddMemory,
    this.onViewMemory,
    this.onEditMemory,
  });

  final FamilyMoment moment;
  final RhythmRecord? rhythm;
  final FamilyMemory? memory;

  final bool canManageMemory;
  final VoidCallback onTap;

  final VoidCallback? onAddMemory;
  final VoidCallback? onViewMemory;
  final VoidCallback? onEditMemory;

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

              if (moment.status == MomentStatus.completed) ...[
                const SizedBox(height: AppSpacing.md),

                const Divider(),

                const SizedBox(height: AppSpacing.sm),

                _MomentMemorySection(
                  memory: memory,
                  canManageMemory: canManageMemory,
                  onAddMemory: onAddMemory,
                  onViewMemory: onViewMemory,
                  onEditMemory: onEditMemory,
                ),
              ],
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

class _MomentMemorySection extends StatelessWidget {
  const _MomentMemorySection({
    required this.memory,
    required this.canManageMemory,
    required this.onAddMemory,
    required this.onViewMemory,
    required this.onEditMemory,
  });

  final FamilyMemory? memory;
  final bool canManageMemory;

  final VoidCallback? onAddMemory;
  final VoidCallback? onViewMemory;
  final VoidCallback? onEditMemory;

  @override
  Widget build(BuildContext context) {
    final hasMemory = memory != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasMemory
                  ? Icons.auto_stories_outlined
                  : Icons.bookmark_add_outlined,
              size: 21,
              color: hasMemory ? AppColors.primary : AppColors.textSecondary,
            ),

            const SizedBox(width: AppSpacing.sm),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasMemory ? 'Memory saved' : 'No Memory saved yet',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),

                  const SizedBox(height: 3),

                  Text(
                    hasMemory
                        ? 'A family note is connected '
                              'to this completed Moment.'
                        : canManageMemory
                        ? 'Preserve what your family '
                              'would like to remember.'
                        : 'An adult can preserve a '
                              'Memory for this Moment.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),

        if (hasMemory || onAddMemory != null) ...[
          const SizedBox(height: AppSpacing.sm),

          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (!hasMemory && onAddMemory != null)
                OutlinedButton.icon(
                  onPressed: onAddMemory,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Add Memory'),
                ),

              if (hasMemory && onViewMemory != null)
                OutlinedButton.icon(
                  onPressed: onViewMemory,
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: const Text('View Memory'),
                ),

              if (hasMemory && onEditMemory != null)
                TextButton.icon(
                  onPressed: onEditMemory,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('Edit Memory'),
                ),
            ],
          ),
        ],
      ],
    );
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
