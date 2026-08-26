import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_memory.dart';
import '../../../../shared/models/family_insight_report.dart';
import 'calendar_palette.dart';

class CalendarSupportCards extends StatelessWidget {
  const CalendarSupportCards({
    required this.availability,
    required this.memory,
    required this.onAvailabilityTap,
    required this.onMemoryTap,
    required this.onAddMemoryTap,
    required this.onAllMemoriesTap,
    super.key,
  });

  final FamilyAvailabilityWindow? availability;

  final FamilyMemory? memory;

  final VoidCallback? onAvailabilityTap;
  final VoidCallback? onMemoryTap;
  final VoidCallback? onAddMemoryTap;

  final VoidCallback onAllMemoriesTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: availability == null
                ? const _SupportCard(
                    icon: Icons.schedule_outlined,
                    iconColor: CalendarPalette.mine,
                    iconBackground: CalendarPalette.mineSoft,
                    eyebrow: 'Best Availability',
                    title: 'No shared window yet',
                    subtitle:
                        'Add personal schedules '
                        'to calculate a shared '
                        'family window.',
                    onTap: null,
                  )
                : _SupportCard(
                    icon: Icons.schedule_outlined,
                    iconColor: CalendarPalette.mine,
                    iconBackground: CalendarPalette.mineSoft,
                    eyebrow: 'Best Availability',
                    title: DateFormat('EEEE').format(availability!.date),
                    subtitle:
                        '${_formatMinutes(context, availability!.startMinutes)}'
                        '–'
                        '${_formatMinutes(context, availability!.endMinutes)}\n'
                        '${availability!.availableMemberCount} of '
                        '${availability!.totalMemberCount} members available',
                    actionLabel: 'View Week',
                    onTap: onAvailabilityTap,
                  ),
          ),

          const SizedBox(width: AppSpacing.sm),

          Expanded(
            child: memory == null
                ? _SupportCard(
                    icon: Icons.bookmark_add_outlined,
                    iconColor: CalendarPalette.milestone,
                    iconBackground: CalendarPalette.milestoneSoft,
                    eyebrow: 'Memory',
                    topActionLabel: 'All Memories',
                    onTopActionTap: onAllMemoriesTap,
                    title: 'No memories yet',
                    subtitle:
                        'Preserve a note from a '
                        'completed family Moment.',
                    actionLabel: onAddMemoryTap == null ? null : 'Add Memory',
                    onTap: onAddMemoryTap,
                  )
                : _SupportCard(
                    icon: Icons.auto_stories_outlined,
                    iconColor: CalendarPalette.milestone,
                    iconBackground: CalendarPalette.milestoneSoft,
                    eyebrow: 'Memory',
                    topActionLabel: 'All Memories',
                    onTopActionTap: onAllMemoriesTap,
                    title: memory!.title,
                    subtitle:
                        '${DateFormat('d MMM y').format(memory!.occurredAt.toLocal())}\n'
                        'Family note saved',
                    actionLabel: 'View Memory',
                    onTap: onMemoryTap,
                    imageUrl: memory!.photoUrls.isEmpty
                        ? null
                        : memory!.photoUrls.first,
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatMinutes(BuildContext context, int minutes) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.actionLabel,
    this.imageUrl,
    this.topActionLabel,
    this.onTopActionTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  final String eyebrow;
  final String title;
  final String subtitle;

  final String? actionLabel;
  final String? imageUrl;

  final String? topActionLabel;
  final VoidCallback? onTopActionTap;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: CalendarPalette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CalendarPalette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    eyebrow.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: CalendarPalette.inkSoft,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                if (topActionLabel != null && onTopActionTap != null)
                  TextButton(
                    onPressed: onTopActionTap,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      topActionLabel!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 68,
                  width: double.infinity,
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _IconBox(
                        icon: icon,
                        color: iconColor,
                        background: iconBackground,
                      );
                    },
                  ),
                ),
              )
            else
              _IconBox(
                icon: icon,
                color: iconColor,
                background: iconBackground,
              ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: CalendarPalette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CalendarPalette.inkSoft,
                height: 1.35,
              ),
            ),

            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.sm),

              Text(
                actionLabel!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: CalendarPalette.forestDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 19, color: color),
    );
  }
}
