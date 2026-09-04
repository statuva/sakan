import '../../../shared/models/model_enums.dart';

enum TwinSimulationType {
  addParticipant,
  removeParticipant,
  changeTime,
  changeWeekday,
  changeDayOfMonth,
  changeFrequency,
  assumeNextCompleted,
  assumeNextMissed,
  assumeParticipantJoins,
  createMoment,
}

enum TwinSimulationScope { nextOccurrence, futureOccurrences }

enum TwinSimulationSource { structured, aiParsed }

class TwinSimulationScenario {
  const TwinSimulationScenario({
    required this.id,
    required this.type,
    this.source = TwinSimulationSource.structured,
    this.targetMomentId,
    this.participantIds = const <String>[],
    this.newTitle,
    this.newCategory,
    this.newIntervalDays,
    this.newStartMinutes,
    this.newWeekday,
    this.newDayOfMonth,
    this.newMonth,
    this.newIsDayFlexible = false,
    this.scope = TwinSimulationScope.nextOccurrence,
    this.assumedDurationMinutes,
  });

  final String id;
  final TwinSimulationType type;
  final TwinSimulationSource source;

  final String? targetMomentId;
  final List<String> participantIds;

  final String? newTitle;
  final MomentCategory? newCategory;
  final int? newIntervalDays;
  final int? newStartMinutes;
  final int? newWeekday;
  final int? newDayOfMonth;
  final int? newMonth;
  final bool newIsDayFlexible;

  final TwinSimulationScope scope;
  final int? assumedDurationMinutes;

  bool get createsMoment => type == TwinSimulationType.createMoment;

  bool get isOutcomeAssumption {
    return type == TwinSimulationType.assumeNextCompleted ||
        type == TwinSimulationType.assumeNextMissed ||
        type == TwinSimulationType.assumeParticipantJoins;
  }

  bool get changesParticipants {
    return type == TwinSimulationType.addParticipant ||
        type == TwinSimulationType.removeParticipant ||
        type == TwinSimulationType.assumeParticipantJoins;
  }

  bool get changesSchedule {
    return type == TwinSimulationType.changeTime ||
        type == TwinSimulationType.changeWeekday ||
        type == TwinSimulationType.changeDayOfMonth ||
        type == TwinSimulationType.changeFrequency;
  }

  String? validate() {
    if (id.trim().isEmpty) {
      return 'The simulation needs an ID.';
    }

    if (createsMoment) {
      if (newTitle == null || newTitle!.trim().isEmpty) {
        return 'Give the hypothetical Moment a name.';
      }

      if (newCategory == null) {
        return 'Choose a category for the hypothetical Moment.';
      }

      if (newIntervalDays == null || newIntervalDays! <= 0) {
        return 'Choose how often the hypothetical Moment repeats.';
      }

      if (newStartMinutes == null ||
          newStartMinutes! < 0 ||
          newStartMinutes! > 1439) {
        return 'Choose a valid start time.';
      }

      if (participantIds.isEmpty) {
        return 'Choose at least one participant.';
      }

      if (!newIsDayFlexible) {
        if ((newIntervalDays == 7 || newIntervalDays == 14) &&
            (newWeekday == null || newWeekday! < 1 || newWeekday! > 7)) {
          return 'Choose a weekday.';
        }

        if ((newIntervalDays == 30 || newIntervalDays == 90) &&
            (newDayOfMonth == null ||
                newDayOfMonth! < 1 ||
                newDayOfMonth! > 31)) {
          return 'Choose a day of the month.';
        }

        if (newIntervalDays == 365) {
          if (newMonth == null || newMonth! < 1 || newMonth! > 12) {
            return 'Choose a month.';
          }

          if (newDayOfMonth == null ||
              newDayOfMonth! < 1 ||
              newDayOfMonth! > 31) {
            return 'Choose a day of the month.';
          }
        }
      }

      return null;
    }

    if (targetMomentId == null || targetMomentId!.trim().isEmpty) {
      return 'Choose a Family Moment.';
    }

    if (changesParticipants && participantIds.isEmpty) {
      return 'Choose a family member.';
    }

    if (type == TwinSimulationType.changeTime &&
        (newStartMinutes == null ||
            newStartMinutes! < 0 ||
            newStartMinutes! > 1439)) {
      return 'Choose a valid start time.';
    }

    if (type == TwinSimulationType.changeWeekday &&
        (newWeekday == null || newWeekday! < 1 || newWeekday! > 7)) {
      return 'Choose a weekday.';
    }

    if (type == TwinSimulationType.changeDayOfMonth &&
        (newDayOfMonth == null || newDayOfMonth! < 1 || newDayOfMonth! > 31)) {
      return 'Choose a valid day of the month.';
    }

    if (type == TwinSimulationType.changeFrequency &&
        (newIntervalDays == null || newIntervalDays! <= 0)) {
      return 'Choose a valid frequency.';
    }

    if ((type == TwinSimulationType.assumeNextCompleted ||
            type == TwinSimulationType.assumeParticipantJoins) &&
        assumedDurationMinutes != null &&
        assumedDurationMinutes! <= 0) {
      return 'The assumed duration must be greater than zero.';
    }

    return null;
  }
}

extension TwinSimulationTypeLabel on TwinSimulationType {
  bool get isOutcomeAssumption {
    return this == TwinSimulationType.assumeNextCompleted ||
        this == TwinSimulationType.assumeNextMissed ||
        this == TwinSimulationType.assumeParticipantJoins;
  }

  String get label {
    return switch (this) {
      TwinSimulationType.addParticipant => 'Add someone to the Moment',
      TwinSimulationType.removeParticipant => 'Remove someone from the Moment',
      TwinSimulationType.changeTime => 'Try a different time',
      TwinSimulationType.changeWeekday => 'Try a different weekday',
      TwinSimulationType.changeDayOfMonth => 'Try a different day of month',
      TwinSimulationType.changeFrequency => 'Try a different frequency',
      TwinSimulationType.assumeNextCompleted =>
        'Assume the next occurrence happens',
      TwinSimulationType.assumeNextMissed =>
        'Assume the next occurrence is missed',
      TwinSimulationType.assumeParticipantJoins =>
        'Assume someone joins next time',
      TwinSimulationType.createMoment => 'Create a hypothetical Moment',
    };
  }

  String get description {
    return switch (this) {
      TwinSimulationType.addParticipant =>
        'Changes who is expected in the plan. It does not claim they attended.',
      TwinSimulationType.removeParticipant =>
        'Removes one expected participant from the simulated plan.',
      TwinSimulationType.changeTime =>
        'Compares recorded schedule conflicts at another time.',
      TwinSimulationType.changeWeekday =>
        'Compares the next four occurrences on another weekday.',
      TwinSimulationType.changeDayOfMonth =>
        'Compares monthly or quarterly occurrences on another date.',
      TwinSimulationType.changeFrequency =>
        'Compares the proposed rhythm with the family’s recorded history.',
      TwinSimulationType.assumeNextCompleted =>
        'Adds one hypothetical completed occurrence to the projection.',
      TwinSimulationType.assumeNextMissed =>
        'Adds one hypothetical missed occurrence to the projection.',
      TwinSimulationType.assumeParticipantJoins =>
        'Assumes a selected member joins a completed next occurrence.',
      TwinSimulationType.createMoment =>
        'Adds a new local-only hypothetical Moment with no recorded history.',
    };
  }
}

extension TwinSimulationScopeLabel on TwinSimulationScope {
  String get label {
    return switch (this) {
      TwinSimulationScope.nextOccurrence => 'Next occurrence',
      TwinSimulationScope.futureOccurrences => 'All future occurrences',
    };
  }
}
