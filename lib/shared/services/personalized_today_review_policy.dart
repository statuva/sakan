import '../models/family_moment.dart';
import '../models/member.dart';
import '../models/model_enums.dart';
import '../models/moment_instance.dart';

abstract final class PersonalizedTodayReviewPolicy {
  static List<MomentInstance> filter({
    required List<MomentInstance> instances,
    required Map<String, FamilyMoment> momentsById,
    required Member currentMember,
    DateTime? now,
  }) {
    final reference = (now ?? DateTime.now()).toLocal();
    final earliest = DateTime(
      reference.year,
      reference.month,
      reference.day,
    ).subtract(const Duration(days: 7));

    final result = instances.where((instance) {
      if (instance.status != MomentInstanceStatus.proposed &&
          instance.status != MomentInstanceStatus.scheduled &&
          instance.status != MomentInstanceStatus.inviting) {
        return false;
      }

      final start = instance.scheduledStartAt.toLocal();
      final end =
          instance.scheduledEndAt?.toLocal() ??
          start.add(const Duration(minutes: 90));
      if (start.isBefore(earliest) || end.isAfter(reference)) return false;

      final moment = momentsById[instance.momentId];
      if (moment == null) return false;

      final relevant =
          moment.expects(currentMember.id) ||
          moment.isSubject(currentMember.id) ||
          currentMember.role == FamilyRole.admin ||
          currentMember.role == FamilyRole.adult;
      if (!relevant) return false;

      // A completed live session never reaches this list because its instance
      // state is completed. External events and unresolved planned sessions do.
      return true;
    }).toList();

    result.sort((a, b) => a.scheduledStartAt.compareTo(b.scheduledStartAt));
    return result;
  }
}
