import 'package:sakan/features/authentication/data/firebase_auth_repository.dart';
import 'package:sakan/features/family_setup/data/firebase_family_access_repository.dart';
import 'package:sakan/features/family_setup/data/firebase_family_setup_repository.dart';
import 'package:sakan/features/profile/data/firebase_profile_repository.dart';
import 'package:sakan/shared/services/current_family_service.dart';
import 'package:sakan/features/profile/data/firebase_schedule_repository.dart';

abstract final class AppDependencies {
  static final FirebaseAuthRepository authRepository = FirebaseAuthRepository();

  static final FirebaseFamilyAccessRepository familyAccessRepository =
      FirebaseFamilyAccessRepository();

  static final FirebaseFamilySetupRepository familySetupRepository =
      FirebaseFamilySetupRepository();

  static final FirebaseProfileRepository profileRepository =
      FirebaseProfileRepository();

  static final FirebaseScheduleRepository scheduleRepository =
      FirebaseScheduleRepository();

  static final CurrentFamilyService currentFamilyService =
      CurrentFamilyService();
}
