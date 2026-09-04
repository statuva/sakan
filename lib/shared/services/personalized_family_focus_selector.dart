import '../models/family_insight_report.dart';
import '../models/family_moment.dart';
import '../models/member.dart';
import '../models/model_enums.dart';
import 'member_recommendation_policy.dart';

/// Final deterministic gate before a Home insight is shown to one member.
abstract final class PersonalizedFamilyFocusSelector {
  static FamilyInsightItem? select(FamilyInsightReport report) {
    final candidates = selectAll(report);
    return candidates.isEmpty ? null : candidates.first;
  }

  static List<FamilyInsightItem> selectAll(FamilyInsightReport report) {
    final member = report.snapshot.currentMember;
    if (member == null || !member.isActive) {
      return const <FamilyInsightItem>[];
    }

    final candidates = <FamilyInsightItem>[
      if (report.primaryInsight != null) report.primaryInsight!,
      ...report.secondaryInsights,
    ];

    final allowed = <FamilyInsightItem>[];
    for (final insight in candidates) {
      final moment = insight.relatedMomentId == null
          ? null
          : report.snapshot.momentById(insight.relatedMomentId!);

      if (!_isAllowed(member: member, moment: moment, insight: insight)) {
        continue;
      }

      if (moment == null) {
        allowed.add(insight);
      } else {
        allowed.add(
          _personalize(member: member, moment: moment, insight: insight),
        );
      }
    }

    return List<FamilyInsightItem>.unmodifiable(allowed);
  }

  static bool _isAllowed({
    required Member member,
    required FamilyMoment? moment,
    required FamilyInsightItem insight,
  }) {
    if (member.role == FamilyRole.child &&
        insight.relatedMomentId != null &&
        moment == null) {
      return false;
    }

    if (moment != null &&
        !MemberRecommendationPolicy.canSeeMoment(
          member: member,
          moment: moment,
        )) {
      return false;
    }

    if (member.role == FamilyRole.child &&
        (insight.actionType == FamilyInsightActionType.reviewToday ||
            insight.actionType == FamilyInsightActionType.scheduleMoment ||
            insight.actionType == FamilyInsightActionType.manageMoments ||
            insight.actionType == FamilyInsightActionType.startMomentNow)) {
      return false;
    }

    if (insight.actionType == FamilyInsightActionType.addReminder) {
      if (moment == null ||
          !MemberRecommendationPolicy.canReceivePreparationAction(
            member: member,
            moment: moment,
          )) {
        return false;
      }
    }

    if (moment != null &&
        insight.actionType == FamilyInsightActionType.startMomentNow &&
        !MemberRecommendationPolicy.canStartSharedSession(
          member: member,
          moment: moment,
        )) {
      return false;
    }

    return true;
  }

  static FamilyInsightItem _personalize({
    required Member member,
    required FamilyMoment moment,
    required FamilyInsightItem insight,
  }) {
    var headline = insight.headline;
    var summary = insight.summary;
    var actionType = insight.actionType;
    var actions = List<String>.from(insight.suggestedActions);

    if (moment.isSubject(member.id)) {
      // Keep the family fact visible, but strip self-preparation behavior.
      if (headline.startsWith('${member.displayName}\'s ')) {
        headline = 'Your ${headline.substring(member.displayName.length + 3)}';
      }
      if (actionType == FamilyInsightActionType.addReminder) {
        actionType = FamilyInsightActionType.none;
        actions = const <String>[];
      }
      summary =
          '${insight.summary} This Moment is about you, so Sakan will not assign you preparation for yourself.';
    }

    final reason = MemberRecommendationPolicy.whyThisIsForMember(
      member: member,
      moment: moment,
    );

    return FamilyInsightItem(
      id: insight.id,
      kind: insight.kind,
      actionType: actionType,
      priority: insight.priority,
      headline: headline,
      summary: summary,
      reasons: <String>[reason, ...insight.reasons],
      suggestedActions: actions,
      confidence: insight.confidence,
      relatedMomentId: insight.relatedMomentId,
      relatedInstanceId: insight.relatedInstanceId,
      relatedReminderId: insight.relatedReminderId,
      recommendedActionAt: insight.recommendedActionAt,
      recommendedActionUsesAvailability:
          insight.recommendedActionUsesAvailability,
    );
  }
}
