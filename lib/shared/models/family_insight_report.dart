import 'family_insight_snapshot.dart';
import 'model_enums.dart';

/// What Sakan noticed.
enum FamilyInsightKind {
  activeMoment,
  reviewNeeded,
  overdueReminder,
  upcomingMilestone,
  carePreparation,
  sharedMomentOpportunity,
  driftingRhythm,
  upcomingMoment,
}

/// The exact product action that should follow the insight.
enum FamilyInsightActionType {
  joinActiveMoment,
  reviewToday,
  openReminders,
  addReminder,
  startMomentNow,
  scheduleMoment,
  openSimulation,
  manageMoments,
  none,
}

enum FamilyOverallState {
  stillLearning,
  stable,
  drifting,
  recovering,
  strengthening,
}

class FamilyInsightItem {
  FamilyInsightItem({
    required this.id,
    required this.kind,
    required this.actionType,
    required this.priority,
    required this.headline,
    required this.summary,
    required List<String> reasons,
    required List<String> suggestedActions,
    required this.confidence,
    this.relatedMomentId,
    this.relatedInstanceId,
    this.relatedReminderId,
    this.recommendedActionAt,
    this.recommendedActionUsesAvailability = false,
    this.recommendsSimulation = false,
  }) : reasons = List<String>.unmodifiable(reasons),
       suggestedActions = List<String>.unmodifiable(suggestedActions);

  final String id;
  final FamilyInsightKind kind;
  final FamilyInsightActionType actionType;

  /// Lower values are more urgent.
  final int priority;

  final String headline;
  final String summary;
  final List<String> reasons;
  final List<String> suggestedActions;
  final ConfidenceLevel confidence;

  final String? relatedMomentId;
  final String? relatedInstanceId;
  final String? relatedReminderId;

  final DateTime? recommendedActionAt;
  final bool recommendedActionUsesAvailability;

  /// Whether Calendar should expose a secondary route to What-if simulation.
  ///
  /// For a drifting rhythm, [actionType] is normally [openSimulation] and this
  /// remains true so the recommendation plan can explain why.
  final bool recommendsSimulation;

  /// Compatibility getter for older Calendar code.
  DateTime? get recommendedReminderAt => recommendedActionAt;

  /// Compatibility getter for older Calendar code.
  bool get recommendedReminderUsesAvailability {
    return recommendedActionUsesAvailability;
  }

  String? get primaryActionLabel {
    return switch (actionType) {
      FamilyInsightActionType.joinActiveMoment => 'Join Moment',
      FamilyInsightActionType.reviewToday => 'Review Outcome',
      FamilyInsightActionType.openReminders => 'Open This Task',
      FamilyInsightActionType.addReminder => 'Remind Me',
      FamilyInsightActionType.startMomentNow => 'Start Moment',
      FamilyInsightActionType.scheduleMoment => 'Choose a Time',
      FamilyInsightActionType.openSimulation => 'Try Simulation',
      FamilyInsightActionType.manageMoments => 'Open Moments',
      FamilyInsightActionType.none => null,
    };
  }
}

class FamilyAvailabilityWindow {
  const FamilyAvailabilityWindow({
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.availableMemberCount,
    required this.totalMemberCount,
    required this.membersWithScheduleDataCount,
  });

  final DateTime date;
  final int startMinutes;
  final int endMinutes;

  final int availableMemberCount;
  final int totalMemberCount;
  final int membersWithScheduleDataCount;

  DateTime get startAt {
    return DateTime(
      date.year,
      date.month,
      date.day,
      startMinutes ~/ 60,
      startMinutes % 60,
    );
  }

  DateTime get endAt {
    return DateTime(
      date.year,
      date.month,
      date.day,
      endMinutes ~/ 60,
      endMinutes % 60,
    );
  }

  bool get everyoneAvailable {
    return totalMemberCount > 0 && availableMemberCount == totalMemberCount;
  }

  bool get hasFullScheduleCoverage {
    return totalMemberCount > 0 &&
        membersWithScheduleDataCount == totalMemberCount;
  }
}

class FamilyInsightMetrics {
  const FamilyInsightMetrics({
    required this.activeMemberCount,
    required this.activeInstanceCount,
    required this.upcomingInstanceCount,
    required this.completedInstanceCount,
    required this.missedInstanceCount,
    required this.reviewNeededCount,
    required this.driftingRhythmCount,
    required this.pendingReminderCount,
    required this.completedReminderCount,
    required this.overdueReminderCount,
    required this.memoryCount,
  });

  final int activeMemberCount;
  final int activeInstanceCount;
  final int upcomingInstanceCount;
  final int completedInstanceCount;
  final int missedInstanceCount;
  final int reviewNeededCount;
  final int driftingRhythmCount;
  final int pendingReminderCount;
  final int completedReminderCount;
  final int overdueReminderCount;
  final int memoryCount;
}

class FamilyInsightReport {
  FamilyInsightReport({
    required this.snapshot,
    required this.overallState,
    required this.overallConfidence,
    required this.primaryInsight,
    required List<FamilyInsightItem> secondaryInsights,
    required this.bestSharedWindow,
  }) : secondaryInsights = List<FamilyInsightItem>.unmodifiable(
         secondaryInsights,
       );

  final FamilyInsightSnapshot snapshot;

  /// A status of the recorded rhythm model, not a diagnosis of
  /// family happiness or emotional well-being.
  final FamilyOverallState overallState;
  final ConfidenceLevel overallConfidence;

  final FamilyInsightItem? primaryInsight;
  final List<FamilyInsightItem> secondaryInsights;
  final FamilyAvailabilityWindow? bestSharedWindow;

  FamilyInsightMetrics get metrics {
    return FamilyInsightMetrics(
      activeMemberCount: snapshot.activeMembers.length,
      activeInstanceCount: snapshot.activeInstance == null ? 0 : 1,
      upcomingInstanceCount: snapshot.upcomingInstances.length,
      completedInstanceCount: snapshot.completedInstances.length,
      missedInstanceCount: snapshot.missedInstances.length,
      reviewNeededCount: snapshot.reviewableInstances.length,
      driftingRhythmCount: snapshot.driftingRhythms.length,
      pendingReminderCount: snapshot.pendingCurrentUserReminders.length,
      completedReminderCount: snapshot.completedCurrentUserReminders.length,
      overdueReminderCount: snapshot.overdueCurrentUserReminders.length,
      memoryCount: snapshot.memories.length,
    );
  }

  /// Privacy-minimized payload for the later remote AI layer.
  /// Titles remain excluded unless explicitly requested.
  Map<String, dynamic> toAiPayload({bool includeTitles = false}) {
    final insight = primaryInsight;
    final relatedMoment = insight?.relatedMomentId == null
        ? null
        : snapshot.momentById(insight!.relatedMomentId!);
    final relatedInstance = insight?.relatedInstanceId == null
        ? null
        : snapshot.instanceById(insight!.relatedInstanceId!);
    final relatedRhythm = relatedMoment == null
        ? null
        : snapshot.rhythmForMoment(relatedMoment.id);

    return <String, dynamic>{
      'generatedAt': snapshot.generatedAt.toIso8601String(),
      'overallState': overallState.name,
      'overallConfidence': overallConfidence.name,
      'metrics': <String, dynamic>{
        'activeMembers': metrics.activeMemberCount,
        'activeInstances': metrics.activeInstanceCount,
        'upcomingInstances': metrics.upcomingInstanceCount,
        'completedInstances': metrics.completedInstanceCount,
        'missedInstances': metrics.missedInstanceCount,
        'reviewNeeded': metrics.reviewNeededCount,
        'driftingRhythms': metrics.driftingRhythmCount,
        'pendingReminders': metrics.pendingReminderCount,
        'overdueReminders': metrics.overdueReminderCount,
        'memories': metrics.memoryCount,
      },
      'primaryInsight': insight == null
          ? null
          : <String, dynamic>{
              'kind': insight.kind.name,
              'actionType': insight.actionType.name,
              'headline': includeTitles ? insight.headline : null,
              'summary': insight.summary,
              'reasons': insight.reasons,
              'suggestedActions': insight.suggestedActions,
              'confidence': insight.confidence.name,
              'recommendedActionAt': insight.recommendedActionAt
                  ?.toIso8601String(),
              'recommendedActionUsesAvailability':
                  insight.recommendedActionUsesAvailability,
              'recommendsSimulation': insight.recommendsSimulation,
            },
      'relatedMoment': relatedMoment == null
          ? null
          : <String, dynamic>{
              'title': includeTitles ? relatedMoment.title : null,
              'type': relatedMoment.type.name,
              'category': relatedMoment.category.name,
              'importance': relatedMoment.importanceLevel,
              'expectedParticipantCount':
                  relatedMoment.expectedParticipantIds.length,
              'expectedIntervalDays': relatedMoment.expectedIntervalDays,
              'rhythmStatus': relatedRhythm?.status.name,
              'rhythmConfidence': relatedRhythm?.confidence.name,
            },
      'relatedInstance': relatedInstance == null
          ? null
          : <String, dynamic>{
              'status': relatedInstance.status.name,
              'source': relatedInstance.source.name,
              'scheduledStartAt': relatedInstance.scheduledStartAt
                  .toIso8601String(),
              'actualStartAt': relatedInstance.actualStartAt?.toIso8601String(),
              'actualDurationMinutes': relatedInstance.actualDurationMinutes,
              'expectedParticipantCount':
                  relatedInstance.expectedParticipantIds.length,
              'recordedParticipantCount':
                  relatedInstance.allRecordedParticipantIds.length,
              'confirmationLevel': relatedInstance.confirmationLevel.name,
            },
      'bestSharedWindow': bestSharedWindow == null
          ? null
          : <String, dynamic>{
              'startAt': bestSharedWindow!.startAt.toIso8601String(),
              'endAt': bestSharedWindow!.endAt.toIso8601String(),
              'availableMemberCount': bestSharedWindow!.availableMemberCount,
              'totalMemberCount': bestSharedWindow!.totalMemberCount,
              'membersWithScheduleDataCount':
                  bestSharedWindow!.membersWithScheduleDataCount,
            },
    };
  }
}
