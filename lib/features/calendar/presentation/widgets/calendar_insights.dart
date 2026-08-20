import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sakan/shared/models/availability_block.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';

import 'calendar_visuals.dart';

class CalendarInsightsSection extends StatelessWidget {
  const CalendarInsightsSection({
    required this.moments,
    required this.availabilityBlocks,
    required this.onPrimaryAction,
    super.key,
  });

  final List<FamilyMoment> moments;
  final List<AvailabilityBlock> availabilityBlocks;
  final ValueChanged<FamilyMoment> onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final upcoming =
        moments
            .where(
              (moment) =>
                  !moment.startAt.toLocal().isBefore(DateTime.now()) &&
                  moment.status != MomentStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

    final primary = _primaryMoment(upcoming);
    final care = upcoming.cast<FamilyMoment?>().firstWhere(
      (moment) =>
          moment != null &&
          (moment.category == MomentCategory.care ||
              moment.category == MomentCategory.milestone),
      orElse: () => null,
    );
    final memory = moments.cast<FamilyMoment?>().firstWhere(
      (moment) =>
          moment != null &&
          (moment.status == MomentStatus.completed ||
              moment.category == MomentCategory.memory),
      orElse: () => null,
    );
    final availability = _bestAvailability();

    if (primary == null &&
        care == null &&
        memory == null &&
        availabilityBlocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          'WHAT SAKAN NOTICES',
          style: TextStyle(
            color: CalendarPalette.inkSoft,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        if (primary != null)
          _RecommendationCard(
            moment: primary,
            availability: availability,
            onPressed: () => onPrimaryAction(primary),
          ),
        if (primary != null) const SizedBox(height: 13),
        SizedBox(
          height: 152,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              _MiniInsightCard(
                icon: Icons.schedule_outlined,
                iconColor: CalendarPalette.personalText,
                iconBackground: CalendarPalette.personalSoft,
                eyebrow: 'Best Availability',
                title: availability.title,
                subtitle: availability.subtitle,
              ),
              if (care != null) ...<Widget>[
                const SizedBox(width: 10),
                _MiniInsightCard(
                  icon: Icons.favorite_border_rounded,
                  iconColor: CalendarPalette.careText,
                  iconBackground: CalendarPalette.careSoft,
                  eyebrow: 'Care Preparation',
                  title: care.title,
                  subtitle: _careSubtitle(care),
                ),
              ],
              if (memory != null) ...<Widget>[
                const SizedBox(width: 10),
                _MiniInsightCard(
                  icon: Icons.photo_camera_outlined,
                  iconColor: CalendarPalette.milestoneText,
                  iconBackground: CalendarPalette.milestoneSoft,
                  eyebrow: 'Memory',
                  title: memory.title,
                  subtitle: DateFormat(
                    'd MMM y',
                  ).format(memory.startAt.toLocal()),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  FamilyMoment? _primaryMoment(List<FamilyMoment> upcoming) {
    if (upcoming.isEmpty) return null;

    final recurring =
        upcoming.where((moment) => moment.type == MomentType.recurring).toList()
          ..sort((a, b) {
            final importance = b.importanceLevel.compareTo(a.importanceLevel);
            if (importance != 0) return importance;
            return a.startAt.compareTo(b.startAt);
          });

    if (recurring.isNotEmpty) return recurring.first;

    upcoming.sort((a, b) {
      final importance = b.importanceLevel.compareTo(a.importanceLevel);
      if (importance != 0) return importance;
      return a.startAt.compareTo(b.startAt);
    });

    return upcoming.first;
  }

  _AvailabilitySuggestion _bestAvailability() {
    const candidates = <_AvailabilitySuggestion>[
      _AvailabilitySuggestion(
        weekday: DateTime.friday,
        startMinutes: 17 * 60,
        endMinutes: 20 * 60,
        title: 'Friday Evening',
      ),
      _AvailabilitySuggestion(
        weekday: DateTime.saturday,
        startMinutes: 17 * 60,
        endMinutes: 20 * 60,
        title: 'Saturday Evening',
      ),
    ];

    var best = candidates.first;
    var bestConflicts = _conflictCount(best);

    for (final candidate in candidates.skip(1)) {
      final conflicts = _conflictCount(candidate);
      if (conflicts < bestConflicts) {
        best = candidate;
        bestConflicts = conflicts;
      }
    }

    if (availabilityBlocks.isEmpty) {
      return best.copyWith(
        subtitle: 'Add recurring schedules for a stronger suggestion',
      );
    }

    return best.copyWith(
      subtitle: bestConflicts == 0
          ? 'No recurring conflicts found · 5–8 PM'
          : '$bestConflicts recurring ${bestConflicts == 1 ? 'conflict' : 'conflicts'} · 5–8 PM',
    );
  }

  int _conflictCount(_AvailabilitySuggestion suggestion) {
    return availabilityBlocks.where((block) {
      if (block.dayOfWeek != suggestion.weekday) return false;
      return suggestion.startMinutes < block.endMinutes &&
          suggestion.endMinutes > block.startMinutes;
    }).length;
  }

  String _careSubtitle(FamilyMoment moment) {
    final days = DateUtils.dateOnly(
      moment.startAt.toLocal(),
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;

    return switch (days) {
      0 => 'Today · preparation may be needed',
      1 => 'Tomorrow · preparation may be needed',
      _ => 'In $days days · preparation may be needed',
    };
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.moment,
    required this.availability,
    required this.onPressed,
  });

  final FamilyMoment moment;
  final _AvailabilitySuggestion availability;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.dateOnly(
      moment.startAt.toLocal(),
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: CalendarPalette.ink.withAlpha(14)),
        boxShadow: CalendarPalette.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: CalendarPalette.forestSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: CalendarPalette.forestDark,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'NEXT BEST FAMILY ACTION',
                  style: TextStyle(
                    color: CalendarPalette.forestDark,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            'Plan ${moment.title} this week',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: CalendarPalette.ink,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            moment.type == MomentType.recurring
                ? 'This is one of your family’s recurring moments, and it already has an upcoming place in the family calendar.'
                : 'This important family moment is coming up and may benefit from early preparation.',
            style: const TextStyle(
              color: CalendarPalette.inkSoft,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _FactChip(
                icon: Icons.schedule_outlined,
                label: switch (days) {
                  0 => 'Happening today',
                  1 => 'Happening tomorrow',
                  _ => 'In $days days',
                },
              ),
              _FactChip(
                icon: Icons.group_outlined,
                label: '${moment.expectedParticipantIds.length} expected',
              ),
              _FactChip(
                icon: Icons.repeat_rounded,
                label: moment.type == MomentType.recurring
                    ? 'Every ${moment.expectedIntervalDays ?? 7} days'
                    : availability.title,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CalendarPalette.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onPressed,
                  child: const Text('Review This Moment'),
                ),
              ),
              const SizedBox(width: 9),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: CalendarPalette.inkSoft,
                  backgroundColor: CalendarPalette.surfaceSoft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {},
                child: const Text('Not now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CalendarPalette.forestSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CalendarPalette.forest.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: CalendarPalette.forestDark),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: CalendarPalette.forestDark,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInsightCard extends StatelessWidget {
  const _MiniInsightCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 158,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CalendarPalette.ink.withAlpha(14)),
        boxShadow: CalendarPalette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 11),
          Text(
            eyebrow.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CalendarPalette.inkSoft,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CalendarPalette.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CalendarPalette.inkSoft,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilitySuggestion {
  const _AvailabilitySuggestion({
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.title,
    this.subtitle = '',
  });

  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final String title;
  final String subtitle;

  _AvailabilitySuggestion copyWith({String? subtitle}) {
    return _AvailabilitySuggestion(
      weekday: weekday,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      title: title,
      subtitle: subtitle ?? this.subtitle,
    );
  }
}
