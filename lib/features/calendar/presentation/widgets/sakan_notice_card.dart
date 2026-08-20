import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../calendar_types.dart';
import 'calendar_palette.dart';

class SakanNoticeCard extends StatelessWidget {
  const SakanNoticeCard({
    required this.recommendation,
    required this.onOpenRecommendation,
    super.key,
  });

  final CalendarRecommendation recommendation;
  final VoidCallback onOpenRecommendation;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  recommendation.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: CalendarPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: recommendation.statusSoftColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  recommendation.statusLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: recommendation.statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            recommendation.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CalendarPalette.inkSoft,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CalendarPalette.surfaceSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 17,
                    color: CalendarPalette.forestDark,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _daysLabel(recommendation.daysLeft),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: CalendarPalette.forestDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onOpenRecommendation,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('AI Recommendation'),
          ),
        ],
      ),
    );
  }

  String _daysLabel(int daysLeft) {
    if (daysLeft < 0) return 'Needs review';
    if (daysLeft == 0) return 'Today';
    if (daysLeft == 1) return '1 day left';
    return '$daysLeft days left';
  }
}
