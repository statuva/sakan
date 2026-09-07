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
      SimulationDirection.unknown => 'Evidence still growing',
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
    this.projectedScheduleCoverageComplete = false,
    this.isHypothetical = false,
    this.isOneTimeProjection = false,
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
  final bool projectedScheduleCoverageComplete;

  final bool isHypothetical;
  final bool isOneTimeProjection;
  final bool isAffected;

  bool get statusChanged => currentStatus != projectedStatus;

  String get cardSubtitle {
    if (!isHypothetical) {
      return direction.label;
    }

    return (projectedConflictCount ?? 0) > 0
        ? 'New idea · choose another time'
        : 'New idea · early potential';
  }
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

  /// Early projections need a useful deterministic explanation before an AI
  /// narrative. A Still Learning status describes evidence, not the value of
  /// trying the Moment.
  bool get shouldLeadWithDeterministicBenefit {
    for (final pattern in patternsByMomentId.values) {
      if (!pattern.isAffected) {
        continue;
      }

      if (pattern.isHypothetical) {
        return (pattern.projectedConflictCount ?? 0) == 0;
      }

      final remainsEarlyLearning =
          pattern.currentStatus == RhythmStatus.stillLearning &&
          pattern.projectedStatus == RhythmStatus.stillLearning;
      if (!remainsEarlyLearning) {
        return false;
      }

      return switch (scenario.type) {
        TwinSimulationType.assumeNextCompleted ||
        TwinSimulationType.assumeParticipantJoins => true,
        TwinSimulationType.changeTime ||
        TwinSimulationType.changeWeekday ||
        TwinSimulationType.changeDayOfMonth =>
          pattern.direction == SimulationDirection.improving &&
              pattern.projectedConflictCount == 0,
        TwinSimulationType.changeFrequency =>
          pattern.direction == SimulationDirection.improving &&
              (pattern.projectedConflictCount ?? 0) == 0,
        TwinSimulationType.addParticipant =>
          pattern.direction != SimulationDirection.increasedRisk &&
              (pattern.projectedConflictCount ?? 0) == 0,
        TwinSimulationType.assumeNextMissed ||
        TwinSimulationType.removeParticipant ||
        TwinSimulationType.createMoment => false,
      };
    }

    return false;
  }

  bool get shouldUseDeterministicNarrative {
    // A missed outcome must remain factual even when an already-drifting
    // rhythm stays Drifting and therefore has an `unchanged` direction.
    if (scenario.type == TwinSimulationType.assumeNextMissed) {
      return true;
    }

    for (final pattern in patternsByMomentId.values) {
      if (!pattern.isAffected) {
        continue;
      }

      return pattern.isHypothetical ||
          (pattern.projectedConflictCount ?? 0) > 0 ||
          (pattern.currentStatus == RhythmStatus.stillLearning &&
              pattern.projectedStatus == RhythmStatus.stillLearning) ||
          pattern.direction == SimulationDirection.increasedRisk ||
          pattern.direction == SimulationDirection.unknown;
    }

    return true;
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
