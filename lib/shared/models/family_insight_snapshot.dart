import 'availability_block.dart';
import 'care_action.dart';
import 'family_memory.dart';
import 'family_moment.dart';
import 'member.dart';
import 'model_enums.dart';
import 'moment_instance.dart';
import 'rhythm_record.dart';

class FamilyInsightSnapshot {
  FamilyInsightSnapshot({
    required this.familyId,
    required this.currentUserId,
    required this.generatedAt,
    required List<Member> members,
    required List<FamilyMoment> moments,
    required List<MomentInstance> instances,
    required List<RhythmRecord> rhythms,
    required List<AvailabilityBlock> availability,
    required List<CareAction> reminders,
    required List<FamilyMemory> memories,
  }) : members = List<Member>.unmodifiable(members),
       moments = List<FamilyMoment>.unmodifiable(moments),
       instances = List<MomentInstance>.unmodifiable(instances),
       rhythms = List<RhythmRecord>.unmodifiable(rhythms),
       availability = List<AvailabilityBlock>.unmodifiable(availability),
       reminders = List<CareAction>.unmodifiable(reminders),
       memories = List<FamilyMemory>.unmodifiable(memories);

  final String familyId;
  final String currentUserId;

  /// Store this in UTC. User-facing date calculations use local time.
  final DateTime generatedAt;

  final List<Member> members;
  final List<FamilyMoment> moments;
  final List<MomentInstance> instances;
  final List<RhythmRecord> rhythms;
  final List<AvailabilityBlock> availability;
  final List<CareAction> reminders;
  final List<FamilyMemory> memories;

  List<Member> get activeMembers {
    return members.where((member) => member.isActive).toList(growable: false);
  }

  Member? get currentMember {
    return membersById[currentUserId];
  }

  bool get currentUserCanManageSharedMoments {
    final role = currentMember?.role;
    return role == FamilyRole.admin || role == FamilyRole.adult;
  }

  Map<String, Member> get membersById {
    return <String, Member>{for (final member in members) member.id: member};
  }

  Map<String, FamilyMoment> get momentsById {
    return <String, FamilyMoment>{
      for (final moment in moments) moment.id: moment,
    };
  }

  Map<String, MomentInstance> get instancesById {
    return <String, MomentInstance>{
      for (final instance in instances) instance.id: instance,
    };
  }

  Map<String, RhythmRecord> get rhythmsByMomentId {
    return <String, RhythmRecord>{
      for (final rhythm in rhythms) rhythm.momentId: rhythm,
    };
  }

  Map<String, FamilyMemory> get memoriesByInstanceId {
    return <String, FamilyMemory>{
      for (final memory in memories)
        if (memory.instanceId != null) memory.instanceId!: memory,
    };
  }

  Map<String, FamilyMemory> get latestMemoriesByMomentId {
    final result = <String, FamilyMemory>{};

    final newestFirst = List<FamilyMemory>.from(memories)
      ..sort((first, second) => second.occurredAt.compareTo(first.occurredAt));

    for (final memory in newestFirst) {
      result.putIfAbsent(memory.momentId, () => memory);
    }

    return result;
  }

  MomentInstance? get activeInstance {
    final active =
        instances
            .where((instance) => instance.status == MomentInstanceStatus.active)
            .toList()
          ..sort(
            (first, second) =>
                first.effectiveStartAt.compareTo(second.effectiveStartAt),
          );

    return active.isEmpty ? null : active.first;
  }

  List<MomentInstance> get upcomingInstances {
    final reference = generatedAt.toLocal();

    final result = instances.where((instance) {
      if (!_isPlanned(instance)) {
        return false;
      }

      return !instance.scheduledStartAt.toLocal().isBefore(reference);
    }).toList();

    result.sort(
      (first, second) =>
          first.scheduledStartAt.compareTo(second.scheduledStartAt),
    );

    return result;
  }

  /// Planned occurrences that can currently produce a user action.
  ///
  /// This includes future occurrences, occurrences whose start time has
  /// arrived but whose planned end has not passed, and unresolved occurrences
  /// from the seven-day review backlog.
  List<MomentInstance> get actionablePlannedInstances {
    final now = generatedAt.toLocal();
    final earliestEnd = now.subtract(const Duration(days: 7));

    final result = instances.where((instance) {
      if (!_isPlanned(instance)) {
        return false;
      }

      final localStart = instance.scheduledStartAt.toLocal();
      final localEnd =
          instance.scheduledEndAt?.toLocal() ??
          localStart.add(const Duration(minutes: 90));

      return !localEnd.isBefore(earliestEnd);
    }).toList();

    result.sort(
      (first, second) =>
          first.scheduledStartAt.compareTo(second.scheduledStartAt),
    );

    return result;
  }

  List<MomentInstance> get completedInstances {
    final result = instances
        .where((instance) => instance.status == MomentInstanceStatus.completed)
        .toList();

    result.sort(
      (first, second) =>
          second.effectiveStartAt.compareTo(first.effectiveStartAt),
    );

    return result;
  }

  List<MomentInstance> get missedInstances {
    final result = instances
        .where((instance) => instance.status == MomentInstanceStatus.missed)
        .toList();

    result.sort(
      (first, second) =>
          second.scheduledStartAt.compareTo(first.scheduledStartAt),
    );

    return result;
  }

  /// Planned occurrences from the previous seven days whose expected time
  /// has passed but which have no completed, missed, or cancelled outcome.
  List<MomentInstance> get reviewableInstances {
    final now = generatedAt.toLocal();
    final earliest = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 7));

    final result = instances.where((instance) {
      if (!_isPlanned(instance)) {
        return false;
      }

      final localStart = instance.scheduledStartAt.toLocal();
      final localEnd =
          instance.scheduledEndAt?.toLocal() ??
          localStart.add(const Duration(minutes: 90));

      return !localStart.isBefore(earliest) && !localEnd.isAfter(now);
    }).toList();

    result.sort(
      (first, second) =>
          first.scheduledStartAt.compareTo(second.scheduledStartAt),
    );

    return result;
  }

  MomentInstance? get nextInstance {
    final upcoming = upcomingInstances;
    return upcoming.isEmpty ? null : upcoming.first;
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

  FamilyMemory? get latestMemory {
    if (memories.isEmpty) {
      return null;
    }

    final sorted = List<FamilyMemory>.from(memories)
      ..sort((first, second) => second.occurredAt.compareTo(first.occurredAt));

    return sorted.first;
  }

  FamilyMoment? momentById(String momentId) {
    return momentsById[momentId];
  }

  MomentInstance? instanceById(String instanceId) {
    return instancesById[instanceId];
  }

  RhythmRecord? rhythmForMoment(String momentId) {
    return rhythmsByMomentId[momentId];
  }

  FamilyMemory? memoryForInstance(String instanceId) {
    return memoriesByInstanceId[instanceId];
  }

  FamilyMemory? latestMemoryForMoment(String momentId) {
    return latestMemoriesByMomentId[momentId];
  }

  List<MomentInstance> instancesForMoment(String momentId) {
    final result = instances
        .where((instance) => instance.momentId == momentId)
        .toList();

    result.sort(
      (first, second) =>
          first.effectiveStartAt.compareTo(second.effectiveStartAt),
    );

    return result;
  }

  MomentInstance? openInstanceForMoment(String momentId) {
    final result = instancesForMoment(momentId).where((instance) {
      return _isPlanned(instance) ||
          instance.status == MomentInstanceStatus.active;
    }).toList();

    if (result.isEmpty) {
      return null;
    }

    result.sort((first, second) {
      if (first.isActive != second.isActive) {
        return first.isActive ? -1 : 1;
      }

      return first.effectiveStartAt.compareTo(second.effectiveStartAt);
    });

    return result.first;
  }

  CareAction? activeReminderForInstance(String instanceId) {
    for (final reminder in pendingCurrentUserReminders) {
      if (reminder.instanceId == instanceId) {
        return reminder;
      }
    }

    return null;
  }

  CareAction? activeReminderForMoment(String momentId) {
    for (final reminder in pendingCurrentUserReminders) {
      if (reminder.momentId == momentId) {
        return reminder;
      }
    }

    return null;
  }

  CareAction? activeReminderForOccurrence(MomentInstance instance) {
    final exact = activeReminderForInstance(instance.id);

    if (exact != null) {
      return exact;
    }

    // Compatibility for reminders created before instanceId was stored.
    for (final reminder in pendingCurrentUserReminders) {
      if (reminder.instanceId == null &&
          reminder.momentId == instance.momentId) {
        return reminder;
      }
    }

    return null;
  }

  bool currentUserIsExpected(MomentInstance instance) {
    return instance.expectedParticipantIds.contains(currentUserId);
  }

  static bool _isPlanned(MomentInstance instance) {
    return instance.status == MomentInstanceStatus.proposed ||
        instance.status == MomentInstanceStatus.scheduled ||
        instance.status == MomentInstanceStatus.inviting;
  }
}
