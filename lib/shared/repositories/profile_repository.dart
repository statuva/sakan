import 'package:sakan/shared/models/family.dart';
import 'package:sakan/shared/models/hub.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/notification_preferences.dart';
import 'package:sakan/shared/models/schedule_block.dart';

abstract interface class ProfileRepository {
  // Current member
  Stream<Member?> watchMember({
    required String familyId,
    required String memberId,
  });

  Future<void> updateProfile({
    required String familyId,
    required String memberId,
    required String displayName,
    required String? photoUrl,
  });

  // Schedule
  Stream<List<ScheduleBlock>> watchScheduleBlocks({
    required String familyId,
    required String memberId,
  });

  Future<void> createScheduleBlock(ScheduleBlock block);

  Future<void> updateScheduleBlock(ScheduleBlock block);

  Future<void> deleteScheduleBlock({
    required String familyId,
    required String memberId,
    required String blockId,
  });

  // Family time preferences
  Future<void> updatePreferredFamilyTime({
    required String familyId,
    required String memberId,
    required List<int> preferredDays,
    required int preferredStartMinutes,
    required int preferredEndMinutes,
  });

  // Preferred activities
  Future<void> updatePreferredActivities({
    required String familyId,
    required String memberId,
    required List<String> activities,
  });

  // Notifications
  Future<void> updateNotificationPreferences({
    required String familyId,
    required String memberId,
    required NotificationPreferences preferences,
  });

  // Privacy
  Future<void> updatePrivacySettings({
    required String familyId,
    required String memberId,
    required bool aiConsent,
    required bool analyticsConsent,
  });

  // Family
  Stream<Family?> watchFamily(String familyId);

  Future<void> updateFamilyName({
    required String familyId,
    required String familyName,
  });

  // Hub
  Stream<List<Hub>> watchHubs(String familyId);

  Future<void> saveHub(Hub hub);

  Future<void> removeHub({required String familyId, required String hubId});

  Future<void> updateManualCheckIn({
    required String familyId,
    required bool enabled,
  });
}
