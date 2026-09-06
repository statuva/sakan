import 'dart:convert';

import '../../../shared/ai/ai_models.dart';
import '../../../shared/ai/sakan_ai_gateway.dart';
import '../../../shared/models/family_insight_report.dart';
import 'digital_twin_interpretation_service.dart';

class TwinFamilyNarrativeService {
  TwinFamilyNarrativeService({required SakanAiGateway gateway})
    : _gateway = gateway;

  final SakanAiGateway _gateway;
  final DigitalTwinInterpretationService _interpretationService =
      const DigitalTwinInterpretationService();
  final Map<String, Future<SakanAiResult>> _cache =
      <String, Future<SakanAiResult>>{};

  Future<SakanAiResult> explain({
    required FamilyInsightReport report,
  }) {
    final grounding = _interpretationService.buildFamilyAiPayload(
      moments: report.snapshot.moments,
      rhythms: report.snapshot.rhythms,
      instances: report.snapshot.instances,
      referenceDate: report.snapshot.generatedAt,
    );
    final key = jsonEncode(<String, dynamic>{
      'familyId': report.snapshot.familyId,
      'memberId': report.snapshot.currentUserId,
      'grounding': grounding,
    });
    return _cache.putIfAbsent(key, () => _load(grounding));
  }

  void clear() => _cache.clear();

  Future<SakanAiResult> _load(Map<String, dynamic> grounding) {
    return _gateway.generate(
      feature: SakanAiFeature.digitalTwinReflection,
      grounding: grounding,
    );
  }
}
