import 'package:sakan/shared/models/family_creation_result.dart';
import 'package:sakan/shared/models/family_invitation.dart';
import 'package:sakan/shared/models/model_enums.dart';

abstract interface class FamilyAccessRepository {
  Future<FamilyCreationResult> createFamily({
    required String name,
    required String countryCode,
    required String city,
    required String preferredLanguage,
  });

  Future<FamilyInvitation?> getInvitation(String code);

  Future<String> joinFamily({
    required String code,
    required String displayName,
    required FamilyRole role,
    required AgeGroup ageGroup,
  });
}
