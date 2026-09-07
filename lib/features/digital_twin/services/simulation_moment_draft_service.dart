import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../domain/twin_simulation_result.dart';
import '../domain/twin_simulation_scenario.dart';

/// Converts a local-only new-Moment simulation into a form seed.
///
/// The returned object is never saved directly. The Moment form treats it as
/// a draft, asks an adult to approve the details, and creates a fresh ID.
abstract final class SimulationMomentDraftService {
  static FamilyMoment build(DigitalTwinSimulationResult simulation) {
    final candidate = simulation.creatableMoment;

    if (candidate == null) {
      throw StateError('This simulation does not contain a new Moment.');
    }

    final isOneTime =
        simulation.scenario.scope == TwinSimulationScope.nextOccurrence;
    final localStart = candidate.startAt.toLocal();
    final interval = candidate.expectedIntervalDays ?? 7;

    return candidate.copyWith(
      type: isOneTime ? MomentType.singular : MomentType.recurring,
      format: _defaultFormat(candidate.category),
      expectedIntervalDays: isOneTime ? null : interval,
      preferredStartMinutes: isOneTime
          ? null
          : candidate.resolvedPreferredStartMinutes,
      preferredEndMinutes: isOneTime
          ? null
          : candidate.resolvedPreferredEndMinutes,
      preferredWeekday: isOneTime || (interval != 7 && interval != 14)
          ? null
          : (candidate.preferredWeekday ?? localStart.weekday),
      preferredDayOfMonth:
          isOneTime || (interval != 30 && interval != 90 && interval != 365)
          ? null
          : (candidate.preferredDayOfMonth ?? localStart.day),
      preferredMonth: isOneTime || interval != 365
          ? null
          : (candidate.preferredMonth ?? localStart.month),
      // Creation needs an exact approved Calendar time. Resolve a flexible
      // projection to its displayed anchor; the adult may change it in-form.
      isDayFlexible: false,
      isArchived: false,
      status: MomentStatus.scheduled,
      evidenceType: EvidenceType.manual,
    );
  }

  static MomentFormat _defaultFormat(MomentCategory category) {
    return switch (category) {
      MomentCategory.milestone ||
      MomentCategory.responsibility ||
      MomentCategory.care => MomentFormat.externalEvent,
      MomentCategory.tradition ||
      MomentCategory.familyTime ||
      MomentCategory.memory => MomentFormat.sharedSession,
    };
  }
}
