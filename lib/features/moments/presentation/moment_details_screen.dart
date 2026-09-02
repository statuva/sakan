import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/services/moment_schedule_resolver.dart';
import '../../../shared/utils/moment_visuals.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../../../shared/widgets/people/sakan_member_avatar.dart';
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
        _membersStream == null) {
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

        final moment = _findMoment(momentSnapshot.data ?? <FamilyMoment>[]);

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
                        onPressed: () => Navigator.of(context).pop(true),
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

            final associatedMembers = _associatedMembers(
              moment: moment,
              members: memberSnapshot.data ?? <Member>[],
            );

            return _detailsScaffold(
              moment: moment,
              associatedMembers: associatedMembers,
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
                        onPressed: () => _editMoment(moment),
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              child: associatedMembers.isEmpty
                  ? const Text(
                      'No active family members are currently associated with this Moment.',
                    )
                  : SizedBox(
                      height: 78,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: associatedMembers.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          return SakanMemberAvatar(
                            member: associatedMembers[index],
                            diameter: 50,
                            width: 62,
                          );
                        },
                      ),
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
                  if (moment.type == MomentType.recurring) ...[
                    _DetailLine(
                      icon: Icons.repeat_rounded,
                      title: 'Frequency',
                      value: _frequencyLabel(moment.expectedIntervalDays),
                    ),
                    const Divider(),
                    _DetailLine(
                      icon: Icons.calendar_today_outlined,
                      title: 'Preferred day',
                      value: _recurringDayLabel(moment),
                    ),
                    const Divider(),
                  ] else ...[
                    _DetailLine(
                      icon: Icons.calendar_today_outlined,
                      title: 'Date',
                      value: DateFormat(
                        'EEEE, d MMMM y',
                      ).format(moment.startAt.toLocal()),
                    ),
                    const Divider(),
                  ],
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
            const _SectionTitle(title: 'How occurrences are confirmed'),
            const SizedBox(height: AppSpacing.sm),
            const AppCard(
              child: _DetailLine(
                icon: Icons.verified_outlined,
                title: 'Confirmation',
                value: 'Manual check-in or Today Review',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeRange(FamilyMoment moment) {
    final startMinutes = moment.resolvedPreferredStartMinutes;
    final endMinutes = moment.resolvedPreferredEndMinutes;
    final reference = DateTime(2026, 1, 1);
    final start = DateTime(
      reference.year,
      reference.month,
      reference.day,
      startMinutes ~/ 60,
      startMinutes % 60,
    );

    if (endMinutes == null) {
      return DateFormat('h:mm a').format(start);
    }

    final end = DateTime(
      reference.year,
      reference.month,
      reference.day,
      endMinutes ~/ 60,
      endMinutes % 60,
    );

    return '${DateFormat('h:mm a').format(start)}–'
        '${DateFormat('h:mm a').format(end)}';
  }

  String _recurringDayLabel(FamilyMoment moment) {
    if (moment.isDayFlexible) {
      return 'Flexible — exact date chosen later';
    }

    return switch (moment.expectedIntervalDays) {
      1 => 'Every day',
      7 || 14 => _weekdayLabel(
        moment.preferredWeekday ?? moment.startAt.toLocal().weekday,
      ),
      30 ||
      90 => 'Day ${moment.preferredDayOfMonth ?? moment.startAt.toLocal().day}',
      365 => _yearlyDayLabel(moment),
      _ => 'Uses its configured interval',
    };
  }

  String _yearlyDayLabel(FamilyMoment moment) {
    final month = moment.preferredMonth ?? moment.startAt.toLocal().month;
    final requestedDay =
        moment.preferredDayOfMonth ?? moment.startAt.toLocal().day;
    final day = requestedDay
        .clamp(1, MomentScheduleResolver.daysInMonth(2026, month))
        .toInt();

    return DateFormat('d MMMM').format(DateTime(2026, month, day));
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

  String _weekdayLabel(int weekday) {
    final monday = DateTime(2026, 1, 5);
    return DateFormat.EEEE().format(monday.add(Duration(days: weekday - 1)));
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
