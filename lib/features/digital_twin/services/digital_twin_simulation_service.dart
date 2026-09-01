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
        moment: affectedMoment,
        scenario: scenario,
      );

      scenarioTitle = 'What if your family added ${affectedMoment.title}?';
      scenarioSubtitle =
          '${_frequencyLabel(affectedMoment.expectedIntervalDays)} · '
          '${affectedMoment.expectedParticipantIds.length} expected '
          '${affectedMoment.expectedParticipantIds.length == 1 ? 'participant' : 'participants'}';
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
      if (!scenario.isOutcomeAssumption)
        'Schedule comparisons use the next $projectionHorizon projected occurrences.',
      ...affectedPattern.assumptions,
      'Sakan does not predict relationship quality, emotions, or whether people will actually attend.',
    }.toList(growable: false);

    final familySummary = _familySummary(
      moment: affectedMoment,
      pattern: affectedPattern,
      scenario: scenario,
    );

    final themes = <String>[
      scenario.type.label,
      if (affectedPattern.statusChanged)
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
    required FamilyMoment moment,
    required TwinSimulationScenario scenario,
  }) {
    return SimulatedMomentPattern(
      momentId: moment.id,
      currentStatus: RhythmStatus.stillLearning,
      projectedStatus: RhythmStatus.stillLearning,
      direction: SimulationDirection.unknown,
      summary:
          '${moment.title} would appear as a new Still Learning pattern. '
          'Sakan cannot project a stronger rhythm until real occurrences are recorded.',
      changes: <String>[
        'New recurring ${_categoryLabel(moment.category)}',
        '${_frequencyLabel(moment.expectedIntervalDays)} at '
            '${_formatMinutes(moment.resolvedPreferredStartMinutes)}',
        '${moment.expectedParticipantIds.length} expected '
            '${moment.expectedParticipantIds.length == 1 ? 'participant' : 'participants'}',
      ],
      assumptions: const <String>[
        'The new Moment has no completed or missed history.',
        'Its first projected state is Still Learning.',
      ],
      confidence: ConfidenceLevel.low,
      currentParticipantCount: 0,
      projectedParticipantCount: moment.expectedParticipantIds.length,
      isHypothetical: true,
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

        final observedGap = _medianCompletedGap(instances);
        direction = _frequencyDirection(
          observedGapDays: observedGap,
          currentIntervalDays: original.expectedIntervalDays,
          projectedIntervalDays: simulated.expectedIntervalDays,
          fallback: comparison.direction,
        );

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
        direction = SimulationDirection.unknown;
        final names = _memberNames(
          snapshot.members,
          scenario.participantIds,
        ).join(', ');
        summary =
            'Adding $names changes who is expected in ${original.title}, '
            'but it does not change the recorded ${_statusLabel(currentStatus)} '
            'rhythm until future sessions actually happen.';
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
    );
  }

  _ScheduleProjection _projectSchedule({
    required FamilyInsightReport baseReport,
    required FamilyMoment moment,
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
      count: projectionHorizon,
    );

    if (starts.isEmpty || coveredMembers.isEmpty) {
      return const _ScheduleProjection(conflictCount: null);
    }

    final duration = _plannedDurationMinutes(moment) ?? defaultDurationMinutes;
    var conflicts = 0;

    for (final start in starts) {
      final startMinutes = _minuteOfDay(start);
      final endMinutes = startMinutes + duration;

      for (final memberId in participantIds) {
        final memberHasConflict = activeBlocks.any((block) {
          if (block.memberId != memberId || !block.occursOn(start)) {
            return false;
          }

          return startMinutes < block.endMinutes &&
              endMinutes > block.startMinutes;
        });

        if (memberHasConflict) {
          conflicts++;
        }
      }
    }

    return _ScheduleProjection(conflictCount: conflicts);
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
      return '${moment.title} would be added to the map as a hypothetical '
          'Still Learning Moment. The family view gains new connections, but '
          'no real rhythm exists until the family records actual outcomes.';
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
  const _ScheduleProjection({required this.conflictCount});

  final int? conflictCount;
}

class _ScheduleComparison {
  const _ScheduleComparison({
    required this.currentConflictCount,
    required this.projectedConflictCount,
    required this.direction,
  });

  final int? currentConflictCount;
  final int? projectedConflictCount;
  final SimulationDirection direction;
}
