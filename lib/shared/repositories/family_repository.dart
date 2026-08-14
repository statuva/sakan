import "package:sakan/shared/models/family.dart";
import "package:sakan/shared/models/member.dart";

abstract interface class FamilyRepository {
  Stream<Family?> watchFamily(String familyId);

  Stream<List<Member>> watchMembers(String familyId);

  Future<String> createFamily(Family family);

  Future<void> updateFamily(Family family);

  Future<void> saveMember(Member member);

  Future<void> removeMember({
    required String familyId,
    required String memberId,
  });
}
