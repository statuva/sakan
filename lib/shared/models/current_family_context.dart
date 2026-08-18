import 'family.dart';
import 'member.dart';
import 'model_enums.dart';

class CurrentFamilyContext {
  const CurrentFamilyContext({
    required this.userId,
    required this.familyId,
    required this.family,
    required this.member,
  });

  final String userId;
  final String familyId;
  final Family family;
  final Member member;

  bool get isAdmin {
    return member.role == FamilyRole.admin;
  }

  bool get isAdult {
    return member.role == FamilyRole.admin || member.role == FamilyRole.adult;
  }
}
