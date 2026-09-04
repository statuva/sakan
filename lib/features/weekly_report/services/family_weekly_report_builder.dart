import '../../../shared/models/family_insight_snapshot.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/models/rhythm_record.dart';
import '../domain/family_weekly_report.dart';
import '../domain/family_weekly_report_period.dart';

abstract final class FamilyWeeklyReportBuilder {
  static FamilyWeeklyReport buildLatestCompletedWeek(
    FamilyInsightSnapshot snapshot, {
    DateTime? now,
  }) {
    final period = FamilyWeeklyReportPeriod.latestCompleted(
      now: now ?? snapshot.generatedAt,
    );
    final weekStart = period.start;
    final weekEndExclusive = period.endExclusive;
    final latestById = <String, MomentInstance>{};

    for (final instance in snapshot.instances) {
      if (instance.familyId != snapshot.familyId) {
        continue;
      }

      final current = latestById[instance.id];
      if (current == null || instance.updatedAt.isAfter(current.updatedAt)) {
        latestById[instance.id] = instance;
      }
    }

    final instances =
        latestById.values.where((instance) {
          final date = _reportDate(instance).toLocal();
          return !date.isBefore(weekStart) && date.isBefore(weekEndExclusive);
        }).toList()..sort((first, second) {
          final dateComparison = _reportDate(
            first,
          ).compareTo(_reportDate(second));
          if (dateComparison != 0) {
            return dateComparison;
          }

          final momentComparison = first.momentId.compareTo(second.momentId);
          return momentComparison != 0
              ? momentComparison
              : first.id.compareTo(second.id);
        });

    var completedCount = 0;
    var missedCount = 0;
    var pendingReviewCount = 0;
    var cancelledCount = 0;
    int? totalDurationMinutes;
    final participationSamples = <double>[];
    final days = List<_DayAccumulator>.generate(
      7,
      (index) => _DayAccumulator(
        DateTime(weekStart.year, weekStart.month, weekStart.day + index),
      ),
    );
    final patterns = <String, _PatternAccumulator>{};

    for (final instance in instances) {
      final date = _reportDate(instance).toLocal();
      final dateOnly = DateTime(date.year, date.month, date.day);
      final dayIndex = (dateOnly.weekday - DateTime.monday + 7) % 7;
      final day = days[dayIndex];
      final rhythm = snapshot.rhythmForMoment(instance.momentId);
      final pattern = instance.typeSnapshot != MomentType.recurring
          ? null
          : patterns.putIfAbsent(
              instance.momentId,
              () => _PatternAccumulator(
                momentId: instance.momentId,
                title: instance.titleSnapshot,
                rhythm: rhythm,
              ),
            );

      day.occurrenceCount += 1;

      if (instance.status == MomentInstanceStatus.completed) {
        completedCount += 1;
        day.completedCount += 1;
        if (pattern != null) {
          pattern.completedCount += 1;
        }

        final duration = instance.actualDurationMinutes;
        if (duration != null && duration >= 0) {
          totalDurationMinutes = (totalDurationMinutes ?? 0) + duration;
          if (pattern != null) {
            pattern.actualDurationMinutes += duration;
          }
        }

        final expected = instance.expectedParticipantIds.toSet();
        if (expected.isNotEmpty) {
          final recorded = instance.allRecordedParticipantIds
              .toSet()
              .intersection(expected);
          participationSamples.add(recorded.length / expected.length);
        }
      } else if (instance.status == MomentInstanceStatus.missed) {
        missedCount += 1;
        day.missedCount += 1;
        if (pattern != null) {
          pattern.missedCount += 1;
        }
      } else if (instance.status == MomentInstanceStatus.cancelled) {
        cancelledCount += 1;
        day.cancelledCount += 1;
        if (pattern != null) {
          pattern.cancelledCount += 1;
        }
      } else {
        pendingReviewCount += 1;
        day.pendingReviewCount += 1;
        if (pattern != null) {
          pattern.pendingReviewCount += 1;
        }
      }
    }

    final momentPatterns =
        patterns.values.map((item) {
          final effect = _effectFor(item);
          return WeeklyMomentPattern(
            momentId: item.momentId,
            title: item.title,
            completedCount: item.completedCount,
            missedCount: item.missedCount,
            pendingReviewCount: item.pendingReviewCount,
            cancelledCount: item.cancelledCount,
            actualDurationMinutes: item.actualDurationMinutes,
            rhythmStatus: item.rhythm?.status,
            rhythmConfidence: item.rhythm?.confidence,
            currentGapDays: item.rhythm?.currentGapDays,
            expectedIntervalDays: item.rhythm?.expectedIntervalDays,
            effect: effect,
            explanation: _patternExplanation(item, effect),
          );
        }).toList()..sort((first, second) {
          final priority = _effectPriority(
            first.effect,
          ).compareTo(_effectPriority(second.effect));
          if (priority != 0) {
            return priority;
          }

          final countComparison = second.resolvedCount.compareTo(
            first.resolvedCount,
          );
          if (countComparison != 0) {
            return countComparison;
          }

          final titleComparison = first.title.compareTo(second.title);
          return titleComparison != 0
              ? titleComparison
              : first.momentId.compareTo(second.momentId);
        });

    final participationRate = participationSamples.isEmpty
        ? null
        : participationSamples.reduce((sum, item) => sum + item) /
              participationSamples.length;

    return FamilyWeeklyReport(
      familyId: snapshot.familyId,
      weekStart: weekStart,
      weekEndExclusive: weekEndExclusive,
      generatedAt: (now ?? snapshot.generatedAt).toUtc(),
      occurrenceCount: instances.length,
      completedCount: completedCount,
      missedCount: missedCount,
      pendingReviewCount: pendingReviewCount,
      cancelledCount: cancelledCount,
      totalDurationMinutes: totalDurationMinutes,
      participationRate: participationRate,
      headline: _headline(
        occurrenceCount: instances.length,
        completedCount: completedCount,
        missedCount: missedCount,
      ),
      interpretation: _interpretation(
        completedCount: completedCount,
        missedCount: missedCount,
        pendingReviewCount: pendingReviewCount,
        cancelledCount: cancelledCount,
        patterns: momentPatterns,
      ),
      dailyActivity: days
          .map(
            (day) => WeeklyDayActivity(
              date: day.date,
              occurrenceCount: day.occurrenceCount,
              completedCount: day.completedCount,
              missedCount: day.missedCount,
              pendingReviewCount: day.pendingReviewCount,
              cancelledCount: day.cancelledCount,
            ),
          )
          .toList(growable: false),
      momentPatterns: momentPatterns,
    );
  }

  static DateTime _reportDate(MomentInstance instance) {
    return instance.status == MomentInstanceStatus.completed
        ? instance.effectiveStartAt
        : instance.scheduledStartAt;
  }

  static WeeklyPatternEffect _effectFor(_PatternAccumulator pattern) {
    if (pattern.completedCount == 0 && pattern.missedCount == 0) {
      return WeeklyPatternEffect.noNewEvidence;
    }
    if (pattern.missedCount > pattern.completedCount) {
      return WeeklyPatternEffect.underPressure;
    }
    if (pattern.completedCount > 0 && pattern.missedCount == 0) {
      return WeeklyPatternEffect.supported;
    }
    return WeeklyPatternEffect.mixed;
  }

  static String _patternExplanation(
    _PatternAccumulator pattern,
    WeeklyPatternEffect effect,
  ) {
    final evidence =
        '${_count(pattern.completedCount, 'completed occurrence')} and '
        '${_count(pattern.missedCount, 'missed occurrence')}';
    final impact = switch (effect) {
      WeeklyPatternEffect.supported =>
        'This week added positive recorded evidence.',
      WeeklyPatternEffect.mixed =>
        'This week added mixed evidence, so the pattern needs more time.',
      WeeklyPatternEffect.underPressure =>
        'This week placed pressure on the pattern and may need attention.',
      WeeklyPatternEffect.noNewEvidence =>
        'This week has no new resolved outcome.',
    };
    final rhythm = pattern.rhythm == null
        ? 'Sakan is still collecting enough evidence to calculate its rhythm.'
        : 'The current rhythm is '
              '${_rhythmLabel(pattern.rhythm!.status).toLowerCase()} '
              'with ${pattern.rhythm!.confidence.name} confidence. '
              'Its current gap is '
              '${_count(pattern.rhythm!.currentGapDays, 'day')} against an '
              'expected interval of '
              '${_count(pattern.rhythm!.expectedIntervalDays, 'day')}.';
    return '$evidence. $impact $rhythm';
  }

  static String _headline({
    required int occurrenceCount,
    required int completedCount,
    required int missedCount,
  }) {
    if (occurrenceCount == 0) {
      return 'A quiet week in Sakan';
    }
    if (completedCount == 0 && missedCount == 0) {
      return 'This week has no resolved Moment outcomes yet';
    }
    if (completedCount > 0 && missedCount == 0) {
      return 'This week added positive Moment evidence';
    }
    if (completedCount > missedCount) {
      return 'More Moments happened than were missed';
    }
    if (missedCount > completedCount) {
      return 'A few family patterns may need attention';
    }
    return 'This week added useful pattern evidence';
  }

  static String _interpretation({
    required int completedCount,
    required int missedCount,
    required int pendingReviewCount,
    required int cancelledCount,
    required List<WeeklyMomentPattern> patterns,
  }) {
    if (completedCount + missedCount + pendingReviewCount + cancelledCount ==
        0) {
      return 'No family Moment outcomes were recorded during this week.';
    }

    final parts = <String>[
      if (completedCount + missedCount == 0)
        'No Moments were resolved as completed or missed.'
      else
        '${_count(completedCount, 'Moment')} completed and '
            '${_count(missedCount, 'Moment')} missed.',
    ];
    if (pendingReviewCount > 0) {
      parts.add(
        '${_count(pendingReviewCount, 'occurrence')} '
        '${pendingReviewCount == 1 ? 'is' : 'are'} still unresolved.',
      );
    }
    if (cancelledCount > 0) {
      parts.add('${_count(cancelledCount, 'occurrence')} cancelled.');
    }
    final attention = patterns.where(
      (pattern) => pattern.effect == WeeklyPatternEffect.underPressure,
    );
    if (attention.isNotEmpty) {
      parts.add(
        '${attention.first.title} has the clearest pressure in this '
        "week's evidence.",
      );
    } else {
      final supported = patterns.where(
        (pattern) => pattern.effect == WeeklyPatternEffect.supported,
      );
      if (supported.isNotEmpty) {
        parts.add(
          '${supported.first.title} added the clearest positive recorded '
          'evidence this week.',
        );
      }
    }
    return parts.join(' ');
  }

  static int _effectPriority(WeeklyPatternEffect effect) {
    return switch (effect) {
      WeeklyPatternEffect.underPressure => 0,
      WeeklyPatternEffect.supported => 1,
      WeeklyPatternEffect.mixed => 2,
      WeeklyPatternEffect.noNewEvidence => 3,
    };
  }

  static String _rhythmLabel(RhythmStatus status) {
    return switch (status) {
      RhythmStatus.stillLearning => 'Still Learning',
      RhythmStatus.stable => 'Stable',
      RhythmStatus.drifting => 'Drifting',
      RhythmStatus.recovering => 'Recovering',
      RhythmStatus.strengthening => 'Strengthening',
    };
  }

  static String _count(int count, String singular) {
    return '$count $singular${count == 1 ? '' : 's'}';
  }
}

class _DayAccumulator {
  _DayAccumulator(this.date);

  final DateTime date;
  int occurrenceCount = 0;
  int completedCount = 0;
  int missedCount = 0;
  int pendingReviewCount = 0;
  int cancelledCount = 0;
}

class _PatternAccumulator {
  _PatternAccumulator({
    required this.momentId,
    required this.title,
    required this.rhythm,
  });

  final String momentId;
  final String title;
  final RhythmRecord? rhythm;
  int completedCount = 0;
  int missedCount = 0;
  int pendingReviewCount = 0;
  int cancelledCount = 0;
  int actualDurationMinutes = 0;
}
