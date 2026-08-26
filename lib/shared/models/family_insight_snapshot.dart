import 'availability_block.dart';
import 'care_action.dart';
import 'family_memory.dart';
import 'family_moment.dart';
import 'member.dart';
import 'model_enums.dart';
import 'rhythm_record.dart';

class FamilyInsightSnapshot {
  FamilyInsightSnapshot({
    required this.familyId,
    required this.currentUserId,
    required this.generatedAt,
    required List<Member> members,
    required List<FamilyMoment> moments,
    required List<RhythmRecord> rhythms,
    required List<AvailabilityBlock> availability,
    required List<CareAction> reminders,
    required List<FamilyMemory> memories,
  }) : members = List<Member>.unmodifiable(members),
       moments = List<FamilyMoment>.unmodifiable(moments),
       rhythms = List<RhythmRecord>.unmodifiable(rhythms),
       availability = List<AvailabilityBlock>.unmodifiable(availability),
       reminders = List<CareAction>.unmodifiable(reminders),
       memories = List<FamilyMemory>.unmodifiable(memories);

  final String familyId;
  final String currentUserId;

  /// The instant at which all derived facts are evaluated.
  ///
  /// Store this value in UTC. Derived date comparisons use local time.
  final DateTime generatedAt;

  final List<Member> members;
  final List<FamilyMoment> moments;
  final List<RhythmRecord> rhythms;
  final List<AvailabilityBlock> availability;
  final List<CareAction> reminders;
  final List<FamilyMemory> memories;

  List<Member> get activeMembers {
    return members.where((member) => member.isActive).toList(growable: false);
  }

  Map<String, Member> get membersById {
    return <String, Member>{for (final member in members) member.id: member};
  }

  Map<String, RhythmRecord> get rhythmsByMomentId {
    return <String, RhythmRecord>{
      for (final rhythm in rhythms) rhythm.momentId: rhythm,
    };
  }

  Map<String, FamilyMemory> get memoriesByMomentId {
    final result = <String, FamilyMemory>{};

    final newestFirst = List<FamilyMemory>.from(memories)
      ..sort((first, second) => second.occurredAt.compareTo(first.occurredAt));

    for (final memory in newestFirst) {
      result.putIfAbsent(memory.momentId, () => memory);
    }

    return result;
  }

  List<FamilyMoment> get upcomingMoments {
    final reference = generatedAt.toLocal();

    final result = moments.where((moment) {
      if (moment.status == MomentStatus.cancelled ||
          moment.status == MomentStatus.completed ||
          moment.status == MomentStatus.missed) {
        return false;
      }

      if (moment.status == MomentStatus.active) {
        return true;
      }

      return !moment.startAt.toLocal().isBefore(reference);
    }).toList();

    result.sort((first, second) {
      if (first.status == MomentStatus.active &&
          second.status != MomentStatus.active) {
        return -1;
      }

      if (second.status == MomentStatus.active &&
          first.status != MomentStatus.active) {
        return 1;
      }

      return first.startAt.compareTo(second.startAt);
    });

    return result;
  }

  List<FamilyMoment> get completedMoments {
    final result = moments
        .where((moment) => moment.status == MomentStatus.completed)
        .toList();

    result.sort((first, second) => second.startAt.compareTo(first.startAt));

    return result;
  }

  List<CareAction> get currentUserReminders {
    return reminders
        .where((reminder) => reminder.assignedMemberId == currentUserId)
        .toList(growable: false);
  }

  List<CareAction> get pendingCurrentUserReminders {
    final result = currentUserReminders
        .where((reminder) => !reminder.isFinished)
        .toList();

    result.sort((first, second) => first.dueAt.compareTo(second.dueAt));

    return result;
  }

  List<CareAction> get completedCurrentUserReminders {
    final result = currentUserReminders
        .where((reminder) => reminder.isFinished)
        .toList();

    result.sort((first, second) {
      final firstDate = first.completedAt ?? first.updatedAt;
      final secondDate = second.completedAt ?? second.updatedAt;
      return secondDate.compareTo(firstDate);
    });

    return result;
  }

  List<CareAction> get overdueCurrentUserReminders {
    return pendingCurrentUserReminders
        .where((reminder) => reminder.isOverdueAt(generatedAt))
        .toList(growable: false);
  }

  CareAction? get nextCurrentUserReminder {
    final reference = generatedAt.toLocal();

    for (final reminder in pendingCurrentUserReminders) {
      if (reminder.dueAt.toLocal().isAfter(reference)) {
        return reminder;
      }
    }

    return null;
  }

  List<RhythmRecord> get driftingRhythms {
    final result = rhythms
        .where((rhythm) => rhythm.status == RhythmStatus.drifting)
        .toList();

    result.sort(
      (first, second) => second.currentGapDays.compareTo(first.currentGapDays),
    );

    return result;
  }

  List<RhythmRecord> get lowConfidenceRhythms {
    return rhythms
        .where((rhythm) => rhythm.confidence == ConfidenceLevel.low)
        .toList(growable: false);
  }

  FamilyMemory? get latestMemory {
    if (memories.isEmpty) {
      return null;
    }

    final sorted = List<FamilyMemory>.from(memories)
      ..sort((first, second) => second.occurredAt.compareTo(first.occurredAt));

    return sorted.first;
  }

  FamilyMoment? momentById(String momentId) {
    for (final moment in moments) {
      if (moment.id == momentId) {
        return moment;
      }
    }

    return null;
  }

  RhythmRecord? rhythmForMoment(String momentId) {
    return rhythmsByMomentId[momentId];
  }

  FamilyMemory? memoryForMoment(String momentId) {
    return memoriesByMomentId[momentId];
  }

  CareAction? activeReminderForMoment(String momentId) {
    for (final reminder in pendingCurrentUserReminders) {
      if (reminder.momentId == momentId) {
        return reminder;
      }
    }

    return null;
  }
}
