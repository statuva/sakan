import '../../../shared/models/family_insight_snapshot.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/services/moment_schedule_resolver.dart';
import '../../../shared/services/recurring_occurrence_service.dart';
import '../domain/family_weekly_report_period.dart';

abstract final class FamilyWeeklyReportSnapshotProjector {
  static FamilyInsightSnapshot projectLatestCompletedWeek(
    FamilyInsightSnapshot snapshot, {
    DateTime? now,
  }) {
    final period = FamilyWeeklyReportPeriod.latestCompleted(
      now: now ?? snapshot.generatedAt,
    );
    final latestById = <String, MomentInstance>{};

    for (final instance in snapshot.instances) {
      if (instance.familyId != snapshot.familyId) {
        continue;
      }

      final existing = latestById[instance.id];
      if (existing == null || instance.updatedAt.isAfter(existing.updatedAt)) {
        latestById[instance.id] = instance;
      }
    }

    final latestByOccurrence = <String, MomentInstance>{};
    for (final instance in latestById.values) {
      final key = _occurrenceKey(instance.momentId, instance.scheduledStartAt);
      final existing = latestByOccurrence[key];
      if (existing == null || _prefer(instance, over: existing)) {
        latestByOccurrence[key] = instance;
      }
    }
    final existingIds = latestById.keys.toSet();

    for (final moment in snapshot.moments) {
      if (moment.familyId != snapshot.familyId) {
        continue;
      }

      final starts = RecurringOccurrenceService.calculateStartsInRange(
        moment: moment,
        rangeStart: period.start,
        rangeEnd: period.inclusiveEnd,
      );
      for (final start in starts) {
        final startUtc = start.toUtc();
        final id = _scheduledInstanceId(moment.id, startUtc);
        final occurrenceKey = _occurrenceKey(moment.id, startUtc);
        if (existingIds.contains(id) ||
            latestByOccurrence.containsKey(occurrenceKey)) {
          continue;
        }

        final end = MomentScheduleResolver.endForStart(
          start: start,
          endMinutes: moment.resolvedPreferredEndMinutes,
        );
        latestByOccurrence[occurrenceKey] = MomentInstance.scheduledFromMoment(
          id: id,
          moment: moment,
          source: MomentInstanceSource.calendar,
          scheduledStartAt: startUtc,
          scheduledEndAt: end?.toUtc(),
          createdBy: moment.createdBy,
          now: snapshot.generatedAt,
        );
        existingIds.add(id);
      }
    }

    final instances = latestByOccurrence.values.toList()
      ..sort((first, second) {
        final startComparison = first.effectiveStartAt.compareTo(
          second.effectiveStartAt,
        );
        return startComparison != 0
            ? startComparison
            : first.id.compareTo(second.id);
      });

    return FamilyInsightSnapshot(
      familyId: snapshot.familyId,
      currentUserId: snapshot.currentUserId,
      generatedAt: snapshot.generatedAt,
      members: snapshot.members,
      moments: snapshot.moments,
      instances: instances,
      rhythms: snapshot.rhythms,
      availability: snapshot.availability,
      reminders: snapshot.reminders,
      memories: snapshot.memories,
    );
  }

  static String _scheduledInstanceId(String momentId, DateTime start) {
    return 'instance_${momentId}_${start.toUtc().millisecondsSinceEpoch}';
  }

  static String _occurrenceKey(String momentId, DateTime start) {
    return '$momentId:${start.toUtc().millisecondsSinceEpoch}';
  }

  static bool _prefer(
    MomentInstance candidate, {
    required MomentInstance over,
  }) {
    final updateComparison = candidate.updatedAt.compareTo(over.updatedAt);
    if (updateComparison != 0) {
      return updateComparison > 0;
    }

    final statusComparison = _statusPriority(
      candidate.status,
    ).compareTo(_statusPriority(over.status));
    if (statusComparison != 0) {
      return statusComparison < 0;
    }

    return candidate.id.compareTo(over.id) < 0;
  }

  static int _statusPriority(MomentInstanceStatus status) {
    return switch (status) {
      MomentInstanceStatus.completed => 0,
      MomentInstanceStatus.missed => 1,
      MomentInstanceStatus.cancelled => 2,
      MomentInstanceStatus.active => 3,
      MomentInstanceStatus.inviting => 4,
      MomentInstanceStatus.scheduled => 5,
      MomentInstanceStatus.proposed => 6,
    };
  }
}
