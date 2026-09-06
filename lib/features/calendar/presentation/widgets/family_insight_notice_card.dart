import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_insight_report.dart';
import '../../../../shared/models/model_enums.dart';
import '../../../../shared/ai/ai_models.dart';
import 'calendar_palette.dart';

class FamilyInsightNoticeCard extends StatelessWidget {
  const FamilyInsightNoticeCard({
    required this.insight,
    required this.aiNarrative,
    required this.onOpen,
    super.key,
  });

  final FamilyInsightItem insight;
  final Future<SakanAiResult>? aiNarrative;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(context);

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
                  color: accent.withAlpha(24),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_kindIcon(), size: 20, color: accent),
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
          FutureBuilder<SakanAiResult>(
            future: aiNarrative,
            builder: (context, snapshot) {
              return Text(
                snapshot.data?.title ?? insight.headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: CalendarPalette.ink,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          FutureBuilder<SakanAiResult>(
            future: aiNarrative,
            builder: (context, snapshot) {
              return Text(
                snapshot.data?.text ?? insight.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CalendarPalette.inkSoft,
                  height: 1.45,
                ),
              );
            },
          ),
          FutureBuilder<SakanAiResult>(
            future: aiNarrative,
            builder: (context, snapshot) {
              final reasons = snapshot.data?.reasons.isNotEmpty == true
                  ? snapshot.data!.reasons
                  : insight.reasons;
              if (reasons.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: reasons
                      .take(1)
                      .map((reason) => _FactChip(label: reason, color: accent))
                      .toList(growable: false),
                ),
              );
            },
          ),
          if (insight.primaryActionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'NEXT ACTION · ${insight.primaryActionLabel}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.25,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onOpen,
              child: const Text('View Recommendation'),
            ),
          ),
        ],
      ),
    );
  }

  String _kindLabel() {
    return switch (insight.kind) {
      FamilyInsightKind.activeMoment => 'Live Family Moment',
      FamilyInsightKind.reviewNeeded => 'Today Review Needed',
      FamilyInsightKind.overdueReminder => 'Overdue Reminder',
      FamilyInsightKind.upcomingMilestone => 'Upcoming Milestone',
      FamilyInsightKind.carePreparation => 'Care Preparation',
      FamilyInsightKind.sharedMomentOpportunity => 'Shared Moment Opportunity',
      FamilyInsightKind.driftingRhythm => 'Drifting Rhythm',
      FamilyInsightKind.upcomingMoment => 'Upcoming Moment',
    };
  }

  IconData _kindIcon() {
    return switch (insight.kind) {
      FamilyInsightKind.activeMoment => Icons.play_circle_outline_rounded,
      FamilyInsightKind.reviewNeeded => Icons.fact_check_outlined,
      FamilyInsightKind.overdueReminder => Icons.warning_amber_rounded,
      FamilyInsightKind.upcomingMilestone => Icons.star_border_rounded,
      FamilyInsightKind.carePreparation => Icons.favorite_border_rounded,
      FamilyInsightKind.sharedMomentOpportunity => Icons.groups_2_outlined,
      FamilyInsightKind.driftingRhythm => Icons.trending_down_rounded,
      FamilyInsightKind.upcomingMoment => Icons.event_outlined,
    };
  }

  Color _accentColor(BuildContext context) {
    return switch (insight.kind) {
      FamilyInsightKind.activeMoment => CalendarPalette.strengthening,
      FamilyInsightKind.reviewNeeded => CalendarPalette.drifting,
      FamilyInsightKind.overdueReminder => Theme.of(context).colorScheme.error,
      FamilyInsightKind.upcomingMilestone => CalendarPalette.milestone,
      FamilyInsightKind.carePreparation => CalendarPalette.care,
      FamilyInsightKind.sharedMomentOpportunity => CalendarPalette.forest,
      FamilyInsightKind.driftingRhythm => CalendarPalette.drifting,
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
