import 'package:sakan/features/authentication/data/firebase_auth_repository.dart';
import 'package:sakan/features/calendar/data/firebase_calendar_repository.dart';
import 'package:sakan/features/moments/data/firebase_moment_instance_repository.dart';
import 'package:sakan/features/care/data/firebase_care_action_repository.dart';
import 'package:sakan/features/family_setup/data/firebase_family_access_repository.dart';
import 'package:sakan/features/family_setup/data/firebase_family_setup_repository.dart';
import 'package:sakan/features/memories/data/firebase_memory_repository.dart';
import 'package:sakan/features/profile/data/firebase_profile_repository.dart';
import 'package:sakan/features/profile/data/firebase_schedule_repository.dart';
import 'package:sakan/shared/services/current_family_service.dart';
import 'package:sakan/shared/services/reminder_notification_service.dart';
import 'package:sakan/shared/services/family_insight_service.dart';

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

  static final FirebaseCalendarRepository calendarRepository =
      FirebaseCalendarRepository();

  static final FirebaseMomentInstanceRepository momentInstanceRepository =
      FirebaseMomentInstanceRepository();

  static final FirebaseCareActionRepository careActionRepository =
      FirebaseCareActionRepository();

  static final FirebaseMemoryRepository memoryRepository =
      FirebaseMemoryRepository();

  static final CurrentFamilyService currentFamilyService =
      CurrentFamilyService();

  static final FamilyInsightService familyInsightService = FamilyInsightService(
    currentFamilyService: currentFamilyService,
    calendarRepository: calendarRepository,
    scheduleRepository: scheduleRepository,
    careActionRepository: careActionRepository,
    memoryRepository: memoryRepository,
  );
  static final ReminderNotificationService reminderNotificationService =
      ReminderNotificationService.instance;
}
