import '../models/family_moment.dart';
import '../models/member.dart';
import '../models/model_enums.dart';

/// Deterministic personalization rules used before AI wording.
abstract final class MemberRecommendationPolicy {
  static bool canSeeMoment({
    required Member member,
    required FamilyMoment moment,
  }) {
    return member.role == FamilyRole.admin ||
        member.role == FamilyRole.adult ||
        moment.expects(member.id) ||
        moment.isSubject(member.id);
  }

  static bool canStartSharedSession({
    required Member member,
    required FamilyMoment moment,
  }) {
    if (!moment.isSharedSession || moment.isArchived) return false;
    return member.role == FamilyRole.admin || member.role == FamilyRole.adult;
  }

  static bool canManageOccurrence(Member member) {
    return member.role == FamilyRole.admin || member.role == FamilyRole.adult;
  }

  static bool canReceivePreparationAction({
    required Member member,
    required FamilyMoment moment,
  }) {
    if (moment.isSubject(member.id)) return false;
    if (!moment.expects(member.id)) return false;
    return member.role == FamilyRole.admin || member.role == FamilyRole.adult;
  }

  static String whyThisIsForMember({
    required Member member,
    required FamilyMoment moment,
  }) {
    if (moment.isSubject(member.id)) {
      return 'This Moment is about you.';
    }
    if (moment.expects(member.id)) {
      return 'You are expected to take part.';
    }
    if (member.role == FamilyRole.admin || member.role == FamilyRole.adult) {
      return 'You can help manage this family Moment.';
    }
    return 'This Moment is visible to your family.';
  }
}
