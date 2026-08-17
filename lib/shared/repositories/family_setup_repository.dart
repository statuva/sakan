import '../models/family.dart';
import '../models/member.dart';
import '../models/model_enums.dart';
import '../models/rhythm_setup_draft.dart';

abstract interface class FamilySetupRepository {
  Stream<Family?> watchFamily(String familyId);

  Stream<List<Member>> watchMembers(String familyId);

  Future<void> updateMemberRelationship({
    required String familyId,
    required String memberId,
    required FamilyRelationship relationship,
  });

  Future<void> completeSetup({
    required String familyId,
    required List<RhythmSetupDraft> rhythms,
  });
}
