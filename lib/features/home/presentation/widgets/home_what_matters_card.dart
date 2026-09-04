import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_insight_report.dart';
import '../../../../shared/models/moment_instance.dart';
import '../../../../shared/ai/ai_models.dart';

class HomeWhatMattersCard extends StatelessWidget {
  const HomeWhatMattersCard({
    required this.insight,
    required this.aiNarrative,
    required this.nextInstance,
    required this.isPerformingAction,
    required this.onAction,
    required this.onOpenCalendar,
    super.key,
  });

  final FamilyInsightItem? insight;
  final Future<SakanAiResult>? aiNarrative;
  final MomentInstance? nextInstance;
  final bool isPerformingAction;
  final VoidCallback? onAction;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final item = insight;
    final visual = _visualFor(item?.kind);

    final headline = item?.headline ?? 'Your family is caught up';
    final summary = item?.summary ?? _calmSummary(nextInstance);
    final actionLabel = item == null
        ? nextInstance == null
              ? null
              : 'Open Calendar'
        : item.primaryActionLabel ??
              (item.actionType == FamilyInsightActionType.none
                  ? 'Open Calendar'
                  : null);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.largeCard),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(visual.icon, color: visual.foreground, size: 21),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'WHAT MATTERS NOW',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: visual.foreground,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.55,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FutureBuilder<SakanAiResult>(
            future: aiNarrative,
            builder: (context, snapshot) {
              return Text(
                snapshot.data?.title ?? headline,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w400,
                  height: 1.15,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          FutureBuilder<SakanAiResult>(
            future: aiNarrative,
            builder: (context, snapshot) {
              return Text(
                snapshot.data?.text ?? summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              );
            },
          ),
          if (item != null)
            FutureBuilder<SakanAiResult>(
              future: aiNarrative,
              builder: (context, snapshot) {
                final reasons = snapshot.data?.reasons.isNotEmpty == true
                    ? snapshot.data!.reasons
                    : item.reasons;
                if (reasons.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.linen.withAlpha(150),
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 17,
                          color: visual.foreground,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            reasons.first,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isPerformingAction
                    ? null
                    : item == null
                    ? onOpenCalendar
                    : onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: visual.foreground,
                ),
                child: isPerformingAction
                    ? const SizedBox.square(
                        dimension: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _calmSummary(MomentInstance? next) {
    if (next == null) {
      return 'Nothing shared needs immediate attention right now.';
    }

    final localStart = next.scheduledStartAt.toLocal();
    return '${next.titleSnapshot} is next on '
        '${DateFormat('EEEE, d MMM').format(localStart)} at '
        '${DateFormat('h:mm a').format(localStart)}.';
  }

  _InsightVisual _visualFor(FamilyInsightKind? kind) {
    return switch (kind) {
      FamilyInsightKind.activeMoment => const _InsightVisual(
        icon: Icons.groups_rounded,
        foreground: AppColors.strengthening,
        background: Color(0xFFE1F2EE),
      ),
      FamilyInsightKind.reviewNeeded => const _InsightVisual(
        icon: Icons.fact_check_outlined,
        foreground: AppColors.secondary,
        background: Color(0xFFF5E7E1),
      ),
      FamilyInsightKind.upcomingMilestone => const _InsightVisual(
        icon: Icons.star_border_rounded,
        foreground: AppColors.accent,
        background: Color(0xFFF6EDD9),
      ),
      FamilyInsightKind.carePreparation => const _InsightVisual(
        icon: Icons.favorite_border_rounded,
        foreground: AppColors.secondary,
        background: Color(0xFFF5E7E1),
      ),
      FamilyInsightKind.sharedMomentOpportunity => const _InsightVisual(
        icon: Icons.play_circle_outline_rounded,
        foreground: AppColors.primary,
        background: Color(0xFFE5EBDD),
      ),
      FamilyInsightKind.driftingRhythm => const _InsightVisual(
        icon: Icons.repeat_rounded,
        foreground: AppColors.drifting,
        background: Color(0xFFFFEBD8),
      ),
      FamilyInsightKind.upcomingMoment => const _InsightVisual(
        icon: Icons.calendar_today_outlined,
        foreground: AppColors.primary,
        background: Color(0xFFE5EBDD),
      ),
      FamilyInsightKind.overdueReminder => const _InsightVisual(
        icon: Icons.notification_important_outlined,
        foreground: AppColors.error,
        background: Color(0xFFF8E3DF),
      ),
      null => const _InsightVisual(
        icon: Icons.check_circle_outline_rounded,
        foreground: AppColors.primary,
        background: Color(0xFFE5EBDD),
      ),
    };
  }
}

class _InsightVisual {
  const _InsightVisual({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
}
