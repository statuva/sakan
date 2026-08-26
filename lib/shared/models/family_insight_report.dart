import 'family_insight_snapshot.dart';
import 'model_enums.dart';

enum FamilyInsightKind {
  overdueReminder,
  upcomingMilestone,
  carePreparation,
  driftingRhythm,
  upcomingMoment,
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
    required this.priority,
    required this.headline,
    required this.summary,
    required List<String> reasons,
    required List<String> suggestedActions,
    required this.confidence,
    this.relatedMomentId,
    this.relatedReminderId,
    this.recommendedReminderAt,
    this.recommendedReminderUsesAvailability = false,
  }) : reasons = List<String>.unmodifiable(reasons),
       suggestedActions = List<String>.unmodifiable(suggestedActions);

  final String id;
  final FamilyInsightKind kind;

  /// Lower values are more urgent.
  final int priority;

  final String headline;
  final String summary;

  /// Factual statements calculated by Sakan.
  final List<String> reasons;

  /// Deterministic suggestions. External AI may improve
  /// their wording later, but must not replace the facts.
  final List<String> suggestedActions;

  final ConfidenceLevel confidence;

  final String? relatedMomentId;
  final String? relatedReminderId;

  final DateTime? recommendedReminderAt;
  final bool recommendedReminderUsesAvailability;
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

  /// Number of active members who have at least one
  /// recorded schedule block. A low value means Sakan
  /// has incomplete schedule coverage.
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
    required this.upcomingMomentCount,
    required this.completedMomentCount,
    required this.driftingRhythmCount,
    required this.pendingReminderCount,
    required this.completedReminderCount,
    required this.overdueReminderCount,
    required this.memoryCount,
  });

  final int activeMemberCount;
  final int upcomingMomentCount;
  final int completedMomentCount;
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

  /// Describes the current learning/rhythm state of the
  /// model. It is not a diagnosis of family well-being.
  final FamilyOverallState overallState;
  final ConfidenceLevel overallConfidence;

  final FamilyInsightItem? primaryInsight;
  final List<FamilyInsightItem> secondaryInsights;

  final FamilyAvailabilityWindow? bestSharedWindow;

  FamilyInsightMetrics get metrics {
    return FamilyInsightMetrics(
      activeMemberCount: snapshot.activeMembers.length,
      upcomingMomentCount: snapshot.upcomingMoments.length,
      completedMomentCount: snapshot.completedMoments.length,
      driftingRhythmCount: snapshot.driftingRhythms.length,
      pendingReminderCount: snapshot.pendingCurrentUserReminders.length,
      completedReminderCount: snapshot.completedCurrentUserReminders.length,
      overdueReminderCount: snapshot.overdueCurrentUserReminders.length,
      memoryCount: snapshot.memories.length,
    );
  }

  /// Produces a privacy-minimized payload for the future
  /// remote AI integration.
  ///
  /// Titles are excluded by default. Sakan can restore
  /// visible names locally after receiving the response.
  Map<String, dynamic> toAiPayload({bool includeTitles = false}) {
    final insight = primaryInsight;
    final relatedMoment = insight?.relatedMomentId == null
        ? null
        : snapshot.momentById(insight!.relatedMomentId!);
    final relatedRhythm = relatedMoment == null
        ? null
        : snapshot.rhythmForMoment(relatedMoment.id);

    return <String, dynamic>{
      'generatedAt': snapshot.generatedAt.toIso8601String(),
      'overallState': overallState.name,
      'overallConfidence': overallConfidence.name,
      'metrics': <String, dynamic>{
        'activeMembers': metrics.activeMemberCount,
        'upcomingMoments': metrics.upcomingMomentCount,
        'completedMoments': metrics.completedMomentCount,
        'driftingRhythms': metrics.driftingRhythmCount,
        'pendingReminders': metrics.pendingReminderCount,
        'overdueReminders': metrics.overdueReminderCount,
        'memories': metrics.memoryCount,
      },
      'primaryInsight': insight == null
          ? null
          : <String, dynamic>{
              'kind': insight.kind.name,
              'headline': includeTitles ? insight.headline : null,
              'summary': insight.summary,
              'reasons': insight.reasons,
              'suggestedActions': insight.suggestedActions,
              'confidence': insight.confidence.name,
              'recommendedReminderAt': insight.recommendedReminderAt
                  ?.toIso8601String(),
              'recommendedReminderUsesAvailability':
                  insight.recommendedReminderUsesAvailability,
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
              'startAt': relatedMoment.startAt.toIso8601String(),
              'status': relatedMoment.status.name,
              'rhythmStatus': relatedRhythm?.status.name,
              'rhythmConfidence': relatedRhythm?.confidence.name,
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
