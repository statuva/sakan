import '../../../shared/ai/ai_models.dart';
import '../../../shared/ai/sakan_ai_gateway.dart';
import '../../../shared/models/family_insight_report.dart';
import '../../../shared/models/model_enums.dart';
import '../domain/twin_simulation_scenario.dart';
import 'twin_ai_scenario_parser.dart';

class RemoteTwinAiScenarioParser implements TwinAiScenarioParser {
  const RemoteTwinAiScenarioParser({required SakanAiGateway gateway})
    : _gateway = gateway;

  final SakanAiGateway _gateway;

  @override
  Future<TwinAiScenarioParseResult> parse({
    required String prompt,
    required FamilyInsightReport report,
  }) async {
    final result = await _gateway.generate(
      feature: SakanAiFeature.simulationParse,
      prompt: prompt,
    );
    final raw = result.scenario;
    if (raw == null) {
      return TwinAiScenarioParseResult(
        scenario: null,
        interpretedSummary: result.text,
        clarificationQuestion: result.text,
      );
    }

    final scenario = _scenarioFromMap(raw);
    final targetId = scenario.targetMomentId;
    if (targetId != null) {
      final targetMoment = report.snapshot.momentById(targetId);
      if (targetMoment == null) {
        throw const FormatException('AI selected an unavailable Moment.');
      }
      if (targetMoment.type != MomentType.recurring ||
          targetMoment.isArchived) {
        throw const FormatException(
          'AI selected a Moment that cannot be simulated.',
        );
      }
    }

    final activeMemberIds = report.snapshot.activeMembers
        .map((member) => member.id)
        .toSet();
    if (scenario.participantIds.any(
      (memberId) => !activeMemberIds.contains(memberId),
    )) {
      throw const FormatException('AI selected an unavailable family member.');
    }

    final validationError = scenario.validate();
    if (validationError != null) {
      throw FormatException(validationError);
    }

    return TwinAiScenarioParseResult(
      scenario: scenario,
      interpretedSummary: result.text,
    );
  }

  TwinSimulationScenario _scenarioFromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String?;
    final type = _simulationTypeByName(typeName);
    if (type == null) {
      throw const FormatException('AI returned an unknown simulation type.');
    }

    final scopeName = map['scope'] as String?;
    final scope =
        _simulationScopeByName(scopeName) ?? TwinSimulationScope.nextOccurrence;

    final categoryName = map['newCategory'] as String?;
    final category = _momentCategoryByName(categoryName);

    return TwinSimulationScenario(
      id: 'ai_what_if_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      source: TwinSimulationSource.aiParsed,
      targetMomentId: _optionalString(map['targetMomentId']),
      participantIds: (map['participantIds'] as List? ?? const <Object>[])
          .whereType<String>()
          .toList(growable: false),
      newTitle: _optionalString(map['newTitle']),
      newCategory: category,
      newIntervalDays: _optionalInt(map['newIntervalDays']),
      newStartMinutes: _optionalInt(map['newStartMinutes']),
      newWeekday: _optionalInt(map['newWeekday']),
      newDayOfMonth: _optionalInt(map['newDayOfMonth']),
      newMonth: _optionalInt(map['newMonth']),
      newIsDayFlexible: map['newIsDayFlexible'] == true,
      scope: scope,
      assumedDurationMinutes: _optionalInt(map['assumedDurationMinutes']),
    );
  }

  String? _optionalString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  int? _optionalInt(Object? value) {
    return value is num ? value.toInt() : null;
  }

  TwinSimulationType? _simulationTypeByName(String? name) {
    for (final value in TwinSimulationType.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  TwinSimulationScope? _simulationScopeByName(String? name) {
    for (final value in TwinSimulationScope.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  MomentCategory? _momentCategoryByName(String? name) {
    for (final value in MomentCategory.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
