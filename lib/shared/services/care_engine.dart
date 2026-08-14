import 'package:sakan/shared/models/care_action.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/member.dart';

abstract interface class CareEngine {
  List<CareAction> generateActions({
    required FamilyMoment moment,
    required List<Member> members,
    required DateTime now,
  });
}
