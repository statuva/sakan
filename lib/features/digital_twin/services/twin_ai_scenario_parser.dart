import '../../../shared/models/family_insight_report.dart';
import '../domain/twin_simulation_scenario.dart';

/// Future integration point for a protected backend that converts a natural-
/// language What If request into the same validated scenario used by the local
/// deterministic simulation engine.
///
/// No implementation is registered in the current build. The OpenAI key must
/// never be placed in Flutter; a later implementation should call an
/// authenticated backend and validate the returned scenario before use.
abstract interface class TwinAiScenarioParser {
  Future<TwinAiScenarioParseResult> parse({
    required String prompt,
    required FamilyInsightReport report,
  });
}

class TwinAiScenarioParseResult {
  const TwinAiScenarioParseResult({
    required this.scenario,
    required this.interpretedSummary,
    this.clarificationQuestion,
  });

  final TwinSimulationScenario? scenario;
  final String interpretedSummary;
  final String? clarificationQuestion;

  bool get needsClarification {
    return scenario == null && clarificationQuestion != null;
  }
}
