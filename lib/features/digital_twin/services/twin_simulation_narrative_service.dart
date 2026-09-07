import '../../../shared/ai/ai_models.dart';
import '../../../shared/ai/sakan_ai_gateway.dart';
import '../domain/twin_simulation_result.dart';

class TwinSimulationNarrativeService {
  const TwinSimulationNarrativeService({required SakanAiGateway gateway})
    : _gateway = gateway;

  final SakanAiGateway _gateway;

  Future<SakanAiResult> explain(DigitalTwinSimulationResult simulation) {
    final patterns = simulation.patternsByMomentId.values
        .where((pattern) => pattern.isAffected)
        .map((pattern) {
          final moment = simulation.momentById(pattern.momentId);
          return <String, dynamic>{
            'momentId': pattern.momentId,
            'momentTitle': moment?.title,
            'momentCategory': moment?.category.name,
            'currentStatus': pattern.currentStatus.name,
            'projectedStatus': pattern.projectedStatus.name,
            'direction': pattern.direction.name,
            'confidence': pattern.confidence.name,
            'isHypothetical': pattern.isHypothetical,
            'isOneTimeProjection': pattern.isOneTimeProjection,
            'canCreateMoment':
                simulation.creatableMoment?.id == pattern.momentId,
            'currentParticipantCount': pattern.currentParticipantCount,
            'projectedParticipantCount': pattern.projectedParticipantCount,
            'currentConflictCount': pattern.currentConflictCount,
            'projectedConflictCount': pattern.projectedConflictCount,
            'projectedScheduleCoverageComplete':
                pattern.projectedScheduleCoverageComplete,
            'deterministicSummary': pattern.summary,
            'changes': pattern.changes,
            'assumptions': pattern.assumptions,
          };
        })
        .toList(growable: false);

    return _gateway.generate(
      feature: SakanAiFeature.simulationExplain,
      targetId: simulation.id,
      grounding: <String, dynamic>{
        'scenarioType': simulation.scenario.type.name,
        'scenarioScope': simulation.scenario.scope.name,
        'scenarioTitle': simulation.scenarioTitle,
        'scenarioSubtitle': simulation.scenarioSubtitle,
        'confidence': simulation.confidence.name,
        'patterns': patterns,
        'assumptions': simulation.assumptions,
        'deterministicSummary': simulation.familySummary,
        'deterministicThemes': simulation.familyThemes,
      },
    );
  }
}
