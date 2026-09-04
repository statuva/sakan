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
        .map(
          (pattern) => <String, dynamic>{
            'momentId': pattern.momentId,
            'currentStatus': pattern.currentStatus.name,
            'projectedStatus': pattern.projectedStatus.name,
            'direction': pattern.direction.name,
            'confidence': pattern.confidence.name,
            'currentParticipantCount': pattern.currentParticipantCount,
            'projectedParticipantCount': pattern.projectedParticipantCount,
            'currentConflictCount': pattern.currentConflictCount,
            'projectedConflictCount': pattern.projectedConflictCount,
            'changes': pattern.changes,
            'assumptions': pattern.assumptions,
          },
        )
        .toList(growable: false);

    return _gateway.generate(
      feature: SakanAiFeature.simulationExplain,
      targetId: simulation.id,
      grounding: <String, dynamic>{
        'scenarioType': simulation.scenario.type.name,
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
