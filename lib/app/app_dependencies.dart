import 'package:sakan/features/authentication/data/firebase_auth_repository.dart';
import 'package:sakan/features/calendar/data/firebase_calendar_repository.dart';
import 'package:sakan/features/care/data/firebase_care_action_repository.dart';
import 'package:sakan/features/daily_review/data/firebase_daily_review_repository.dart';
import 'package:sakan/features/digital_twin/services/remote_twin_ai_scenario_parser.dart';
import 'package:sakan/features/digital_twin/services/twin_ai_scenario_parser.dart';
import 'package:sakan/features/digital_twin/services/twin_simulation_narrative_service.dart';
import 'package:sakan/features/digital_twin/services/twin_family_narrative_service.dart';
import 'package:sakan/features/family_setup/data/firebase_family_access_repository.dart';
import 'package:sakan/features/family_setup/data/firebase_family_setup_repository.dart';
import 'package:sakan/features/memories/data/firebase_memory_repository.dart';
import 'package:sakan/features/moments/data/non_destructive_firebase_moment_instance_repository.dart';
import 'package:sakan/features/profile/data/firebase_profile_repository.dart';
import 'package:sakan/features/profile/data/firebase_schedule_repository.dart';
import 'package:sakan/features/rhythm/data/firebase_rhythm_repository.dart';
import 'package:sakan/shared/ai/ai_family_insight_service.dart';
import 'package:sakan/shared/ai/firebase_sakan_ai_gateway.dart';
import 'package:sakan/shared/ai/sakan_ai_gateway.dart';
import 'package:sakan/shared/services/current_family_service.dart';
import 'package:sakan/shared/services/family_insight_service.dart';
import 'package:sakan/shared/services/moment_instance_migration_service.dart';
import 'package:sakan/shared/services/moment_outcome_service.dart';
import 'package:sakan/shared/services/reminder_notification_service.dart';
import 'package:sakan/shared/services/rhythm_update_service.dart';

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

  static final NonDestructiveFirebaseMomentInstanceRepository
  momentInstanceRepository = NonDestructiveFirebaseMomentInstanceRepository();

  static final FirebaseCareActionRepository careActionRepository =
      FirebaseCareActionRepository();

  static final FirebaseMemoryRepository memoryRepository =
      FirebaseMemoryRepository();

  static final FirebaseRhythmRepository rhythmRepository =
      FirebaseRhythmRepository();

  static final FirebaseDailyReviewRepository dailyReviewRepository =
      FirebaseDailyReviewRepository();

  static final CurrentFamilyService currentFamilyService =
      CurrentFamilyService();

  static final SakanAiGateway sakanAiGateway = FirebaseSakanAiGateway(
    currentFamilyService: currentFamilyService,
    profileRepository: profileRepository,
  );

  static final AiFamilyInsightService aiFamilyInsightService =
      AiFamilyInsightService(gateway: sakanAiGateway);

  static final TwinAiScenarioParser twinAiScenarioParser =
      RemoteTwinAiScenarioParser(gateway: sakanAiGateway);

  static final TwinSimulationNarrativeService twinSimulationNarrativeService =
      TwinSimulationNarrativeService(gateway: sakanAiGateway);

  static final TwinFamilyNarrativeService twinFamilyNarrativeService =
      TwinFamilyNarrativeService(gateway: sakanAiGateway);

  static void clearAiCaches() {
    aiFamilyInsightService.clear();
    twinFamilyNarrativeService.clear();
  }

  static final ReminderNotificationService reminderNotificationService =
      ReminderNotificationService.instance;

  static final MomentInstanceMigrationService momentInstanceMigrationService =
      MomentInstanceMigrationService(
        calendarRepository: calendarRepository,
        momentInstanceRepository: momentInstanceRepository,
      );

  static final RhythmUpdateService rhythmUpdateService = RhythmUpdateService(
    calendarRepository: calendarRepository,
    momentInstanceRepository: momentInstanceRepository,
    rhythmRepository: rhythmRepository,
  );

  static final MomentOutcomeService momentOutcomeService = MomentOutcomeService(
    calendarRepository: calendarRepository,
    momentInstanceRepository: momentInstanceRepository,
    rhythmUpdateService: rhythmUpdateService,
  );

  static final FamilyInsightService familyInsightService = FamilyInsightService(
    currentFamilyService: currentFamilyService,
    calendarRepository: calendarRepository,
    momentInstanceRepository: momentInstanceRepository,
    scheduleRepository: scheduleRepository,
    careActionRepository: careActionRepository,
    memoryRepository: memoryRepository,
  );
}
