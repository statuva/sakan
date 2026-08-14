import "package:sakan/shared/models/family_moment.dart";
import "package:sakan/shared/models/moment_instance.dart";

abstract interface class MomentRepository {
  Stream<List<FamilyMoment>> watchMoments(String familyId);

  Stream<List<MomentInstance>> watchMomentInstances({
    required String familyId,
    required String momentId,
  });

  Future<FamilyMoment?> getMoment({
    required String familyId,
    required String momentId,
  });

  Future<void> createMoment(FamilyMoment moment);
  Future<void> updateMoment(FamilyMoment moment);
  Future<void> deleteMoment({
    required String familyId,
    required String momentId,
  });

  Future<void> saveMomentInstance(MomentInstance instance);
}
