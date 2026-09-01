import '../models/care_action.dart';
import '../models/family_insight_report.dart';
import '../models/model_enums.dart';
import '../models/moment_instance.dart';

class MomentActionDecision {
  const MomentActionDecision({
    required this.actionType,
    this.recommendedActionAt,
    this.relatedReminderId,
  });

  final FamilyInsightActionType actionType;
  final DateTime? recommendedActionAt;
  final String? relatedReminderId;
}

abstract final class MomentActionEvaluator {
  static const Duration defaultSessionWindow = Duration(minutes: 90);
  static const Duration reviewBacklog = Duration(days: 7);

  static MomentActionDecision evaluate({
    required MomentInstance instance,
    required DateTime now,
    required MomentInstance? activeInstance,
    required bool canStartSharedMoment,
    required bool canReviewSharedMoment,
    required bool canCreatePersonalReminder,
    CareAction? existingReminder,
  }) {
    final localNow = now.toLocal();

    if (activeInstance != null) {
      if (activeInstance.id == instance.id) {
        return MomentActionDecision(
          actionType: FamilyInsightActionType.joinActiveMoment,
          recommendedActionAt:
              activeInstance.actualStartAt ?? activeInstance.scheduledStartAt,
        );
      }

      return const MomentActionDecision(
        actionType: FamilyInsightActionType.none,
      );
    }

    if (instance.status == MomentInstanceStatus.active) {
      return MomentActionDecision(
        actionType: FamilyInsightActionType.joinActiveMoment,
        recommendedActionAt:
            instance.actualStartAt ?? instance.scheduledStartAt,
      );
    }

    if (instance.isFinished || !_isPlanned(instance)) {
      return const MomentActionDecision(
        actionType: FamilyInsightActionType.none,
      );
    }

    final start = instance.scheduledStartAt.toLocal();
    final end =
        (instance.scheduledEndAt ??
                instance.scheduledStartAt.add(defaultSessionWindow))
            .toLocal();

    if (!localNow.isBefore(start) && !localNow.isAfter(end)) {
      if (canStartSharedMoment && _isSharedSessionCategory(instance)) {
        return MomentActionDecision(
          actionType: FamilyInsightActionType.startMomentNow,
          recommendedActionAt: localNow,
        );
      }

      return const MomentActionDecision(
        actionType: FamilyInsightActionType.none,
      );
    }

    if (localNow.isAfter(end)) {
      final age = localNow.difference(end);

      if (canReviewSharedMoment && age <= reviewBacklog) {
        return MomentActionDecision(
          actionType: FamilyInsightActionType.reviewToday,
          recommendedActionAt: localNow,
        );
      }

      return const MomentActionDecision(
        actionType: FamilyInsightActionType.none,
      );
    }

    if (_isSameLocalDay(localNow, start) && canCreatePersonalReminder) {
      if (existingReminder != null) {
        return MomentActionDecision(
          actionType: FamilyInsightActionType.openReminders,
          recommendedActionAt: existingReminder.dueAt,
          relatedReminderId: existingReminder.id,
        );
      }

      var reminderAt = start.subtract(const Duration(minutes: 30));
      final minimum = localNow.add(const Duration(minutes: 1));

      if (reminderAt.isBefore(minimum)) {
        reminderAt = minimum;
      }

      if (reminderAt.isAfter(start)) {
        reminderAt = start;
      }

      return MomentActionDecision(
        actionType: FamilyInsightActionType.addReminder,
        recommendedActionAt: reminderAt,
      );
    }

    return const MomentActionDecision(actionType: FamilyInsightActionType.none);
  }

  static bool canStartNow({
    required MomentInstance instance,
    required DateTime now,
    required MomentInstance? activeInstance,
    required bool canStartSharedMoment,
  }) {
    return evaluate(
          instance: instance,
          now: now,
          activeInstance: activeInstance,
          canStartSharedMoment: canStartSharedMoment,
          canReviewSharedMoment: false,
          canCreatePersonalReminder: false,
        ).actionType ==
        FamilyInsightActionType.startMomentNow;
  }

  static bool _isPlanned(MomentInstance instance) {
    return instance.status == MomentInstanceStatus.proposed ||
        instance.status == MomentInstanceStatus.scheduled ||
        instance.status == MomentInstanceStatus.inviting;
  }

  static bool _isSharedSessionCategory(MomentInstance instance) {
    return instance.expectedParticipantIds.length >= 2 &&
        (instance.categorySnapshot == MomentCategory.tradition ||
            instance.categorySnapshot == MomentCategory.familyTime);
  }

  static bool _isSameLocalDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
