import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_insight_report.dart';
import '../../../../shared/models/model_enums.dart';
import 'calendar_palette.dart';

class FamilyInsightNoticeCard extends StatelessWidget {
  const FamilyInsightNoticeCard({
    required this.insight,
    required this.onOpen,
    super.key,
  });

  final FamilyInsightItem insight;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(context);
    final softAccent = accent.withAlpha(24);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CalendarPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WHAT SAKAN NOTICES',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: CalendarPalette.inkSoft,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _kindLabel(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _ConfidenceChip(confidence: insight.confidence),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            insight.headline,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: CalendarPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            insight.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CalendarPalette.inkSoft,
              height: 1.45,
            ),
          ),
          if (insight.reasons.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: insight.reasons
                  .take(2)
                  .map((reason) => _FactChip(label: reason, color: accent))
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('View Recommendation'),
            ),
          ),
        ],
      ),
    );
  }

  String _kindLabel() {
    return switch (insight.kind) {
      FamilyInsightKind.overdueReminder => 'Overdue Reminder',
      FamilyInsightKind.upcomingMilestone => 'Upcoming Milestone',
      FamilyInsightKind.carePreparation => 'Care Preparation',
      FamilyInsightKind.driftingRhythm => 'Drifting Rhythm',
      FamilyInsightKind.upcomingMoment => 'Upcoming Moment',
    };
  }

  Color _accentColor(BuildContext context) {
    return switch (insight.kind) {
      FamilyInsightKind.overdueReminder => Theme.of(context).colorScheme.error,
      FamilyInsightKind.upcomingMilestone => CalendarPalette.milestone,
      FamilyInsightKind.carePreparation => CalendarPalette.care,
      FamilyInsightKind.driftingRhythm => CalendarPalette.milestone,
      FamilyInsightKind.upcomingMoment => CalendarPalette.forest,
    };
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.confidence});

  final ConfidenceLevel confidence;

  @override
  Widget build(BuildContext context) {
    final label = switch (confidence) {
      ConfidenceLevel.low => 'Low confidence',
      ConfidenceLevel.medium => 'Medium',
      ConfidenceLevel.high => 'High',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: CalendarPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: CalendarPalette.inkSoft,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
