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
  }) {
    final recurringMoments = moments
        .where((moment) => moment.type == MomentType.recurring)
        .toList(growable: false);

    if (recurringMoments.isEmpty) {
      return const FamilyTwinInterpretation(
        summary:
            'Add and record recurring family Moments before Sakan can describe how your family rhythms are changing.',
        themes: <String>[
          'No recurring patterns yet',
          'More recorded sessions are needed',
        ],
        origin: DigitalTwinInterpretationOrigin.ruleBasedFallback,
      );
    }

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

    final stableCount = countStatus(RhythmStatus.stable);
    final strengtheningCount = countStatus(RhythmStatus.strengthening);
    final driftingCount = countStatus(RhythmStatus.drifting);
    final recoveringCount = countStatus(RhythmStatus.recovering);
    final learningCount = countStatus(RhythmStatus.stillLearning);
    final dependableCount = stableCount + strengtheningCount;

    final recurringIds = recurringMoments.map((moment) => moment.id).toSet();

    final completed = instances
        .where((instance) {
          return recurringIds.contains(instance.momentId) &&
              instance.status == MomentInstanceStatus.completed;
        })
        .toList(growable: false);

    final outcomes = instances
        .where((instance) {
          return recurringIds.contains(instance.momentId) &&
              (instance.status == MomentInstanceStatus.completed ||
                  instance.status == MomentInstanceStatus.missed);
        })
        .toList(growable: false);

    final participation = _averageParticipationRatio(completed);

    final weekendRate = _completionRate(outcomes: outcomes, weekend: true);

    final weekdayRate = _completionRate(outcomes: outcomes, weekend: false);

    final sentences = <String>[];

    if (learningCount == recurringMoments.length) {
      sentences.add(
        'Sakan is still learning most of your family rhythms. '
        'A few more confirmed sessions will make the picture more reliable.',
      );
    } else if (driftingCount > 0 && dependableCount > 0) {
      sentences.add(
        'Your family has $dependableCount '
        '${dependableCount == 1 ? 'dependable rhythm' : 'dependable rhythms'}, '
        'while $driftingCount '
        '${driftingCount == 1 ? 'Moment is' : 'Moments are'} becoming less regular. '
        'The pattern is mixed rather than one overall family score.',
      );
    } else if (driftingCount > 0) {
      sentences.add(
        '$driftingCount recurring '
        '${driftingCount == 1 ? 'Moment is' : 'Moments are'} happening less regularly than planned. '
        'The family may need timings or frequencies that are easier to maintain.',
      );
    } else if (recoveringCount > 0) {
      sentences.add(
        '$recoveringCount '
        '${recoveringCount == 1 ? 'rhythm is' : 'rhythms are'} returning after a less consistent period. '
        'Recent completed sessions are moving closer to the intended pattern.',
      );
    } else if (dependableCount == recurringMoments.length) {
      sentences.add(
        'The recorded recurring Moments are currently dependable. '
        'They are happening close to their intended rhythms.',
      );
    } else {
      sentences.add(
        'Your family has a mixture of established and developing rhythms. '
        'Sakan is continuing to learn from each confirmed or missed occurrence.',
      );
    }

    if (participation != null) {
      if (participation >= 0.75) {
        sentences.add(
          'When a shared session happens, most expected members are usually recorded as participating.',
        );
      } else if (participation < 0.5) {
        sentences.add(
          'Recorded sessions often include fewer expected members, '
          'so participation is less consistent than timing alone suggests.',
        );
      }
    }

    if (weekendRate != null && weekdayRate != null) {
      final difference = weekendRate - weekdayRate;

      if (difference >= 0.25) {
        sentences.add(
          'Recent weekend occurrences have been completed more consistently than weekday occurrences.',
        );
      } else if (difference <= -0.25) {
        sentences.add(
          'Recent weekday occurrences have been completed more consistently than weekend occurrences.',
        );
      }
    }

    final themes = <String>[];

    if (dependableCount > 0) {
      themes.add(
        '$dependableCount dependable '
        '${dependableCount == 1 ? 'rhythm' : 'rhythms'}',
      );
    }

    if (driftingCount > 0) {
      themes.add(
        '$driftingCount '
        '${driftingCount == 1 ? 'rhythm needs' : 'rhythms need'} consistency',
      );
    }

    if (recoveringCount > 0) {
      themes.add(
        '$recoveringCount '
        '${recoveringCount == 1 ? 'rhythm is' : 'rhythms are'} returning',
      );
    }

    if (participation != null && participation >= 0.75) {
      themes.add('Participation is usually strong');
    }

    if (learningCount > 0) {
      themes.add(
        '$learningCount '
        '${learningCount == 1 ? 'pattern is' : 'patterns are'} still being learned',
      );
    }

    if (themes.isEmpty) {
      themes.add('More recorded sessions are needed');
    }

    return FamilyTwinInterpretation(
      summary: sentences.join(' '),
      themes: List<String>.unmodifiable(themes.take(3)),
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
  }) {
    final recurring = moments
        .where((moment) => moment.type == MomentType.recurring)
        .toList(growable: false);

    final rhythmByMomentId = <String, RhythmRecord>{
      for (final rhythm in rhythms) rhythm.momentId: rhythm,
    };

    return <String, dynamic>{
      'recurringMomentCount': recurring.length,
      'statusCounts': <String, int>{
        for (final status in RhythmStatus.values)
          status.name: recurring.where((moment) {
            return (rhythmByMomentId[moment.id]?.status ??
                    RhythmStatus.stillLearning) ==
                status;
          }).length,
      },
      'moments': recurring
          .map(
            (moment) => buildMomentAiPayload(
              moment: moment,
              rhythm: rhythmByMomentId[moment.id],
              instances: instances
                  .where((instance) => instance.momentId == moment.id)
                  .toList(),
            ),
          )
          .toList(),
    };
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

  double? _completionRate({
    required List<MomentInstance> outcomes,
    required bool weekend,
  }) {
    final filtered = outcomes
        .where((instance) {
          final weekday = instance.scheduledStartAt.toLocal().weekday;
          final isWeekend =
              weekday == DateTime.saturday || weekday == DateTime.sunday;

          return isWeekend == weekend;
        })
        .toList(growable: false);

    if (filtered.length < 2) {
      return null;
    }

    final completedCount = filtered
        .where((instance) => instance.status == MomentInstanceStatus.completed)
        .length;

    return completedCount / filtered.length;
  }
}
