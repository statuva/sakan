import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/utils/moment_visuals.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import 'moment_details_screen.dart';
import 'moment_form_screen.dart';

enum _MomentLibraryFilter { all, recurring, oneTime }

class MomentsScreen extends StatefulWidget {
  const MomentsScreen({super.key});

  @override
  State<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends State<MomentsScreen> {
  CurrentFamilyContext? _familyContext;
  Stream<List<FamilyMoment>>? _momentsStream;

  _MomentLibraryFilter _filter = _MomentLibraryFilter.all;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMoments();
  }

  Future<void> _loadMoments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      final momentsStream = AppDependencies.calendarRepository.watchMoments(
        familyId: familyContext.familyId,
      );

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _momentsStream = momentsStream;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load your family Moments.';
      });
    }
  }

  List<FamilyMoment> _applyFilter(List<FamilyMoment> moments) {
    final filtered = moments.where((moment) {
      return switch (_filter) {
        _MomentLibraryFilter.all => true,
        _MomentLibraryFilter.recurring => moment.type == MomentType.recurring,
        _MomentLibraryFilter.oneTime => moment.type == MomentType.singular,
      };
    }).toList();

    filtered.sort((first, second) {
      final importanceResult = second.importanceLevel.compareTo(
        first.importanceLevel,
      );

      if (importanceResult != 0) {
        return importanceResult;
      }

      return first.title.toLowerCase().compareTo(second.title.toLowerCase());
    });

    return filtered;
  }

  Future<void> _openMomentForm() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const MomentFormScreen()));

    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Family Moment saved.')));
    }
  }

  Future<void> _openMomentDetails(FamilyMoment moment) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MomentDetailsScreen(initialMoment: moment),
      ),
    );
  }

  Scaffold _errorScaffold(String message) {
    return Scaffold(
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
          child: AppLoadingState(message: 'Loading family Moments…'),
        ),
      );
    }

    if (_familyContext == null || _momentsStream == null) {
      return _errorScaffold(_errorMessage ?? 'Family Moments are unavailable.');
    }

    final canEdit = _familyContext!.isAdult;

    return StreamBuilder<List<FamilyMoment>>(
      stream: _momentsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorScaffold('We could not load family Moments.');
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(message: 'Loading family Moments…'),
            ),
          );
        }

        final allMoments = snapshot.data ?? <FamilyMoment>[];

        final visibleMoments = _applyFilter(allMoments);

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                108,
              ),
              children: [
                _MomentsHeader(
                  canGoBack: Navigator.of(context).canPop(),
                  canAddMoment: canEdit,
                  onBack: () {
                    Navigator.of(context).maybePop();
                  },
                  onAddMoment: _openMomentForm,
                ),

                const SizedBox(height: AppSpacing.xl),

                _MomentFilterBar(
                  selectedFilter: _filter,
                  onChanged: (filter) {
                    setState(() {
                      _filter = filter;
                    });
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                if (visibleMoments.isEmpty)
                  _EmptyMomentsState(
                    canAddMoment: canEdit,
                    onAddMoment: _openMomentForm,
                  )
                else
                  ...visibleMoments.map(
                    (moment) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _MomentArchiveCard(
                        moment: moment,
                        onTap: () {
                          _openMomentDetails(moment);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MomentsHeader extends StatelessWidget {
  const _MomentsHeader({
    required this.canGoBack,
    required this.canAddMoment,
    required this.onBack,
    required this.onAddMoment,
  });

  final bool canGoBack;
  final bool canAddMoment;
  final VoidCallback onBack;
  final VoidCallback onAddMoment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        if (canGoBack) ...[
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
        ],

        Expanded(
          child: Text(
            'Family Moments',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),

        if (canAddMoment)
          IconButton.filled(
            tooltip: 'Add Family Moment',
            onPressed: onAddMoment,
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.add_rounded),
          ),
      ],
    );
  }
}

class _MomentFilterBar extends StatelessWidget {
  const _MomentFilterBar({
    required this.selectedFilter,
    required this.onChanged,
  });

  final _MomentLibraryFilter selectedFilter;
  final ValueChanged<_MomentLibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _MomentLibraryFilter.values.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              label: Text(_label(filter)),
              selected: selectedFilter == filter,
              showCheckmark: false,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(
                color: selectedFilter == filter
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                onChanged(filter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(_MomentLibraryFilter filter) {
    return switch (filter) {
      _MomentLibraryFilter.all => 'All',
      _MomentLibraryFilter.recurring => 'Recurring',
      _MomentLibraryFilter.oneTime => 'One-time',
    };
  }
}

class _MomentArchiveCard extends StatelessWidget {
  const _MomentArchiveCard({required this.moment, required this.onTap});

  final FamilyMoment moment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryColor = momentCategoryColor(moment.category);

    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      moment.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              Row(
                children: [
                  _MomentCategoryLabel(
                    label: momentCategoryLabel(moment.category),
                    color: categoryColor,
                  ),

                  const Spacer(),

                  Tooltip(
                    message: 'Importance ${moment.importanceLevel} out of 5',
                    child: _ImportanceDots(
                      value: moment.importanceLevel,
                      color: categoryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MomentCategoryLabel extends StatelessWidget {
  const _MomentCategoryLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ImportanceDots extends StatelessWidget {
  const _ImportanceDots({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(1, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Importance',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(width: 7),

        ...List.generate(5, (index) {
          final isFilled = index < safeValue;

          return Container(
            width: 7,
            height: 7,
            margin: EdgeInsets.only(left: index == 0 ? 0 : 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? color : Colors.transparent,
              border: Border.all(color: isFilled ? color : color.withAlpha(90)),
            ),
          );
        }),
      ],
    );
  }
}

class _EmptyMomentsState extends StatelessWidget {
  const _EmptyMomentsState({
    required this.canAddMoment,
    required this.onAddMoment,
  });

  final bool canAddMoment;
  final VoidCallback onAddMoment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_motion_outlined,
            size: 52,
            color: Theme.of(context).colorScheme.primary,
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            'No Moments in this view',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            canAddMoment
                ? 'Create a Moment that matters to your family.'
                : 'An adult or family admin can add Family Moments.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          if (canAddMoment) ...[
            const SizedBox(height: AppSpacing.lg),

            FilledButton.icon(
              onPressed: onAddMoment,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Family Moment'),
            ),
          ],
        ],
      ),
    );
  }
}
