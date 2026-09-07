import 'package:intl/intl.dart';

import '../../../shared/models/availability_block.dart';
import '../../../shared/models/family_insight_report.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/models/rhythm_record.dart';
import '../../../shared/services/moment_schedule_resolver.dart';
import '../domain/twin_simulation_result.dart';
import '../domain/twin_simulation_scenario.dart';

class DigitalTwinSimulationService {
  const DigitalTwinSimulationService();

  static const int projectionHorizon = 4;
  static const int defaultDurationMinutes = 90;

  DigitalTwinSimulationResult simulate({
    required FamilyInsightReport baseReport,
    required TwinSimulationScenario scenario,
  }) {
    final validationError = scenario.validate();

    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final snapshot = baseReport.snapshot;
    final activeMemberIds = snapshot.activeMembers
        .map((member) => member.id)
        .toSet();

    if (scenario.participantIds.any(
      (memberId) => !activeMemberIds.contains(memberId),
    )) {
      throw StateError(
        'Every simulated participant must be an active member of this family.',
      );
    }

    final simulatedMoments = List<FamilyMoment>.from(snapshot.moments);
    final patterns = <String, SimulatedMomentPattern>{};

    for (final moment in simulatedMoments.where(
      (item) => item.type == MomentType.recurring,
    )) {
      final rhythm = snapshot.rhythmForMoment(moment.id);
      final status = rhythm?.status ?? RhythmStatus.stillLearning;

      patterns[moment.id] = SimulatedMomentPattern(
        momentId: moment.id,
        currentStatus: status,
        projectedStatus: status,
        direction: SimulationDirection.unchanged,
        summary: 'This Moment is not changed by the current simulation.',
        changes: const <String>[],
        assumptions: const <String>[],
        confidence: rhythm?.confidence ?? ConfidenceLevel.low,
        currentParticipantCount: moment.expectedParticipantIds.length,
        projectedParticipantCount: moment.expectedParticipantIds.length,
      );
    }

    final changedMomentIds = <String>{};
    final changedMemberIds = <String>{...scenario.participantIds};
    final hypotheticalMomentIds = <String>{};

    late final FamilyMoment affectedMoment;
    late final SimulatedMomentPattern affectedPattern;
    late final String scenarioTitle;
    late final String scenarioSubtitle;

    if (scenario.createsMoment) {
      affectedMoment = _buildHypotheticalMoment(
        baseReport: baseReport,
        scenario: scenario,
      );

      simulatedMoments.add(affectedMoment);
      changedMomentIds.add(affectedMoment.id);
      hypotheticalMomentIds.add(affectedMoment.id);

      affectedPattern = _newMomentPattern(
        baseReport: baseReport,
        moment: affectedMoment,
        scenario: scenario,
      );

      scenarioTitle = 'What if your family added ${affectedMoment.title}?';
      final timingLabel = scenario.scope == TwinSimulationScope.nextOccurrence
          ? 'One hypothetical occurrence'
          : _frequencyLabel(affectedMoment.expectedIntervalDays);
      scenarioSubtitle =
          '$timingLabel · ${affectedMoment.expectedParticipantIds.length} '
          'expected ${affectedMoment.expectedParticipantIds.length == 1 ? 'participant' : 'participants'}';
    } else {
      final targetId = scenario.targetMomentId!;
      final targetIndex = simulatedMoments.indexWhere(
        (moment) => moment.id == targetId,
      );

      if (targetIndex == -1) {
        throw StateError('The selected Family Moment could not be found.');
      }

      final originalMoment = simulatedMoments[targetIndex];

      if (originalMoment.type != MomentType.recurring) {
        throw StateError(
          'What If simulations currently use recurring Family Moments.',
        );
      }

      if (originalMoment.isArchived) {
        throw StateError('Archived Moments cannot be simulated.');
      }

      affectedMoment = _applyScenarioToMoment(
        baseReport: baseReport,
        original: originalMoment,
        scenario: scenario,
      );

      simulatedMoments[targetIndex] = affectedMoment;
      changedMomentIds.add(affectedMoment.id);

      affectedPattern = _buildAffectedPattern(
        baseReport: baseReport,
        original: originalMoment,
        simulated: affectedMoment,
        scenario: scenario,
      );

      scenarioTitle = _scenarioTitle(
        baseReport: baseReport,
        moment: originalMoment,
        scenario: scenario,
      );

      scenarioSubtitle = _scenarioSubtitle(
        moment: originalMoment,
        scenario: scenario,
      );
    }

    patterns[affectedMoment.id] = affectedPattern;

    final assumptions = <String>{
      'This is a local projection. It does not change Firestore or the real Digital Twin.',
      if (!scenario.isOutcomeAssumption &&
          scenario.scope == TwinSimulationScope.futureOccurrences)
        'Schedule comparisons use the next $projectionHorizon projected occurrences.',
      ...affectedPattern.assumptions,
      'Sakan does not predict relationship quality, emotions, or whether people will actually attend.',
    }.toList(growable: false);

    final familySummary = _familySummary(
      moment: affectedMoment,
      pattern: affectedPattern,
      scenario: scenario,
    );

    final remainsEarlyLearning =
        affectedPattern.currentStatus == RhythmStatus.stillLearning &&
        affectedPattern.projectedStatus == RhythmStatus.stillLearning;
    final isPositiveScheduleTrial =
        affectedPattern.direction == SimulationDirection.improving &&
        (scenario.type == TwinSimulationType.changeFrequency
            ? (affectedPattern.projectedConflictCount ?? 0) == 0
            : scenario.changesSchedule &&
                  affectedPattern.projectedConflictCount == 0);
    final isPositiveEarlyTrial =
        remainsEarlyLearning &&
        (scenario.type == TwinSimulationType.assumeNextCompleted ||
            scenario.type == TwinSimulationType.assumeParticipantJoins ||
            (scenario.type == TwinSimulationType.addParticipant &&
                affectedPattern.direction !=
                    SimulationDirection.increasedRisk &&
                (affectedPattern.projectedConflictCount ?? 0) == 0) ||
            isPositiveScheduleTrial);
    final themes = <String>[
      scenario.type.label,
      if (affectedPattern.isHypothetical)
        (affectedPattern.projectedConflictCount ?? 0) > 0
            ? 'Schedule conflict · choose another time'
            : !affectedPattern.projectedScheduleCoverageComplete
            ? 'Confirm family availability'
            : 'Early potential'
      else if (isPositiveEarlyTrial)
        'Benefit can be tested'
      else if (scenario.changesSchedule &&
          (affectedPattern.projectedConflictCount ?? 0) > 0)
        affectedPattern.direction == SimulationDirection.improving
            ? 'Fewer conflicts · time still needs review'
            : 'Recorded conflicts · review the time'
      else if (affectedPattern.statusChanged)
        '${_statusLabel(affectedPattern.currentStatus)} → Projected ${_statusLabel(affectedPattern.projectedStatus)}'
      else
        affectedPattern.direction.label,
      '${_confidenceLabel(affectedPattern.confidence)} projection',
    ];

    return DigitalTwinSimulationResult(
      id:
          'simulation_${scenario.id}_'
          '${snapshot.generatedAt.microsecondsSinceEpoch}',
      baseGeneratedAt: snapshot.generatedAt,
      scenario: scenario,
      scenarioTitle: scenarioTitle,
      scenarioSubtitle: scenarioSubtitle,
      simulatedMoments: simulatedMoments,
      patternsByMomentId: patterns,
      changedMomentIds: changedMomentIds,
      changedMemberIds: changedMemberIds,
      hypotheticalMomentIds: hypotheticalMomentIds,
      assumptions: assumptions,
      familySummary: familySummary,
      familyThemes: themes,
      confidence: affectedPattern.confidence,
    );
  }

  FamilyMoment _buildHypotheticalMoment({
    required FamilyInsightReport baseReport,
    required TwinSimulationScenario scenario,
  }) {
    final snapshot = baseReport.snapshot;
    final now = snapshot.generatedAt.toLocal();
    final interval = scenario.newIntervalDays!;
    final startMinutes = scenario.newStartMinutes!;

    final exactStart = MomentScheduleResolver.firstExactStart(
      type: MomentType.recurring,
      reference: now,
      startMinutes: startMinutes,
      intervalDays: interval,
      isDayFlexible: scenario.newIsDayFlexible,
      preferredWeekday: scenario.newWeekday,
      preferredDayOfMonth: scenario.newDayOfMonth,
      preferredMonth: scenario.newMonth,
    );

    final anchor =
        exactStart ??
        MomentScheduleResolver.anchorForFlexible(
          reference: now,
          startMinutes: startMinutes,
        );

    final duration = scenario.assumedDurationMinutes ?? defaultDurationMinutes;
    final end = anchor.add(Duration(minutes: duration));

    return FamilyMoment(
      id: 'simulated_moment_${scenario.id}',
      familyId: snapshot.familyId,
      title: scenario.newTitle!.trim(),
      type: MomentType.recurring,
      category: scenario.newCategory!,
      importanceLevel: 3,
      expectedParticipantIds: _sortedUnique(scenario.participantIds),
      startAt: anchor.toUtc(),
      endAt: end.toUtc(),
      expectedIntervalDays: interval,
      preferredStartMinutes: startMinutes,
      preferredEndMinutes: _minuteOfDay(end),
      preferredWeekday: scenario.newWeekday,
      preferredDayOfMonth: scenario.newDayOfMonth,
      preferredMonth: scenario.newMonth,
      isDayFlexible: scenario.newIsDayFlexible,
      isArchived: false,
      evidenceType: EvidenceType.manual,
      status: MomentStatus.scheduled,
      createdBy: snapshot.currentUserId,
      createdAt: snapshot.generatedAt,
      updatedAt: snapshot.generatedAt,
    );
  }

  FamilyMoment _applyScenarioToMoment({
    required FamilyInsightReport baseReport,
    required FamilyMoment original,
    required TwinSimulationScenario scenario,
  }) {
    switch (scenario.type) {
      case TwinSimulationType.addParticipant:
      case TwinSimulationType.assumeParticipantJoins:
        return original.copyWith(
          expectedParticipantIds: _sortedUnique(<String>[
            ...original.expectedParticipantIds,
            ...scenario.participantIds,
          ]),
        );

      case TwinSimulationType.removeParticipant:
        final remaining = original.expectedParticipantIds
            .where((id) => !scenario.participantIds.contains(id))
            .toList(growable: false);

        if (remaining.isEmpty) {
          throw StateError('A Moment must keep at least one participant.');
        }

        return original.copyWith(
          expectedParticipantIds: _sortedUnique(remaining),
        );

      case TwinSimulationType.changeTime:
        return _copyWithSchedule(
          baseReport: baseReport,
          moment: original,
          startMinutes: scenario.newStartMinutes!,
          intervalDays: original.expectedIntervalDays ?? 7,
          isDayFlexible: original.isDayFlexible,
          preferredWeekday: original.preferredWeekday,
          preferredDayOfMonth: original.preferredDayOfMonth,
          preferredMonth: original.preferredMonth,
        );

      case TwinSimulationType.changeWeekday:
        return _copyWithSchedule(
          baseReport: baseReport,
          moment: original,
          startMinutes: original.resolvedPreferredStartMinutes,
          intervalDays: original.expectedIntervalDays ?? 7,
          isDayFlexible: false,
          preferredWeekday: scenario.newWeekday,
          preferredDayOfMonth: original.preferredDayOfMonth,
          preferredMonth: original.preferredMonth,
        );

      case TwinSimulationType.changeDayOfMonth:
        return _copyWithSchedule(
          baseReport: baseReport,
          moment: original,
          startMinutes: original.resolvedPreferredStartMinutes,
          intervalDays: original.expectedIntervalDays ?? 30,
          isDayFlexible: false,
          preferredWeekday: original.preferredWeekday,
          preferredDayOfMonth: scenario.newDayOfMonth,
          preferredMonth: original.preferredMonth,
        );

      case TwinSimulationType.changeFrequency:
        final interval = scenario.newIntervalDays!;
        final supportsFlexible =
            interval == 7 || interval == 14 || interval == 30 || interval == 90;
        final flexible = supportsFlexible && original.isDayFlexible;

        final weekday = interval == 7 || interval == 14
            ? original.preferredWeekday ?? original.startAt.toLocal().weekday
            : null;

        final dayOfMonth = interval == 30 || interval == 90 || interval == 365
            ? original.preferredDayOfMonth ?? original.startAt.toLocal().day
            : null;

        final month = interval == 365
            ? original.preferredMonth ?? original.startAt.toLocal().month
            : null;

        return _copyWithSchedule(
          baseReport: baseReport,
          moment: original,
          startMinutes: original.resolvedPreferredStartMinutes,
          intervalDays: interval,
          isDayFlexible: flexible,
          preferredWeekday: weekday,
          preferredDayOfMonth: dayOfMonth,
          preferredMonth: month,
        );

      case TwinSimulationType.assumeNextCompleted:
      case TwinSimulationType.assumeNextMissed:
        return original;

      case TwinSimulationType.createMoment:
        throw StateError('A new Moment is built through a separate path.');
    }
  }

  FamilyMoment _copyWithSchedule({
    required FamilyInsightReport baseReport,
    required FamilyMoment moment,
    required int startMinutes,
    required int intervalDays,
    required bool isDayFlexible,
    required int? preferredWeekday,
    required int? preferredDayOfMonth,
    required int? preferredMonth,
  }) {
    final reference = baseReport.snapshot.generatedAt.toLocal();
    final duration = _plannedDurationMinutes(moment);

    final exactStart = MomentScheduleResolver.firstExactStart(
      type: MomentType.recurring,
      reference: reference,
      startMinutes: startMinutes,
      intervalDays: intervalDays,
      isDayFlexible: isDayFlexible,
      preferredWeekday: preferredWeekday,
      preferredDayOfMonth: preferredDayOfMonth,
      preferredMonth: preferredMonth,
    );

    final anchor =
        exactStart ??
        MomentScheduleResolver.anchorForFlexible(
          reference: reference,
          startMinutes: startMinutes,
        );

    final end = duration == null
        ? null
        : anchor.add(Duration(minutes: duration));

    return moment.copyWith(
      startAt: anchor.toUtc(),
      endAt: end?.toUtc(),
      expectedIntervalDays: intervalDays,
      preferredStartMinutes: startMinutes,
      preferredEndMinutes: end == null ? null : _minuteOfDay(end),
      preferredWeekday: preferredWeekday,
      preferredDayOfMonth: preferredDayOfMonth,
      preferredMonth: preferredMonth,
      isDayFlexible: isDayFlexible,
      updatedAt: baseReport.snapshot.generatedAt,
    );
  }

  SimulatedMomentPattern _newMomentPattern({
    required FamilyInsightReport baseReport,
    required FamilyMoment moment,
    required TwinSimulationScenario scenario,
  }) {
    final isOneTime = scenario.scope == TwinSimulationScope.nextOccurrence;
    final schedule = _projectSchedule(
      baseReport: baseReport,
      moment: moment,
      count: isOneTime ? 1 : projectionHorizon,
    );
    final conflictCount = schedule.conflictCount;
    final benefit = _momentBenefit(moment, isOneTime: isOneTime);
    final recommendation = _newMomentRecommendation(
      conflictCount: conflictCount,
      hasCompleteCoverage: schedule.hasCompleteCoverage,
    );
    final summary = (conflictCount ?? 0) > 0
        ? 'This time has $conflictCount recorded schedule '
              '${conflictCount == 1 ? 'conflict' : 'conflicts'}. '
              '$benefit $recommendation'
        : '$benefit $recommendation';
    return SimulatedMomentPattern(
      momentId: moment.id,
      currentStatus: RhythmStatus.stillLearning,
      projectedStatus: RhythmStatus.stillLearning,
      direction: SimulationDirection.unknown,
      summary: summary,
      changes: <String>[
        'New ${isOneTime ? 'one-time' : 'recurring'} ${_categoryLabel(moment.category)}',
        if (isOneTime)
          'Planned at ${_formatMinutes(moment.resolvedPreferredStartMinutes)}'
        else
          '${_frequencyLabel(moment.expectedIntervalDays)} at '
              '${_formatMinutes(moment.resolvedPreferredStartMinutes)}',
        '${moment.expectedParticipantIds.length} expected '
            '${moment.expectedParticipantIds.length == 1 ? 'participant' : 'participants'}',
        if (conflictCount != null)
          schedule.hasCompleteCoverage
              ? 'Recorded availability conflicts: $conflictCount'
              : 'Recorded conflicts in available schedules: $conflictCount',
      ],
      assumptions: <String>[
        'The new Moment has no completed or missed history.',
        if (isOneTime)
          'Only this hypothetical occurrence is considered.'
        else
          'Its first projected state is Still Learning.',
      ],
      confidence: ConfidenceLevel.low,
      currentParticipantCount: 0,
      projectedParticipantCount: moment.expectedParticipantIds.length,
      projectedConflictCount: conflictCount,
      projectedScheduleCoverageComplete: schedule.hasCompleteCoverage,
      isHypothetical: true,
      isOneTimeProjection: isOneTime,
      isAffected: true,
    );
  }

  SimulatedMomentPattern _buildAffectedPattern({
    required FamilyInsightReport baseReport,
    required FamilyMoment original,
    required FamilyMoment simulated,
    required TwinSimulationScenario scenario,
  }) {
    final snapshot = baseReport.snapshot;
    final rhythm = snapshot.rhythmForMoment(original.id);
    final instances = snapshot.instancesForMoment(original.id);
    final currentStatus = rhythm?.status ?? RhythmStatus.stillLearning;
    final changes = _changesForScenario(
      baseReport: baseReport,
      original: original,
      simulated: simulated,
      scenario: scenario,
    );

    final assumptions = <String>[];
    SimulationDirection direction;
    RhythmStatus projectedStatus;
    String summary;
    int? currentConflicts;
    int? projectedConflicts;
    var projectedScheduleCoverageComplete = false;
    var frequencyUsesRecordedCadence = false;

    switch (scenario.type) {
      case TwinSimulationType.assumeNextCompleted:
        projectedStatus = _statusAfterCompleted(
          currentStatus: currentStatus,
          occurrenceCount:
              rhythm?.occurrenceCount ?? _completedInstances(instances).length,
        );
        direction = projectedStatus == currentStatus
            ? SimulationDirection.unchanged
            : SimulationDirection.improving;
        summary =
            'If the next occurrence is completed as assumed, '
            '${original.title} could move from ${_statusLabel(currentStatus)} '
            'toward Projected ${_statusLabel(projectedStatus)}.';
        assumptions.add(
          'The next occurrence is completed for about '
          '${scenario.assumedDurationMinutes ?? defaultDurationMinutes} minutes.',
        );
        assumptions.add(
          'At least one expected participant confirms attendance.',
        );
        break;

      case TwinSimulationType.assumeParticipantJoins:
        projectedStatus = _statusAfterCompleted(
          currentStatus: currentStatus,
          occurrenceCount:
              rhythm?.occurrenceCount ?? _completedInstances(instances).length,
        );
        direction = projectedStatus == currentStatus
            ? SimulationDirection.unchanged
            : SimulationDirection.improving;
        final memberName = _memberNames(
          snapshot.members,
          scenario.participantIds,
        ).join(', ');
        summary =
            'If $memberName joins a completed next occurrence, '
            '${original.title} may move toward '
            'Projected ${_statusLabel(projectedStatus)}. '
            'This does not claim that the member will attend.';
        assumptions.add('$memberName checks in during the next occurrence.');
        assumptions.add(
          'The occurrence lasts about '
          '${scenario.assumedDurationMinutes ?? defaultDurationMinutes} minutes.',
        );
        break;

      case TwinSimulationType.assumeNextMissed:
        projectedStatus = _statusAfterMissed(currentStatus);
        direction = projectedStatus == currentStatus
            ? SimulationDirection.unchanged
            : SimulationDirection.increasedRisk;
        summary =
            'If the next occurrence is missed, ${original.title} could move '
            'from ${_statusLabel(currentStatus)} toward '
            'Projected ${_statusLabel(projectedStatus)}.';
        assumptions.add('The next occurrence receives a missed outcome.');
        break;

      case TwinSimulationType.changeTime:
      case TwinSimulationType.changeWeekday:
      case TwinSimulationType.changeDayOfMonth:
        final comparison = _compareSchedules(
          baseReport: baseReport,
          currentMoment: original,
          simulatedMoment: simulated,
        );
        currentConflicts = comparison.currentConflictCount;
        projectedConflicts = comparison.projectedConflictCount;
        projectedScheduleCoverageComplete =
            comparison.projectedScheduleCoverageComplete;
        direction = comparison.direction;
        projectedStatus = _statusAfterPlanChange(
          currentStatus: currentStatus,
          direction: direction,
          scope: scenario.scope,
        );
        summary = _scheduleSummary(
          title: original.title,
          direction: direction,
          currentConflicts: currentConflicts,
          projectedConflicts: projectedConflicts,
        );
        assumptions.add(
          'Only recorded busy periods are used; unrecorded plans are unknown.',
        );
        break;

      case TwinSimulationType.changeFrequency:
        final comparison = _compareSchedules(
          baseReport: baseReport,
          currentMoment: original,
          simulatedMoment: simulated,
        );
        currentConflicts = comparison.currentConflictCount;
        projectedConflicts = comparison.projectedConflictCount;
        projectedScheduleCoverageComplete =
            comparison.projectedScheduleCoverageComplete;

        final observedGap = _medianCompletedGap(instances);
        direction = _frequencyDirection(
          observedGapDays: observedGap,
          currentIntervalDays: original.expectedIntervalDays,
          projectedIntervalDays: simulated.expectedIntervalDays,
          fallback: comparison.direction,
        );
        frequencyUsesRecordedCadence =
            observedGap != null &&
            original.expectedIntervalDays != null &&
            simulated.expectedIntervalDays != null &&
            (observedGap - simulated.expectedIntervalDays!).abs() <
                (observedGap - original.expectedIntervalDays!).abs();

        projectedStatus = _statusAfterPlanChange(
          currentStatus: currentStatus,
          direction: direction,
          scope: scenario.scope,
        );

        summary = observedGap == null
            ? _scheduleSummary(
                title: original.title,
                direction: direction,
                currentConflicts: currentConflicts,
                projectedConflicts: projectedConflicts,
              )
            : '${original.title} has recently occurred about every '
                  '$observedGap days. Changing the planned rhythm from '
                  '${_frequencyLabel(original.expectedIntervalDays)} to '
                  '${_frequencyLabel(simulated.expectedIntervalDays)} '
                  '${direction == SimulationDirection.improving
                      ? 'is closer to that recorded pattern'
                      : direction == SimulationDirection.increasedRisk
                      ? 'is farther from that recorded pattern'
                      : 'does not materially change the fit with that recorded pattern'}.';
        assumptions.add(
          'The recent median gap is treated as a guide, not a promise of future behavior.',
        );
        break;

      case TwinSimulationType.addParticipant:
        projectedStatus = currentStatus;
        final comparison = _compareSchedules(
          baseReport: baseReport,
          currentMoment: original,
          simulatedMoment: simulated,
        );
        currentConflicts = comparison.currentConflictCount;
        projectedConflicts = comparison.projectedConflictCount;
        projectedScheduleCoverageComplete =
            comparison.projectedScheduleCoverageComplete;
        // If the added member has a known conflict, that risk is useful even
        // when the original group has no schedule records to compare against.
        direction = currentConflicts == null &&
                projectedConflicts != null &&
                projectedConflicts > 0
            ? SimulationDirection.increasedRisk
            : comparison.direction;
        final names = _memberNames(
          snapshot.members,
          scenario.participantIds,
        ).join(', ');
        summary =
            'Adding $names changes who is expected in ${original.title}, '
            'but it does not change the recorded ${_statusLabel(currentStatus)} '
            'rhythm until future sessions actually happen.';
        if (direction == SimulationDirection.increasedRisk &&
            projectedConflicts != null &&
            projectedConflicts > 0) {
          summary = '$summary The simulated plan has $projectedConflicts '
              'recorded schedule conflict ${projectedConflicts == 1 ? 'match' : 'matches'}; '
              'review the time before adding them.';
        }
        assumptions.add(
          'The selected member is added to the simulated plan only.',
        );
        break;

      case TwinSimulationType.removeParticipant:
        projectedStatus = currentStatus;
        direction = SimulationDirection.unknown;
        final names = _memberNames(
          snapshot.members,
          scenario.participantIds,
        ).join(', ');
        summary =
            'Removing $names changes the expected group for ${original.title}. '
            'The real rhythm remains ${_statusLabel(currentStatus)} because '
            'no recorded occurrence has changed.';
        assumptions.add('Historical participation records remain untouched.');
        break;

      case TwinSimulationType.createMoment:
        throw StateError('New Moment patterns use a separate path.');
    }

    final remainsEarlyLearning =
        currentStatus == RhythmStatus.stillLearning &&
        projectedStatus == RhythmStatus.stillLearning;
    final isPositiveScheduleTrial =
        direction == SimulationDirection.improving &&
        (scenario.type == TwinSimulationType.changeFrequency
            ? (projectedConflicts ?? 0) == 0
            : scenario.changesSchedule && projectedConflicts == 0);
    final isPositiveEarlyTrial =
        remainsEarlyLearning &&
        (scenario.type == TwinSimulationType.assumeNextCompleted ||
            scenario.type == TwinSimulationType.assumeParticipantJoins ||
            (scenario.type == TwinSimulationType.addParticipant &&
                direction != SimulationDirection.increasedRisk &&
                (projectedConflicts ?? 0) == 0) ||
            isPositiveScheduleTrial);

    if (remainsEarlyLearning &&
        scenario.type == TwinSimulationType.assumeNextMissed) {
      summary = 'Missing the next ${original.title} would add no completed '
          'evidence, so the rhythm would remain Still Learning.';
    } else if (isPositiveEarlyTrial) {
      final nextStep = scenario.type == TwinSimulationType.addParticipant
          ? projectedScheduleCoverageComplete
                ? 'Including the added member could make this a more shared Moment. '
                      'Try the next real occurrence and record what happened.'
                : 'Including the added member could make this a more shared Moment. '
                      'Confirm that they are free at this time, then try the next '
                      'real occurrence and record what happened.'
          : frequencyUsesRecordedCadence
          ? projectedConflicts == null
                ? 'The new frequency better matches the recorded cadence. '
                      'Confirm the time with your family, then try the next '
                      'real occurrence and record what happened.'
                : projectedConflicts != null &&
                    currentConflicts != null &&
                    projectedConflicts > currentConflicts
                ? 'The new frequency better matches the recorded cadence, but '
                      'it creates more recorded schedule conflicts. Review the '
                      'timing before trying it.'
                : 'The new frequency better matches the recorded cadence. Try '
                      'the next real occurrence and record what happened.'
          : scenario.changesSchedule
          ? projectedScheduleCoverageComplete
                ? 'The adjusted plan has no recorded busy-time conflicts. Try '
                      'the next real occurrence and record what happened.'
                : 'The adjusted plan has no conflicts in the available schedules. '
                      'Confirm the time with the family, then try the next real '
                      'occurrence and record what happened.'
          : 'Completing and recording the next real occurrence will help '
                'Sakan learn whether this Moment fits your family.';
      summary = '${_momentBenefit(simulated)} $nextStep';
    }

    return SimulatedMomentPattern(
      momentId: original.id,
      currentStatus: currentStatus,
      projectedStatus: projectedStatus,
      direction: direction,
      summary: summary,
      changes: changes,
      assumptions: assumptions,
      confidence: _confidenceFor(
        rhythm: rhythm,
        availability: snapshot.availability,
        participantIds: simulated.expectedParticipantIds,
        scenario: scenario,
      ),
      currentParticipantCount: original.expectedParticipantIds.length,
      projectedParticipantCount: simulated.expectedParticipantIds.length,
      currentConflictCount: currentConflicts,
      projectedConflictCount: projectedConflicts,
      projectedScheduleCoverageComplete:
          projectedScheduleCoverageComplete,
      isAffected: true,
    );
  }

  List<String> _changesForScenario({
    required FamilyInsightReport baseReport,
    required FamilyMoment original,
    required FamilyMoment simulated,
    required TwinSimulationScenario scenario,
  }) {
    final snapshot = baseReport.snapshot;

    return switch (scenario.type) {
      TwinSimulationType.addParticipant => <String>[
        'Expected participants: ${original.expectedParticipantIds.length} → '
            '${simulated.expectedParticipantIds.length}',
        'Added ${_memberNames(snapshot.members, scenario.participantIds).join(', ')}',
        'Scope: ${scenario.scope.label}',
      ],
      TwinSimulationType.removeParticipant => <String>[
        'Expected participants: ${original.expectedParticipantIds.length} → '
            '${simulated.expectedParticipantIds.length}',
        'Removed ${_memberNames(snapshot.members, scenario.participantIds).join(', ')}',
        'Scope: ${scenario.scope.label}',
      ],
      TwinSimulationType.changeTime => <String>[
        'Usual time: ${_formatMinutes(original.resolvedPreferredStartMinutes)} → '
            '${_formatMinutes(simulated.resolvedPreferredStartMinutes)}',
        'Scope: ${scenario.scope.label}',
      ],
      TwinSimulationType.changeWeekday => <String>[
        'Usual day: ${_weekdayLabel(original.preferredWeekday ?? original.startAt.toLocal().weekday)} → '
            '${_weekdayLabel(simulated.preferredWeekday ?? simulated.startAt.toLocal().weekday)}',
        'Scope: ${scenario.scope.label}',
      ],
      TwinSimulationType.changeDayOfMonth => <String>[
        'Usual day of month: '
            '${original.preferredDayOfMonth ?? original.startAt.toLocal().day} → '
            '${simulated.preferredDayOfMonth ?? simulated.startAt.toLocal().day}',
        'Scope: ${scenario.scope.label}',
      ],
      TwinSimulationType.changeFrequency => <String>[
        'Frequency: ${_frequencyLabel(original.expectedIntervalDays)} → '
            '${_frequencyLabel(simulated.expectedIntervalDays)}',
        'Scope: ${scenario.scope.label}',
      ],
      TwinSimulationType.assumeNextCompleted => <String>[
        'Hypothetical next outcome: Completed',
        'Assumed duration: '
            '${scenario.assumedDurationMinutes ?? defaultDurationMinutes} min',
      ],
      TwinSimulationType.assumeNextMissed => const <String>[
        'Hypothetical next outcome: Missed',
      ],
      TwinSimulationType.assumeParticipantJoins => <String>[
        'Assumed participant: '
            '${_memberNames(snapshot.members, scenario.participantIds).join(', ')}',
        'Hypothetical next outcome: Completed',
      ],
      TwinSimulationType.createMoment => const <String>[],
    };
  }

  _ScheduleComparison _compareSchedules({
    required FamilyInsightReport baseReport,
    required FamilyMoment currentMoment,
    required FamilyMoment simulatedMoment,
  }) {
    final current = _projectSchedule(
      baseReport: baseReport,
      moment: currentMoment,
    );
    final projected = _projectSchedule(
      baseReport: baseReport,
      moment: simulatedMoment,
    );

    final currentConflicts = current.conflictCount;
    final projectedConflicts = projected.conflictCount;

    if (currentConflicts == null || projectedConflicts == null) {
      return _ScheduleComparison(
        currentConflictCount: currentConflicts,
        projectedConflictCount: projectedConflicts,
        direction: SimulationDirection.unknown,
        projectedScheduleCoverageComplete: projected.hasCompleteCoverage,
      );
    }

    final direction = projectedConflicts < currentConflicts
        ? SimulationDirection.improving
        : projectedConflicts > currentConflicts
        ? SimulationDirection.increasedRisk
        : SimulationDirection.unchanged;

    return _ScheduleComparison(
      currentConflictCount: currentConflicts,
      projectedConflictCount: projectedConflicts,
      direction: direction,
      projectedScheduleCoverageComplete: projected.hasCompleteCoverage,
    );
  }

  _ScheduleProjection _projectSchedule({
    required FamilyInsightReport baseReport,
    required FamilyMoment moment,
    int count = projectionHorizon,
  }) {
    final snapshot = baseReport.snapshot;
    final participantIds = moment.expectedParticipantIds.toSet();
    final activeBlocks = snapshot.availability
        .where((block) {
          return participantIds.contains(block.memberId) &&
              !block.isExpiredAt(snapshot.generatedAt);
        })
        .toList(growable: false);

    final coveredMembers = activeBlocks.map((block) => block.memberId).toSet();
    final starts = _projectedStarts(
      baseReport: baseReport,
      moment: moment,
      count: count,
    );

    if (starts.isEmpty || coveredMembers.isEmpty) {
      return const _ScheduleProjection(conflictCount: null);
    }

    final duration = _plannedDurationMinutes(moment) ?? defaultDurationMinutes;
    var conflicts = 0;

    for (final start in starts) {
      final end = start.add(Duration(minutes: duration));

      for (final memberId in participantIds) {
        final memberHasConflict = activeBlocks.any((block) {
          if (block.memberId != memberId) {
            return false;
          }

          return _availabilityBlockOverlaps(
            block: block,
            start: start,
            end: end,
          );
        });

        if (memberHasConflict) {
          conflicts++;
        }
      }
    }

    return _ScheduleProjection(
      conflictCount: conflicts,
      hasCompleteCoverage: coveredMembers.containsAll(participantIds),
    );
  }

  bool _availabilityBlockOverlaps({
    required AvailabilityBlock block,
    required DateTime start,
    required DateTime end,
  }) {
    final startDate = _dateOnly(start);
    final endDate = _dateOnly(end);
    final blockDates = <DateTime>[
      startDate.subtract(const Duration(days: 1)),
      startDate,
      if (endDate != startDate) endDate,
    ];

    for (final blockDate in blockDates) {
      if (!block.occursOn(blockDate)) {
        continue;
      }

      final busyStart = blockDate.add(Duration(minutes: block.startMinutes));
      var busyEnd = blockDate.add(Duration(minutes: block.endMinutes));
      if (!busyEnd.isAfter(busyStart)) {
        busyEnd = busyEnd.add(const Duration(days: 1));
      }

      if (start.isBefore(busyEnd) && end.isAfter(busyStart)) {
        return true;
      }
    }

    return false;
  }

  List<DateTime> _projectedStarts({
    required FamilyInsightReport baseReport,
    required FamilyMoment moment,
    required int count,
  }) {
    if (count <= 0) {
      return const <DateTime>[];
    }

    final reference = baseReport.snapshot.generatedAt.toLocal();
    final result = <DateTime>[];

    DateTime? first;

    if (moment.isDayFlexible) {
      final sharedWindow = baseReport.bestSharedWindow?.startAt;
      first = sharedWindow != null && sharedWindow.isAfter(reference)
          ? _atMinutes(sharedWindow, moment.resolvedPreferredStartMinutes)
          : MomentScheduleResolver.anchorForFlexible(
              reference: reference.add(const Duration(days: 1)),
              startMinutes: moment.resolvedPreferredStartMinutes,
            );
    } else {
      first = MomentScheduleResolver.firstExactStart(
        type: MomentType.recurring,
        reference: reference,
        startMinutes: moment.resolvedPreferredStartMinutes,
        intervalDays: moment.expectedIntervalDays ?? 7,
        isDayFlexible: false,
        preferredWeekday: moment.preferredWeekday,
        preferredDayOfMonth: moment.preferredDayOfMonth,
        preferredMonth: moment.preferredMonth,
      );
    }

    if (first == null) {
      return const <DateTime>[];
    }

    result.add(first);

    while (result.length < count) {
      final previous = result.last;
      final next = moment.isDayFlexible
          ? _advanceFlexible(previous, moment.expectedIntervalDays ?? 7)
          : MomentScheduleResolver.nextExactStart(
              moment: moment,
              after: previous,
              now: reference,
            );

      if (next == null || !next.isAfter(previous)) {
        break;
      }

      result.add(next);
    }

    return result;
  }

  DateTime _advanceFlexible(DateTime previous, int intervalDays) {
    return switch (intervalDays) {
      30 => _addMonths(previous, 1),
      90 => _addMonths(previous, 3),
      365 => DateTime(
        previous.year + 1,
        previous.month,
        previous.day
            .clamp(
              1,
              MomentScheduleResolver.daysInMonth(
                previous.year + 1,
                previous.month,
              ),
            )
            .toInt(),
        previous.hour,
        previous.minute,
      ),
      _ => previous.add(Duration(days: intervalDays <= 0 ? 1 : intervalDays)),
    };
  }

  DateTime _addMonths(DateTime value, int months) {
    final zeroBased = value.month - 1 + months;
    final year = value.year + zeroBased ~/ 12;
    final month = zeroBased % 12 + 1;
    final day = value.day
        .clamp(1, MomentScheduleResolver.daysInMonth(year, month))
        .toInt();

    return DateTime(year, month, day, value.hour, value.minute);
  }

  RhythmStatus _statusAfterCompleted({
    required RhythmStatus currentStatus,
    required int occurrenceCount,
  }) {
    return switch (currentStatus) {
      RhythmStatus.stillLearning =>
        occurrenceCount + 1 >= 3
            ? RhythmStatus.stable
            : RhythmStatus.stillLearning,
      RhythmStatus.drifting => RhythmStatus.recovering,
      RhythmStatus.recovering => RhythmStatus.stable,
      RhythmStatus.stable => RhythmStatus.strengthening,
      RhythmStatus.strengthening => RhythmStatus.strengthening,
    };
  }

  RhythmStatus _statusAfterMissed(RhythmStatus currentStatus) {
    return switch (currentStatus) {
      RhythmStatus.stillLearning => RhythmStatus.stillLearning,
      RhythmStatus.drifting => RhythmStatus.drifting,
      RhythmStatus.recovering ||
      RhythmStatus.stable ||
      RhythmStatus.strengthening => RhythmStatus.drifting,
    };
  }

  RhythmStatus _statusAfterPlanChange({
    required RhythmStatus currentStatus,
    required SimulationDirection direction,
    required TwinSimulationScope scope,
  }) {
    if (scope == TwinSimulationScope.nextOccurrence) {
      return currentStatus;
    }

    return switch (direction) {
      SimulationDirection.improving => switch (currentStatus) {
        RhythmStatus.drifting => RhythmStatus.recovering,
        RhythmStatus.recovering => RhythmStatus.stable,
        _ => currentStatus,
      },
      SimulationDirection.increasedRisk => switch (currentStatus) {
        RhythmStatus.stable ||
        RhythmStatus.recovering ||
        RhythmStatus.strengthening => RhythmStatus.drifting,
        _ => currentStatus,
      },
      SimulationDirection.unchanged ||
      SimulationDirection.unknown => currentStatus,
    };
  }

  SimulationDirection _frequencyDirection({
    required int? observedGapDays,
    required int? currentIntervalDays,
    required int? projectedIntervalDays,
    required SimulationDirection fallback,
  }) {
    if (observedGapDays == null ||
        currentIntervalDays == null ||
        projectedIntervalDays == null) {
      return fallback;
    }

    final currentDistance = (observedGapDays - currentIntervalDays).abs();
    final projectedDistance = (observedGapDays - projectedIntervalDays).abs();

    if (projectedDistance < currentDistance) {
      return SimulationDirection.improving;
    }

    if (projectedDistance > currentDistance) {
      return SimulationDirection.increasedRisk;
    }

    return fallback == SimulationDirection.unknown
        ? SimulationDirection.unchanged
        : fallback;
  }

  int? _medianCompletedGap(List<MomentInstance> instances) {
    final completed = _completedInstances(instances)
      ..sort(
        (first, second) =>
            first.effectiveStartAt.compareTo(second.effectiveStartAt),
      );

    if (completed.length < 2) {
      return null;
    }

    final gaps = <int>[];

    for (var index = 1; index < completed.length; index++) {
      final previous = _dateOnly(
        completed[index - 1].effectiveStartAt.toLocal(),
      );
      final current = _dateOnly(completed[index].effectiveStartAt.toLocal());
      final gap = current.difference(previous).inDays;

      if (gap > 0) {
        gaps.add(gap);
      }
    }

    if (gaps.isEmpty) {
      return null;
    }

    gaps.sort();
    return gaps[gaps.length ~/ 2];
  }

  List<MomentInstance> _completedInstances(List<MomentInstance> instances) {
    return instances
        .where((item) => item.status == MomentInstanceStatus.completed)
        .toList();
  }

  ConfidenceLevel _confidenceFor({
    required RhythmRecord? rhythm,
    required List<AvailabilityBlock> availability,
    required List<String> participantIds,
    required TwinSimulationScenario scenario,
  }) {
    if (scenario.createsMoment ||
        rhythm == null ||
        rhythm.occurrenceCount < 2) {
      return ConfidenceLevel.low;
    }

    if (scenario.changesSchedule) {
      final covered = availability
          .map((block) => block.memberId)
          .toSet()
          .intersection(participantIds.toSet())
          .length;

      if (covered < participantIds.length) {
        return ConfidenceLevel.low;
      }
    }

    return rhythm.confidence == ConfidenceLevel.low
        ? ConfidenceLevel.low
        : ConfidenceLevel.medium;
  }

  String _scheduleSummary({
    required String title,
    required SimulationDirection direction,
    required int? currentConflicts,
    required int? projectedConflicts,
  }) {
    if (currentConflicts == null || projectedConflicts == null) {
      return '$title changes in the simulated map, but Sakan does not have '
          'enough recorded schedule coverage to estimate whether the new plan '
          'is easier to maintain.';
    }

    final directionText = switch (direction) {
      SimulationDirection.improving =>
        'The simulated plan has fewer recorded conflicts.',
      SimulationDirection.increasedRisk =>
        'The simulated plan has more recorded conflicts.',
      SimulationDirection.unchanged =>
        'The simulated plan has the same number of recorded conflicts.',
      SimulationDirection.unknown =>
        'The schedule effect cannot be determined from the recorded data.',
    };

    return 'Across the next $projectionHorizon projected occurrences, '
        'member-conflict matches change from $currentConflicts to '
        '$projectedConflicts. $directionText';
  }

  String _familySummary({
    required FamilyMoment moment,
    required SimulatedMomentPattern pattern,
    required TwinSimulationScenario scenario,
  }) {
    if (pattern.isHypothetical) {
      final evidenceNote = scenario.scope == TwinSimulationScope.nextOccurrence
          ? 'This is one planned experience rather than a recurring rhythm.'
          : 'Because it is new, it begins as Still Learning until real outcomes are recorded.';
      if ((pattern.projectedConflictCount ?? 0) > 0) {
        return 'This time has ${pattern.projectedConflictCount} recorded schedule '
            '${pattern.projectedConflictCount == 1 ? 'conflict' : 'conflicts'}. '
            '${_momentBenefit(
              moment,
              isOneTime: scenario.scope == TwinSimulationScope.nextOccurrence,
            )} $evidenceNote Choose a clear time, then add it as a Moment.';
      }
      return '${_momentBenefit(
        moment,
        isOneTime: scenario.scope == TwinSimulationScope.nextOccurrence,
      )} $evidenceNote '
          '${_newMomentRecommendation(
            conflictCount: pattern.projectedConflictCount,
            hasCompleteCoverage:
                pattern.projectedScheduleCoverageComplete,
          )}';
    }

    final remainsEarlyLearning =
        pattern.currentStatus == RhythmStatus.stillLearning &&
        pattern.projectedStatus == RhythmStatus.stillLearning;
    final isPositiveScheduleTrial =
        pattern.direction == SimulationDirection.improving &&
        (scenario.type == TwinSimulationType.changeFrequency
            ? (pattern.projectedConflictCount ?? 0) == 0
            : scenario.changesSchedule &&
                  pattern.projectedConflictCount == 0);
    final isPositiveEarlyTrial =
        remainsEarlyLearning &&
        (scenario.type == TwinSimulationType.assumeNextCompleted ||
            scenario.type == TwinSimulationType.assumeParticipantJoins ||
            (scenario.type == TwinSimulationType.addParticipant &&
                pattern.direction != SimulationDirection.increasedRisk &&
                (pattern.projectedConflictCount ?? 0) == 0) ||
            isPositiveScheduleTrial);
    if (remainsEarlyLearning &&
        scenario.type == TwinSimulationType.assumeNextMissed) {
      return pattern.summary;
    }

    if (isPositiveEarlyTrial) {
      return '${pattern.summary} The Still Learning label only means that '
          'more real outcomes are needed; it does not remove this potential benefit.';
    }

    if (pattern.statusChanged) {
      return 'This scenario changes ${moment.title} from '
          '${_statusLabel(pattern.currentStatus)} to '
          'Projected ${_statusLabel(pattern.projectedStatus)}. '
          'The change is a projection based on the stated assumptions, not a '
          'saved family outcome.';
    }

    if (scenario.changesParticipants) {
      return 'The family map changes who is connected to ${moment.title}, '
          'while its recorded ${_statusLabel(pattern.currentStatus)} status '
          'remains unchanged.';
    }

    return '${moment.title} keeps its recorded '
        '${_statusLabel(pattern.currentStatus)} status. '
        '${pattern.summary}';
  }

  String _newMomentRecommendation({
    required int? conflictCount,
    required bool hasCompleteCoverage,
  }) {
    if ((conflictCount ?? 0) > 0) {
      return 'Choose a time without the recorded conflict before adding it.';
    }

    if (!hasCompleteCoverage) {
      return 'Review the time with the family, then add it as a Moment if it works.';
    }

    return 'No recorded conflicts were found, so this is worth trying as a Moment.';
  }

  String _momentBenefit(FamilyMoment moment, {bool isOneTime = false}) {
    final title = moment.title.toLowerCase();
    final hasFamilyGroup = moment.expectedParticipantIds.length > 1;

    if (!hasFamilyGroup) {
      return 'Planning ${moment.title} could make the next step clearer and '
          'easier to coordinate.';
    }

    if (_containsAny(title, const <String>[
      'picnic',
      'park',
      'outdoor',
      'نزه',
      'حديقة',
    ])) {
      return 'A shared outing could give the family unhurried time away from '
          'routines, with room to talk and enjoy an activity together.';
    }

    if (_containsAny(title, const <String>['walk', 'مشي'])) {
      return 'A family walk could add relaxed time together and make '
          'conversation easier alongside a simple shared activity.';
    }

    if (_containsAny(title, const <String>[
      'lunch',
      'dinner',
      'breakfast',
      'meal',
      'brunch',
      'غداء',
      'عشاء',
      'فطور',
      'وجبة',
    ])) {
      return 'A shared meal could create an easy family check-in and time to '
          'reconnect without needing a complicated activity.';
    }

    if (_containsAny(title, const <String>[
      'movie',
      'film',
      'cinema',
      'game night',
      'فيلم',
      'سينما',
      'ألعاب',
    ])) {
      return 'This could offer low-effort shared downtime and give the family '
          'an experience to enjoy together.';
    }

    if (_containsAny(title, const <String>['birthday', 'ميلاد'])) {
      return 'This could help the family mark the birthday while giving each '
          'member a simple way to contribute.';
    }

    if (_containsAny(title, const <String>[
      'graduation',
      'graduate',
      'تخرج',
    ])) {
      return 'This could help recognize the person’s achievement and create '
          'a milestone the family can share together.';
    }

    if (_containsAny(title, const <String>[
      'appointment',
      'doctor',
      'clinic',
      'hospital',
      'موعد',
      'طبيب',
      'عيادة',
      'مستشفى',
    ])) {
      return 'Adding this appointment could make preparation, travel, and '
          'family support easier to coordinate.';
    }

    return switch (moment.category) {
      MomentCategory.familyTime =>
        'Protecting this time could give the family more space to talk, '
            'relax, and be present together.',
      MomentCategory.tradition =>
        isOneTime
        ? 'Sharing this tradition once could give the family a familiar point '
              'of connection on this occasion.'
        : 'Repeating this tradition could give the family a familiar point of '
              'connection to look forward to.',
      MomentCategory.milestone =>
        'Planning this milestone could help the family recognize it together '
            'and make the occasion more intentional.',
      MomentCategory.responsibility =>
        'Planning this could make responsibilities clearer and reduce '
            'last-minute pressure for the family.',
      MomentCategory.care =>
        'Planning this care Moment could make support easier to coordinate '
            'and clarify how family members can help.',
      MomentCategory.memory =>
        'Making time for this could give the family a shared experience worth '
            'remembering and discussing later.',
    };
  }

  bool _containsAny(String value, List<String> terms) {
    return terms.any((term) => value.contains(term));
  }

  String _scenarioTitle({
    required FamilyInsightReport baseReport,
    required FamilyMoment moment,
    required TwinSimulationScenario scenario,
  }) {
    final memberNames = _memberNames(
      baseReport.snapshot.members,
      scenario.participantIds,
    ).join(', ');

    return switch (scenario.type) {
      TwinSimulationType.addParticipant =>
        'What if $memberNames was added to ${moment.title}?',
      TwinSimulationType.removeParticipant =>
        'What if $memberNames was removed from ${moment.title}?',
      TwinSimulationType.changeTime =>
        'What if ${moment.title} moved to ${_formatMinutes(scenario.newStartMinutes!)}?',
      TwinSimulationType.changeWeekday =>
        'What if ${moment.title} moved to ${_weekdayLabel(scenario.newWeekday!)}?',
      TwinSimulationType.changeDayOfMonth =>
        'What if ${moment.title} moved to day ${scenario.newDayOfMonth}?',
      TwinSimulationType.changeFrequency =>
        'What if ${moment.title} became ${_frequencyLabel(scenario.newIntervalDays!)}?',
      TwinSimulationType.assumeNextCompleted =>
        'What if the next ${moment.title} happened?',
      TwinSimulationType.assumeNextMissed =>
        'What if the next ${moment.title} was missed?',
      TwinSimulationType.assumeParticipantJoins =>
        'What if $memberNames joined the next ${moment.title}?',
      TwinSimulationType.createMoment =>
        'What if your family added ${scenario.newTitle}?',
    };
  }

  String _scenarioSubtitle({
    required FamilyMoment moment,
    required TwinSimulationScenario scenario,
  }) {
    if (scenario.isOutcomeAssumption) {
      return 'One hypothetical next occurrence';
    }

    return '${moment.title} · ${scenario.scope.label}';
  }

  List<String> _memberNames(List<Member> members, List<String> ids) {
    final byId = <String, String>{
      for (final member in members) member.id: member.displayName,
    };

    final result = ids.map((id) => byId[id] ?? 'Selected member').toList();
    result.sort();
    return result;
  }

  List<String> _sortedUnique(Iterable<String> values) {
    final result = values
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList();
    result.sort();
    return result;
  }

  int? _plannedDurationMinutes(FamilyMoment moment) {
    final start = moment.startAt.toLocal();
    final end = moment.endAt?.toLocal();

    if (end != null && end.isAfter(start)) {
      return end.difference(start).inMinutes;
    }

    final startMinutes = moment.resolvedPreferredStartMinutes;
    final endMinutes = moment.resolvedPreferredEndMinutes;

    if (endMinutes == null) {
      return null;
    }

    var duration = endMinutes - startMinutes;

    if (duration <= 0) {
      duration += 24 * 60;
    }

    return duration;
  }

  DateTime _atMinutes(DateTime date, int minutes) {
    final safe = minutes.clamp(0, 1439).toInt();
    return DateTime(date.year, date.month, date.day, safe ~/ 60, safe % 60);
  }

  int _minuteOfDay(DateTime value) {
    final local = value.toLocal();
    return local.hour * 60 + local.minute;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatMinutes(int minutes) {
    final safe = minutes.clamp(0, 1439).toInt();
    return DateFormat(
      'h:mm a',
    ).format(DateTime(2026, 1, 1, safe ~/ 60, safe % 60));
  }

  String _weekdayLabel(int weekday) {
    final monday = DateTime(2026, 1, 5);
    return DateFormat.EEEE().format(
      monday.add(Duration(days: weekday.clamp(1, 7).toInt() - 1)),
    );
  }

  String _frequencyLabel(int? days) {
    return switch (days) {
      null => 'Unconfigured',
      1 => 'Daily',
      7 => 'Weekly',
      14 => 'Every 2 weeks',
      30 => 'Monthly',
      90 => 'Every 3 months',
      365 => 'Yearly',
      _ => 'Every $days days',
    };
  }

  String _categoryLabel(MomentCategory category) {
    return switch (category) {
      MomentCategory.tradition => 'Tradition',
      MomentCategory.milestone => 'Milestone',
      MomentCategory.responsibility => 'Responsibility',
      MomentCategory.care => 'Care Moment',
      MomentCategory.familyTime => 'Family Time Moment',
      MomentCategory.memory => 'Memory Moment',
    };
  }

  String _statusLabel(RhythmStatus status) {
    return switch (status) {
      RhythmStatus.stillLearning => 'Still Learning',
      RhythmStatus.stable => 'Stable',
      RhythmStatus.drifting => 'Drifting',
      RhythmStatus.recovering => 'Recovering',
      RhythmStatus.strengthening => 'Strengthening',
    };
  }

  String _confidenceLabel(ConfidenceLevel confidence) {
    return switch (confidence) {
      ConfidenceLevel.low => 'Low-confidence',
      ConfidenceLevel.medium => 'Medium-confidence',
      ConfidenceLevel.high => 'High-confidence',
    };
  }
}

class _ScheduleProjection {
  const _ScheduleProjection({
    required this.conflictCount,
    this.hasCompleteCoverage = false,
  });

  final int? conflictCount;
  final bool hasCompleteCoverage;
}

class _ScheduleComparison {
  const _ScheduleComparison({
    required this.currentConflictCount,
    required this.projectedConflictCount,
    required this.direction,
    this.projectedScheduleCoverageComplete = false,
  });

  final int? currentConflictCount;
  final int? projectedConflictCount;
  final SimulationDirection direction;
  final bool projectedScheduleCoverageComplete;
}
