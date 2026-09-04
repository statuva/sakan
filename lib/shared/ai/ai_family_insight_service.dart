import '../models/family_insight_report.dart';
import 'ai_models.dart';
import 'sakan_ai_gateway.dart';

class AiFamilyInsightService {
  AiFamilyInsightService({required SakanAiGateway gateway})
    : _gateway = gateway;

  final SakanAiGateway _gateway;
  final Map<String, Future<SakanAiResult>> _inFlightOrCached =
      <String, Future<SakanAiResult>>{};

  Future<SakanAiResult> enrich({
    required FamilyInsightItem insight,
    required String familyId,
    required String memberId,
  }) {
    final key = <Object?>[
      familyId,
      memberId,
      insight.id,
      insight.kind.name,
      insight.actionType.name,
      insight.relatedMomentId,
      insight.relatedInstanceId,
      insight.relatedReminderId,
      insight.confidence.name,
      insight.headline,
      insight.summary,
      insight.recommendedActionAt?.toUtc().toIso8601String(),
      insight.recommendedActionUsesAvailability,
      ...insight.reasons,
      ...insight.suggestedActions,
    ].join('|');

    return _inFlightOrCached.putIfAbsent(key, () => _load(insight));
  }

  Future<SakanAiResult> _load(FamilyInsightItem insight) {
    return _gateway.generate(
      feature: SakanAiFeature.homeInsight,
      targetId:
          insight.relatedInstanceId ??
          insight.relatedMomentId ??
          insight.relatedReminderId,
      grounding: <String, dynamic>{
        'insightId': insight.id,
        'kind': insight.kind.name,
        'actionType': insight.actionType.name,
        'confidence': insight.confidence.name,
        'relatedMomentId': insight.relatedMomentId,
        'relatedInstanceId': insight.relatedInstanceId,
        'relatedReminderId': insight.relatedReminderId,
        'recommendedActionAt': insight.recommendedActionAt
            ?.toUtc()
            .toIso8601String(),
        'recommendedActionUsesAvailability':
            insight.recommendedActionUsesAvailability,
        'baselineHeadline': insight.headline,
        'baselineSummary': insight.summary,
        'baselineReasons': insight.reasons,
        'baselineSuggestedActions': insight.suggestedActions,
      },
    );
  }

  void clear() => _inFlightOrCached.clear();
}
