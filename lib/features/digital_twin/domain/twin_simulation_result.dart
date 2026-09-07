import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import 'twin_simulation_scenario.dart';

enum SimulationDirection { improving, unchanged, increasedRisk, unknown }

extension SimulationDirectionLabel on SimulationDirection {
  String get label {
    return switch (this) {
      SimulationDirection.improving => 'Easier to maintain',
      SimulationDirection.unchanged => 'No projected change',
      SimulationDirection.increasedRisk => 'Harder to maintain',
      SimulationDirection.unknown => 'Not enough data',
    };
  }
}

class SimulatedMomentPattern {
  const SimulatedMomentPattern({
    required this.momentId,
    required this.currentStatus,
    required this.projectedStatus,
    required this.direction,
    required this.summary,
    required this.changes,
    required this.assumptions,
    required this.confidence,
    required this.currentParticipantCount,
    required this.projectedParticipantCount,
    this.currentConflictCount,
    this.projectedConflictCount,
    this.isHypothetical = false,
    this.isAffected = false,
  });

  final String momentId;
  final RhythmStatus currentStatus;
  final RhythmStatus projectedStatus;
  final SimulationDirection direction;

  final String summary;
  final List<String> changes;
  final List<String> assumptions;
  final ConfidenceLevel confidence;

  final int currentParticipantCount;
  final int projectedParticipantCount;
  final int? currentConflictCount;
  final int? projectedConflictCount;

  final bool isHypothetical;
  final bool isAffected;

  bool get statusChanged => currentStatus != projectedStatus;
}

class DigitalTwinSimulationResult {
  DigitalTwinSimulationResult({
    required this.id,
    required this.baseGeneratedAt,
    required this.scenario,
    required this.scenarioTitle,
    required this.scenarioSubtitle,
    required List<FamilyMoment> simulatedMoments,
    required Map<String, SimulatedMomentPattern> patternsByMomentId,
    required Set<String> changedMomentIds,
    required Set<String> changedMemberIds,
    required Set<String> hypotheticalMomentIds,
    required List<String> assumptions,
    required this.familySummary,
    required List<String> familyThemes,
    required this.confidence,
  }) : simulatedMoments = List<FamilyMoment>.unmodifiable(simulatedMoments),
       patternsByMomentId = Map<String, SimulatedMomentPattern>.unmodifiable(
         patternsByMomentId,
       ),
       changedMomentIds = Set<String>.unmodifiable(changedMomentIds),
       changedMemberIds = Set<String>.unmodifiable(changedMemberIds),
       hypotheticalMomentIds = Set<String>.unmodifiable(hypotheticalMomentIds),
       assumptions = List<String>.unmodifiable(assumptions),
       familyThemes = List<String>.unmodifiable(familyThemes);

  final String id;
  final DateTime baseGeneratedAt;
  final TwinSimulationScenario scenario;

  final String scenarioTitle;
  final String scenarioSubtitle;

  final List<FamilyMoment> simulatedMoments;
  final Map<String, SimulatedMomentPattern> patternsByMomentId;

  final Set<String> changedMomentIds;
  final Set<String> changedMemberIds;
  final Set<String> hypotheticalMomentIds;

  final List<String> assumptions;
  final String familySummary;
  final List<String> familyThemes;
  final ConfidenceLevel confidence;

  SimulatedMomentPattern? patternForMoment(String momentId) {
    return patternsByMomentId[momentId];
  }

  FamilyMoment? momentById(String momentId) {
    for (final moment in simulatedMoments) {
      if (moment.id == momentId) {
        return moment;
      }
    }

    return null;
  }

  /// The local-only new Moment that may be reviewed for creation.
  ///
  /// Existing-Moment simulations deliberately return null so they cannot
  /// accidentally create a duplicate definition.
  FamilyMoment? get creatableMoment {
    if (!scenario.createsMoment || hypotheticalMomentIds.length != 1) {
      return null;
    }

    return momentById(hypotheticalMomentIds.single);
  }

  bool isChangedMoment(String momentId) {
    return changedMomentIds.contains(momentId);
  }

  bool isChangedMember(String memberId) {
    return changedMemberIds.contains(memberId);
  }

  bool isHypotheticalMoment(String momentId) {
    return hypotheticalMomentIds.contains(momentId);
  }
}
