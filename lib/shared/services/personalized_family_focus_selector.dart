import '../models/availability_block.dart';
import '../models/family_insight_report.dart';
import '../models/family_insight_snapshot.dart';
import '../models/family_moment.dart';
import '../models/member.dart';
import '../models/model_enums.dart';
import '../models/moment_instance.dart';
import 'member_moment_recommendation_builder.dart';
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
          _personalize(
            member: member,
            moment: moment,
            insight: insight,
            snapshot: report.snapshot,
          ),
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

    final isMinor =
        member.ageGroup == AgeGroup.child || member.ageGroup == AgeGroup.teen;

    if (isMinor &&
        (insight.actionType == FamilyInsightActionType.reviewToday ||
            insight.actionType == FamilyInsightActionType.scheduleMoment ||
            insight.actionType == FamilyInsightActionType.openSimulation ||
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
    required FamilyInsightSnapshot snapshot,
  }) {
    var headline = insight.headline;
    var summary = insight.summary;
    var actionType = insight.actionType;
    var actions = List<String>.from(insight.suggestedActions);
    var recommendsSimulation = insight.recommendsSimulation;

    if (moment.isSubject(member.id)) {
      if (headline.startsWith('${member.displayName}\'s ')) {
        headline = 'Your ${headline.substring(member.displayName.length + 3)}';
      }
    }

    String? scheduleNote;
    if (_usesPersonalTaskPlan(insight.kind)) {
      final instance = insight.relatedInstanceId == null
          ? null
          : snapshot.instanceById(insight.relatedInstanceId!);
      final hasScheduleConflict =
          instance != null &&
          _hasRelevantScheduleConflict(
            snapshot: snapshot,
            instance: instance,
            member: member,
          );
      final recommendation = MemberMomentRecommendationBuilder.build(
        member: member,
        moment: moment,
        hasScheduleConflict: hasScheduleConflict,
        hasVerifiedFreeWindow: insight.recommendedActionUsesAvailability,
        isDrifting: insight.kind == FamilyInsightKind.driftingRhythm,
      );

      summary = recommendation.summary;
      actions = recommendation.tasks;
      recommendsSimulation =
          insight.recommendsSimulation || recommendation.recommendsSimulation;
      scheduleNote = recommendation.scheduleNote;

      if (actionType == FamilyInsightActionType.startMomentNow) {
        actions = _startNowFirst(moment.title, actions);
      } else if ((actionType == FamilyInsightActionType.openSimulation ||
              (recommendation.recommendsSimulation &&
                  insight.kind == FamilyInsightKind.driftingRhythm)) &&
          actionType != FamilyInsightActionType.startMomentNow) {
        actionType = FamilyInsightActionType.openSimulation;
        actions = _simulationFirst(
          actions,
          isDrifting: insight.kind == FamilyInsightKind.driftingRhythm,
        );
      }
    }

    final reason = MemberRecommendationPolicy.whyThisIsForMember(
      member: member,
      moment: moment,
    );
    final reasons = <String>[
      reason,
      if (scheduleNote != null) scheduleNote,
      ...insight.reasons,
    ];

    return FamilyInsightItem(
      id: insight.id,
      kind: insight.kind,
      actionType: actionType,
      priority: insight.priority,
      headline: headline,
      summary: summary,
      reasons: _unique(reasons),
      suggestedActions: actions,
      confidence: insight.confidence,
      relatedMomentId: insight.relatedMomentId,
      relatedInstanceId: insight.relatedInstanceId,
      relatedReminderId: insight.relatedReminderId,
      recommendedActionAt: insight.recommendedActionAt,
      recommendedActionUsesAvailability:
          insight.recommendedActionUsesAvailability,
      recommendsSimulation: recommendsSimulation,
    );
  }

  static bool _usesPersonalTaskPlan(FamilyInsightKind kind) {
    return kind == FamilyInsightKind.upcomingMilestone ||
        kind == FamilyInsightKind.carePreparation ||
        kind == FamilyInsightKind.upcomingMoment ||
        kind == FamilyInsightKind.driftingRhythm;
  }

  static bool _hasRelevantScheduleConflict({
    required FamilyInsightSnapshot snapshot,
    required MomentInstance instance,
    required Member member,
  }) {
    final start = instance.scheduledStartAt.toLocal();
    final end =
        (instance.scheduledEndAt ??
                instance.scheduledStartAt.add(const Duration(minutes: 90)))
            .toLocal();
    final date = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    final previousDate = date.subtract(const Duration(days: 1));
    final relevantMemberIds = _isAdultOrAdmin(member)
        ? instance.expectedParticipantIds.toSet()
        : <String>{snapshot.currentUserId};
    if (relevantMemberIds.isEmpty) {
      relevantMemberIds.add(snapshot.currentUserId);
    }

    for (final block in snapshot.availability) {
      if (relevantMemberIds.contains(block.memberId) &&
          !block.isExpiredAt(snapshot.generatedAt) &&
          (_availabilityOverlaps(
                block: block,
                blockDate: date,
                start: start,
                end: end,
              ) ||
              _availabilityOverlaps(
                block: block,
                blockDate: previousDate,
                start: start,
                end: end,
              ) ||
              (!_sameDate(date, endDate) &&
                  _availabilityOverlaps(
                    block: block,
                    blockDate: endDate,
                    start: start,
                    end: end,
                  )))) {
        return true;
      }
    }

    return false;
  }

  static bool _availabilityOverlaps({
    required AvailabilityBlock block,
    required DateTime blockDate,
    required DateTime start,
    required DateTime end,
  }) {
    if (!block.occursOn(blockDate)) return false;

    final blockStart = blockDate.add(Duration(minutes: block.startMinutes));
    var blockEnd = blockDate.add(Duration(minutes: block.endMinutes));
    if (!blockEnd.isAfter(blockStart)) {
      blockEnd = blockEnd.add(const Duration(days: 1));
    }

    return start.isBefore(blockEnd) && end.isAfter(blockStart);
  }

  static List<String> _unique(List<String> values) {
    final seen = <String>{};
    return values
        .where((value) => seen.add(value.trim().toLowerCase()))
        .toList(growable: false);
  }

  static bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static List<String> _simulationFirst(
    List<String> actions, {
    required bool isDrifting,
  }) {
    final simulationTask = isDrifting
        ? 'Try a What-if simulation before choosing the next time.'
        : 'Try a What-if simulation to compare a conflict-free time.';
    return _unique(<String>[simulationTask, ...actions])
        .take(3)
        .toList(growable: false);
  }

  static List<String> _startNowFirst(String title, List<String> actions) {
    return _unique(<String>[
      'Start $title now while its planned time is open.',
      ...actions,
    ]).take(3).toList(growable: false);
  }

  static bool _isAdultOrAdmin(Member member) {
    final hasAdultRole =
        member.role == FamilyRole.admin || member.role == FamilyRole.adult;
    final hasAdultAge =
        member.ageGroup == AgeGroup.adult ||
        member.ageGroup == AgeGroup.senior;
    return hasAdultRole && hasAdultAge;
  }
}
