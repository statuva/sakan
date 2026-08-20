import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_memory.dart';
import '../calendar_types.dart';
import 'calendar_palette.dart';

class CalendarSupportCards extends StatelessWidget {
  const CalendarSupportCards({
    required this.availability,
    required this.memory,
    required this.onAvailabilityTap,
    required this.onMemoryTap,
    super.key,
  });

  final CalendarAvailabilityWindow? availability;
  final FamilyMemory? memory;
  final VoidCallback? onAvailabilityTap;
  final VoidCallback? onMemoryTap;

  @override
  Widget build(BuildContext context) {
    if (availability == null && memory == null) {
      return const SizedBox.shrink();
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (availability != null)
            Expanded(
              child: _SupportCard(
                icon: Icons.schedule_outlined,
                iconColor: CalendarPalette.mine,
                iconBackground: CalendarPalette.mineSoft,
                eyebrow: 'Best Availability',
                title: DateFormat('EEEE').format(availability!.date),
                subtitle:
                    '${_formatMinutes(context, availability!.startMinutes)}–${_formatMinutes(context, availability!.endMinutes)}\n${availability!.availableMemberCount} of ${availability!.totalMemberCount} members available',
                onTap: onAvailabilityTap,
              ),
            ),
          if (availability != null && memory != null)
            const SizedBox(width: AppSpacing.sm),
          if (memory != null)
            Expanded(
              child: _SupportCard(
                icon: Icons.photo_library_outlined,
                iconColor: CalendarPalette.milestone,
                iconBackground: CalendarPalette.milestoneSoft,
                eyebrow: 'Memory',
                title: memory!.title,
                subtitle:
                    '${DateFormat('d MMM y').format(memory!.occurredAt.toLocal())}\nTap to view photos and reflection',
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
    this.imageUrl,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? imageUrl;

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
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 68,
                  width: double.infinity,
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _IconBox(
                      icon: icon,
                      color: iconColor,
                      background: iconBackground,
                    ),
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
              eyebrow.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: CalendarPalette.inkSoft,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CalendarPalette.inkSoft,
                height: 1.35,
              ),
            ),
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
