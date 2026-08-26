import '../models/family_moment.dart';
import '../models/model_enums.dart';
import '../models/moment_instance.dart';
import '../models/moment_participant.dart';

abstract interface class MomentInstanceRepository {
  Stream<List<MomentInstance>> watchInstances({required String familyId});

  Stream<List<MomentInstance>> watchMomentInstances({
    required String familyId,
    required String momentId,
  });

  Stream<List<MomentInstance>> watchUpcomingInstances({
    required String familyId,
  });

  Stream<MomentInstance?> watchActiveInstance({required String familyId});

  Stream<MomentInstance?> watchInstance({
    required String familyId,
    required String instanceId,
  });

  Stream<List<MomentParticipant>> watchParticipants({
    required String familyId,
    required String instanceId,
  });

  Future<MomentInstance?> getInstance({
    required String familyId,
    required String instanceId,
  });

  Future<MomentInstance?> getOpenInstanceForMoment({
    required String familyId,
    required String momentId,
  });

  Future<List<MomentParticipant>> getParticipants({
    required String familyId,
    required String instanceId,
  });

  /// Creates the first/next scheduled occurrence for a Moment,
  /// or updates its existing open scheduled occurrence.
  Future<MomentInstance?> syncScheduledInstanceFromMoment({
    required FamilyMoment moment,
    required String createdBy,
    MomentInstanceSource source = MomentInstanceSource.calendar,
  });

  /// Cancels proposed/scheduled/inviting/active occurrences
  /// belonging to a deleted or cancelled Moment definition.
  Future<int> cancelOpenInstancesForMoment({
    required String familyId,
    required String momentId,
    required String cancelledBy,
  });

  Future<MomentInstance> startMomentNow({
    required FamilyMoment moment,
    required String startedBy,
    required MomentInstanceSource source,
    String? existingInstanceId,
  });

  Future<void> checkIn({
    required String familyId,
    required String instanceId,
    required String memberId,
    MomentCheckInMethod method = MomentCheckInMethod.manual,
  });

  Future<void> checkOut({
    required String familyId,
    required String instanceId,
    required String memberId,
  });

  Future<MomentInstance> endInstance({
    required String familyId,
    required String instanceId,
    required String endedBy,
  });

  Future<MomentInstance> cancelInstance({
    required String familyId,
    required String instanceId,
    required String cancelledBy,
  });

  Future<MomentInstance> markMissed({
    required String familyId,
    required String instanceId,
    required String updatedBy,
  });
}
