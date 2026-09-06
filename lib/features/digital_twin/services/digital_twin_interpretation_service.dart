import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/models/rhythm_record.dart';
import '../domain/digital_twin_interpretation.dart';

class DigitalTwinInterpretationService {
  const DigitalTwinInterpretationService();

  MomentTwinInterpretation interpretMoment({
    required FamilyMoment moment,
    required RhythmRecord? rhythm,
    required List<MomentInstance> instances,
  }) {
    final completed =
        instances
            .where(
              (instance) => instance.status == MomentInstanceStatus.completed,
            )
            .toList()
          ..sort(
            (first, second) =>
                second.effectiveStartAt.compareTo(first.effectiveStartAt),
          );

    final missedCount = instances
        .where((instance) => instance.status == MomentInstanceStatus.missed)
        .length;

    final participation = _averageParticipationRatio(completed);
    final averageDuration = _averageDurationMinutes(completed);
    final status = rhythm?.status ?? RhythmStatus.stillLearning;

    final summary = switch (status) {
      RhythmStatus.stillLearning => _stillLearningSummary(
        moment: moment,
        completedCount: completed.length,
      ),
      RhythmStatus.stable => _stableSummary(
        moment: moment,
        participation: participation,
      ),
      RhythmStatus.drifting => _driftingSummary(
        moment: moment,
        participation: participation,
        missedCount: missedCount,
      ),
      RhythmStatus.recovering => _recoveringSummary(
        moment: moment,
        participation: participation,
      ),
      RhythmStatus.strengthening => _strengtheningSummary(
        moment: moment,
        participation: participation,
      ),
    };

    final themes = <String>[
      switch (status) {
        RhythmStatus.stillLearning => 'More history is needed',
        RhythmStatus.stable => 'Timing is dependable',
        RhythmStatus.drifting => 'Timing needs consistency',
        RhythmStatus.recovering => 'The rhythm is returning',
        RhythmStatus.strengthening => 'The rhythm is strengthening',
      },
    ];

    if (participation != null) {
      if (participation >= 0.75) {
        themes.add('Participation remains strong');
      } else if (participation < 0.5) {
        themes.add('Participation varies');
      }
    }

    if (missedCount > 0) {
      themes.add(
        '$missedCount missed '
        '${missedCount == 1 ? 'occurrence' : 'occurrences'}',
      );
    } else if (averageDuration != null) {
      themes.add('Sessions average $averageDuration min');
    }

    return MomentTwinInterpretation(
      summary: summary,
      themes: List<String>.unmodifiable(themes.take(3)),
      origin: DigitalTwinInterpretationOrigin.ruleBasedFallback,
    );
  }

  FamilyTwinInterpretation interpretFamily({
    required List<FamilyMoment> moments,
    required List<RhythmRecord> rhythms,
    required List<MomentInstance> instances,
    DateTime? referenceDate,
  }) {
    final recurringMoments = moments
        .where((moment) => moment.type == MomentType.recurring)
        .toList(growable: false);

    final rhythmByMomentId = <String, RhythmRecord>{
      for (final rhythm in rhythms) rhythm.momentId: rhythm,
    };

    int countStatus(RhythmStatus status) {
      return recurringMoments.where((moment) {
        return (rhythmByMomentId[moment.id]?.status ??
                RhythmStatus.stillLearning) ==
            status;
      }).length;
    }

    final dependableCount =
        countStatus(RhythmStatus.stable) +
        countStatus(RhythmStatus.strengthening);
    final driftingCount = countStatus(RhythmStatus.drifting);
    final recent = _rollingWeekInstances(
      instances,
      referenceDate ?? DateTime.now(),
    );
    final completed = recent
        .where((item) => item.status == MomentInstanceStatus.completed)
        .toList(growable: false);
    final completedCount = completed.length;
    final missedCount = recent
        .where((item) => item.status == MomentInstanceStatus.missed)
        .length;
    final cancelledCount = recent
        .where((item) => item.status == MomentInstanceStatus.cancelled)
        .length;
    final unresolvedCount =
        recent.length - completedCount - missedCount - cancelledCount;
    final resolvedCount = completedCount + missedCount + cancelledCount;

    late String summary;
    late final String signal;

    if (recent.isEmpty) {
      if (driftingCount > 0) {
        summary =
            'The wider rhythm needs attention, but the last seven days have no recorded Moments to confirm whether that is continuing.';
        signal = 'This week needs a recorded outcome';
      } else if (dependableCount > 0) {
        summary =
            'The established rhythms look dependable, but this week needs a recorded outcome before Sakan can read its direction.';
        signal =
            '$dependableCount dependable ${dependableCount == 1 ? 'rhythm' : 'rhythms'} overall';
      } else {
        summary =
            'The family rhythm is still taking shape, and this week has too little recorded activity for a clear reading.';
        signal = 'More weekly evidence is needed';
      }
    } else if (resolvedCount == 0) {
      summary =
          '$unresolvedCount recent ${unresolvedCount == 1 ? 'Moment still needs' : 'Moments still need'} an outcome, so this week’s overall pattern is not clear yet.';
      signal = '$unresolvedCount recent outcomes still open';
    } else {
      if (completedCount == resolvedCount) {
        summary =
            'The recorded week looks steady: all $resolvedCount resolved ${resolvedCount == 1 ? 'Moment was' : 'Moments were'} completed.';
      } else if (completedCount * 2 > resolvedCount) {
        summary =
            'Most resolved Moments were completed this week, so the recorded family rhythm looks generally workable.';
      } else if (missedCount > 0) {
        summary =
            'This week looks less settled, with $completedCount completed and $missedCount missed ${missedCount == 1 ? 'Moment' : 'Moments'}.';
      } else {
        summary =
            'This week’s recorded outcomes are mixed, so another completed Moment would make the family rhythm clearer.';
      }

      if (unresolvedCount > 0) {
        summary +=
            ' $unresolvedCount other ${unresolvedCount == 1 ? 'Moment still needs' : 'Moments still need'} an outcome.';
        signal = '$unresolvedCount recent outcomes still open';
      } else if (missedCount > 0) {
        signal = '$missedCount missed this week';
      } else if (completedCount == resolvedCount) {
        signal = 'All resolved Moments were completed';
      } else {
        signal = 'Most resolved Moments were completed';
      }
    }

    return FamilyTwinInterpretation(
      summary: summary,
      themes: <String>[signal],
      origin: DigitalTwinInterpretationOrigin.ruleBasedFallback,
    );
  }

  Map<String, dynamic> buildMomentAiPayload({
    required FamilyMoment moment,
    required RhythmRecord? rhythm,
    required List<MomentInstance> instances,
    bool includeTitle = false,
  }) {
    final completed = instances
        .where((instance) => instance.status == MomentInstanceStatus.completed)
        .toList(growable: false);

    final missed = instances
        .where((instance) => instance.status == MomentInstanceStatus.missed)
        .toList(growable: false);

    final recent = List<MomentInstance>.from(instances)
      ..sort(
        (first, second) =>
            second.effectiveStartAt.compareTo(first.effectiveStartAt),
      );

    return <String, dynamic>{
      'title': includeTitle ? moment.title : null,
      'category': moment.category.name,
      'expectedIntervalDays':
          rhythm?.expectedIntervalDays ?? moment.expectedIntervalDays,
      'rhythmStatus': (rhythm?.status ?? RhythmStatus.stillLearning).name,
      'rhythmConfidence': (rhythm?.confidence ?? ConfidenceLevel.low).name,
      'currentGapDays': rhythm?.currentGapDays,
      'completedCount': completed.length,
      'missedCount': missed.length,
      'averageParticipationRatio': _averageParticipationRatio(completed),
      'averageDurationMinutes': _averageDurationMinutes(completed),
      'recentOutcomes': recent
          .take(5)
          .map(
            (instance) => <String, dynamic>{
              'status': instance.status.name,
              'scheduledAt': instance.scheduledStartAt.toIso8601String(),
              'actualDurationMinutes': instance.actualDurationMinutes,
              'expectedParticipantCount':
                  instance.expectedParticipantIds.length,
              'recordedParticipantCount':
                  instance.allRecordedParticipantIds.length,
              'confirmationLevel': instance.confirmationLevel.name,
              'evidenceSignals': instance.evidenceSignals
                  .map((item) => item.name)
                  .toList(),
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> buildFamilyAiPayload({
    required List<FamilyMoment> moments,
    required List<RhythmRecord> rhythms,
    required List<MomentInstance> instances,
    DateTime? referenceDate,
  }) {
    final recurring = moments
        .where((moment) => moment.type == MomentType.recurring)
        .toList(growable: false);

    final rhythmByMomentId = <String, RhythmRecord>{
      for (final rhythm in rhythms) rhythm.momentId: rhythm,
    };
    final endDate = _dateOnly((referenceDate ?? DateTime.now()).toLocal());
    final startDate = endDate.subtract(const Duration(days: 6));
    final recent = _rollingWeekInstances(instances, endDate);
    final completed = recent
        .where((item) => item.status == MomentInstanceStatus.completed)
        .toList(growable: false);
    final missedCount = recent
        .where((item) => item.status == MomentInstanceStatus.missed)
        .length;
    final cancelledCount = recent
        .where((item) => item.status == MomentInstanceStatus.cancelled)
        .length;
    final unresolvedCount =
        recent.length - completed.length - missedCount - cancelledCount;

    return <String, dynamic>{
      'narrativeContractVersion': 2,
      'window': <String, String>{
        'startDate': _dateKey(startDate),
        'endDate': _dateKey(endDate),
        'meaning': 'rollingSevenDaysIncludingToday',
      },
      'recurringMomentCount': recurring.length,
      'currentRhythmStatusCounts': <String, int>{
        for (final status in RhythmStatus.values)
          status.name: recurring.where((moment) {
            return (rhythmByMomentId[moment.id]?.status ??
                    RhythmStatus.stillLearning) ==
                status;
          }).length,
      },
      'rollingWeek': <String, dynamic>{
        'recordedCount': recent.length,
        'completedCount': completed.length,
        'missedCount': missedCount,
        'cancelledCount': cancelledCount,
        'unresolvedCount': unresolvedCount,
        'averageParticipationRatio': _averageParticipationRatio(completed),
        'categoryCounts': <String, int>{
          for (final category in MomentCategory.values)
            if (recent.any((item) => item.categorySnapshot == category))
              category.name: recent
                  .where((item) => item.categorySnapshot == category)
                  .length,
        },
      },
    };
  }

  List<MomentInstance> _rollingWeekInstances(
    List<MomentInstance> instances,
    DateTime referenceDate,
  ) {
    final endDate = _dateOnly(referenceDate.toLocal());
    final startDate = endDate.subtract(const Duration(days: 6));

    return instances.where((instance) {
      final date = _dateOnly(instance.scheduledStartAt.toLocal());
      return !date.isBefore(startDate) && !date.isAfter(endDate);
    }).toList(growable: false);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _stillLearningSummary({
    required FamilyMoment moment,
    required int completedCount,
  }) {
    if (completedCount == 0) {
      return 'Sakan does not yet have enough confirmed sessions to understand how ${moment.title} fits into your family routine. '
          'The next few recorded occurrences will make this pattern more reliable.';
    }

    return 'Sakan has recorded only $completedCount confirmed '
        '${completedCount == 1 ? 'session' : 'sessions'} for ${moment.title}. '
        'That is not enough history to call the rhythm stable or drifting with confidence.';
  }

  String _stableSummary({
    required FamilyMoment moment,
    required double? participation,
  }) {
    if (participation != null && participation < 0.5) {
      return '${moment.title} is occurring close to its intended rhythm, '
          'but the recorded group is often smaller than expected. '
          'The timing looks dependable even though participation varies.';
    }

    return '${moment.title} has become a dependable part of your family routine. '
        'It is happening close to its intended rhythm'
        '${participation != null && participation >= 0.75 ? ', and most expected members are usually recorded as participating' : ''}.';
  }

  String _driftingSummary({
    required FamilyMoment moment,
    required double? participation,
    required int missedCount,
  }) {
    if (participation != null && participation >= 0.75) {
      return '${moment.title} is happening less regularly than planned, '
          'but participation remains strong when it does happen. '
          'The available data points more strongly to timing consistency than to low recorded participation.';
    }

    if (missedCount > 0) {
      return '${moment.title} has become less consistent in both timing and recent outcomes. '
          'The family may need a simpler frequency or a time that is easier for expected members to maintain.';
    }

    return '${moment.title} has moved beyond its usual rhythm. '
        'Sakan needs another confirmed occurrence to see whether this is a temporary delay or a continuing change.';
  }

  String _recoveringSummary({
    required FamilyMoment moment,
    required double? participation,
  }) {
    return '${moment.title} is returning after a less consistent period. '
        'Recent completed sessions are closer to its usual rhythm'
        '${participation != null && participation >= 0.75 ? ', with strong recorded participation' : ''}. '
        'A few more occurrences will show whether the recovery continues.';
  }

  String _strengtheningSummary({
    required FamilyMoment moment,
    required double? participation,
  }) {
    return '${moment.title} is becoming more dependable. '
        'Recent sessions are occurring consistently'
        '${participation != null && participation >= 0.75 ? ', and most expected members are taking part' : ''}.';
  }

  double? _averageParticipationRatio(List<MomentInstance> completed) {
    var total = 0.0;
    var samples = 0;

    for (final instance in completed) {
      final expected = instance.expectedParticipantIds.toSet();

      if (expected.isEmpty) {
        continue;
      }

      final recorded = instance.allRecordedParticipantIds
          .toSet()
          .intersection(expected)
          .length;

      total += recorded / expected.length;
      samples++;
    }

    if (samples == 0) {
      return null;
    }

    return total / samples;
  }

  int? _averageDurationMinutes(List<MomentInstance> completed) {
    final durations = completed
        .map((instance) => instance.actualDurationMinutes)
        .whereType<int>()
        .where((duration) => duration >= 0)
        .toList(growable: false);

    if (durations.isEmpty) {
      return null;
    }

    final total = durations.fold<int>(0, (sum, duration) => sum + duration);

    return (total / durations.length).round();
  }

}
