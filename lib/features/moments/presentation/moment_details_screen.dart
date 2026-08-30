import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_memory.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/utils/moment_visuals.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import 'moment_form_screen.dart';

class MomentDetailsScreen extends StatefulWidget {
  const MomentDetailsScreen({required this.initialMoment, super.key});

  final FamilyMoment initialMoment;

  @override
  State<MomentDetailsScreen> createState() => _MomentDetailsScreenState();
}

class _MomentDetailsScreenState extends State<MomentDetailsScreen> {
  CurrentFamilyContext? _familyContext;

  Stream<List<FamilyMoment>>? _momentsStream;
  Stream<List<Member>>? _membersStream;
  Stream<List<FamilyMemory>>? _memoriesStream;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
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
        _errorMessage = 'We could not load this Family Moment.';
      });
    }
  }

  FamilyMoment? _findMoment(List<FamilyMoment> moments) {
    for (final moment in moments) {
      if (moment.id == widget.initialMoment.id) {
        return moment;
      }
    }

    return null;
  }

  Future<void> _editMoment(FamilyMoment moment) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MomentFormScreen(initialMoment: moment),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Family Moment updated.')));
    }
  }

  Scaffold _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moment Details')),
      body: SafeArea(
        child: AppErrorState(message: message, onRetry: _loadDetails),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading Moment details…'),
        ),
      );
    }

    if (_familyContext == null ||
        _momentsStream == null ||
        _membersStream == null ||
        _memoriesStream == null) {
      return _errorScaffold(
        _errorMessage ?? 'This Family Moment is unavailable.',
      );
    }

    return StreamBuilder<List<FamilyMoment>>(
      stream: _momentsStream,
      builder: (context, momentSnapshot) {
        if (momentSnapshot.hasError) {
          return _errorScaffold('We could not load this Family Moment.');
        }

        if (momentSnapshot.connectionState == ConnectionState.waiting &&
            !momentSnapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(message: 'Loading Moment details…'),
            ),
          );
        }

        final moments = momentSnapshot.data ?? <FamilyMoment>[];

        final moment = _findMoment(moments);

        if (moment == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Moment Details')),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_motion_outlined, size: 52),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'This Moment is no longer available.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                        child: const Text('Back to Moments'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return StreamBuilder<List<Member>>(
          stream: _membersStream,
          builder: (context, memberSnapshot) {
            if (memberSnapshot.hasError) {
              return _errorScaffold(
                'We could not load the associated members.',
              );
            }

            final members = memberSnapshot.data ?? <Member>[];

            return StreamBuilder<List<FamilyMemory>>(
              stream: _memoriesStream,
              builder: (context, memorySnapshot) {
                if (memorySnapshot.hasError) {
                  return _errorScaffold('We could not load the Memory count.');
                }

                final memories = memorySnapshot.data ?? <FamilyMemory>[];

                final relatedMemories = memories.where((memory) {
                  return memory.momentId == moment.id;
                }).toList();

                final associatedMembers = _associatedMembers(
                  moment: moment,
                  members: members,
                );

                return _detailsScaffold(
                  moment: moment,
                  associatedMembers: associatedMembers,
                  memoryCount: relatedMemories.length,
                );
              },
            );
          },
        );
      },
    );
  }

  List<Member> _associatedMembers({
    required FamilyMoment moment,
    required List<Member> members,
  }) {
    final byId = <String, Member>{
      for (final member in members) member.id: member,
    };

    final result = <Member>[];

    for (final memberId in moment.expectedParticipantIds) {
      final member = byId[memberId];

      if (member != null) {
        result.add(member);
      }
    }

    result.sort(
      (first, second) => first.displayName.compareTo(second.displayName),
    );

    return result;
  }

  Widget _detailsScaffold({
    required FamilyMoment moment,
    required List<Member> associatedMembers,
    required int memoryCount,
  }) {
    final canEdit = _familyContext!.isAdult;

    final categoryColor = momentCategoryColor(moment.category);

    return Scaffold(
      appBar: AppBar(title: const Text('Moment Details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            96,
          ),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: categoryColor.withAlpha(24),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _categoryIcon(moment.category),
                          color: categoryColor,
                        ),
                      ),

                      const SizedBox(width: AppSpacing.md),

                      Expanded(
                        child: Text(
                          moment.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _InformationLabel(
                        label: momentCategoryLabel(moment.category),
                        color: categoryColor,
                      ),
                      _InformationLabel(
                        label: momentTypeLabel(moment.type),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      if (moment.type == MomentType.recurring)
                        _InformationLabel(
                          label: _frequencyLabel(moment.expectedIntervalDays),
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                    ],
                  ),

                  if (canEdit) ...[
                    const SizedBox(height: AppSpacing.lg),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _editMoment(moment);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit this Moment'),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            const _SectionTitle(title: 'Importance'),

            const SizedBox(height: AppSpacing.sm),

            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: _ImportanceDots(
                      value: moment.importanceLevel,
                      color: categoryColor,
                    ),
                  ),
                  Text(
                    '${moment.importanceLevel}/5',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: categoryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            const _SectionTitle(title: 'About this Moment'),

            const SizedBox(height: AppSpacing.sm),

            AppCard(
              child: Text(
                moment.notes?.trim().isNotEmpty == true
                    ? moment.notes!.trim()
                    : 'No description has been added yet.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            const _SectionTitle(title: 'Associated Members'),

            const SizedBox(height: AppSpacing.sm),

            AppCard(
              child: associatedMembers.isEmpty
                  ? const Text(
                      'No active family members are currently associated with this Moment.',
                    )
                  : Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: associatedMembers.map((member) {
                        return Chip(
                          avatar: CircleAvatar(
                            child: Text(_initial(member.displayName)),
                          ),
                          label: Text(member.displayName),
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: AppSpacing.xl),

            _SectionTitle(
              title: moment.type == MomentType.recurring
                  ? 'Usual Timing'
                  : 'Planned Timing',
            ),

            const SizedBox(height: AppSpacing.sm),

            AppCard(
              child: Column(
                children: [
                  if (moment.type == MomentType.recurring)
                    _DetailLine(
                      icon: Icons.repeat_rounded,
                      title: 'Frequency',
                      value: _frequencyLabel(moment.expectedIntervalDays),
                    ),

                  if (moment.type == MomentType.recurring) const Divider(),

                  _DetailLine(
                    icon: Icons.calendar_today_outlined,
                    title: moment.type == MomentType.recurring
                        ? 'Usual day'
                        : 'Date',
                    value: moment.type == MomentType.recurring
                        ? DateFormat('EEEE').format(moment.startAt.toLocal())
                        : DateFormat(
                            'EEEE, d MMMM y',
                          ).format(moment.startAt.toLocal()),
                  ),

                  const Divider(),

                  _DetailLine(
                    icon: Icons.access_time_outlined,
                    title: 'Time',
                    value: _timeRange(moment),
                  ),

                  if (moment.location?.trim().isNotEmpty == true) ...[
                    const Divider(),
                    _DetailLine(
                      icon: Icons.location_on_outlined,
                      title: 'Location',
                      value: moment.location!.trim(),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            const _SectionTitle(title: 'Evidence Method'),

            const SizedBox(height: AppSpacing.sm),

            AppCard(
              child: _DetailLine(
                icon: Icons.verified_outlined,
                title: 'Configured method',
                value: _evidenceLabel(moment.evidenceType),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            const _SectionTitle(title: 'Memories'),

            const SizedBox(height: AppSpacing.sm),

            AppCard(
              child: _DetailLine(
                icon: Icons.photo_library_outlined,
                title: 'Saved Memories',
                value: memoryCount == 0
                    ? 'No Memories saved yet'
                    : '$memoryCount saved '
                          '${memoryCount == 1 ? 'Memory' : 'Memories'}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeRange(FamilyMoment moment) {
    final start = moment.startAt.toLocal();
    final end = moment.endAt?.toLocal();

    if (end == null) {
      return DateFormat('h:mm a').format(start);
    }

    return '${DateFormat('h:mm a').format(start)}'
        '–${DateFormat('h:mm a').format(end)}';
  }

  String _frequencyLabel(int? days) {
    return switch (days) {
      null => 'Not configured',
      1 => 'Daily',
      7 => 'Weekly',
      14 => 'Every 2 weeks',
      30 => 'Monthly',
      90 => 'Every 3 months',
      365 => 'Yearly',
      _ => 'Every $days days',
    };
  }

  String _evidenceLabel(EvidenceType type) {
    return switch (type) {
      EvidenceType.scheduledOnly => 'Scheduled occurrence',
      EvidenceType.userConfirmed => 'Member confirmation',
      EvidenceType.photoAttached => 'Memory or photo evidence',
      EvidenceType.manual => 'Manual check-in',
    };
  }

  IconData _categoryIcon(MomentCategory category) {
    return switch (category) {
      MomentCategory.tradition => Icons.eco_outlined,
      MomentCategory.milestone => Icons.star_border_rounded,
      MomentCategory.responsibility => Icons.task_alt_outlined,
      MomentCategory.care => Icons.favorite_border_rounded,
      MomentCategory.familyTime => Icons.family_restroom_outlined,
      MomentCategory.memory => Icons.photo_library_outlined,
    };
  }

  String _initial(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      return '?';
    }

    return trimmed[0].toUpperCase();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _InformationLabel extends StatelessWidget {
  const _InformationLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
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
      children: List.generate(5, (index) {
        final isFilled = index < safeValue;

        return Container(
          width: 13,
          height: 13,
          margin: EdgeInsets.only(right: index == 4 ? 0 : 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? color : Colors.transparent,
            border: Border.all(color: isFilled ? color : color.withAlpha(90)),
          ),
        );
      }),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),

        const SizedBox(width: AppSpacing.md),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),

              const SizedBox(height: 4),

              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
