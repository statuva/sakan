import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_moment.dart';
import '../../../../shared/models/model_enums.dart';
import '../../../../shared/models/rhythm_record.dart';
import 'calendar_moment_style.dart';
import 'calendar_palette.dart';

class CalendarAgendaView extends StatelessWidget {
  const CalendarAgendaView({
    required this.moments,
    required this.rhythmsByMomentId,
    required this.currentUserId,
    required this.onMomentTap,
    super.key,
  });

  final List<FamilyMoment> moments;
  final Map<String, RhythmRecord> rhythmsByMomentId;
  final String currentUserId;
  final ValueChanged<FamilyMoment> onMomentTap;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final upcoming =
        moments.where((moment) {
            final date = DateUtils.dateOnly(moment.startAt.toLocal());
            return !date.isBefore(today) &&
                moment.status != MomentStatus.cancelled;
          }).toList()
          ..sort((first, second) => first.startAt.compareTo(second.startAt));

    if (upcoming.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: CalendarPalette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CalendarPalette.border),
        ),
        child: Text(
          'No upcoming family moments match the selected labels.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Upcoming',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: CalendarPalette.ink),
        ),
        const SizedBox(height: AppSpacing.md),
        ...upcoming.map((moment) {
          final style = calendarMomentStyle(
            moment,
            currentUserId: currentUserId,
          );
          final status = calendarStatusStyle(
            moment: moment,
            rhythm: rhythmsByMomentId[moment.id],
          );
          final localStart = moment.startAt.toLocal();

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onMomentTap(moment),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: CalendarPalette.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: CalendarPalette.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: style.softColor,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(style.icon, color: style.color, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            moment.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: CalendarPalette.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_relativeDate(localStart)} · ${DateFormat('h:mm a').format(localStart)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: CalendarPalette.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status.softColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status.label,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: status.color,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: CalendarPalette.inkSoft,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _relativeDate(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final target = DateUtils.dateOnly(date);
    final days = target.difference(today).inDays;

    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days > 1 && days <= 14) return 'In $days days';
    return DateFormat('d MMM').format(date);
  }
}
