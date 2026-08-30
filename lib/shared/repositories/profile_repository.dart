import 'package:sakan/shared/models/family.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart' as models;

import 'package:sakan/shared/models/notification_preferences.dart';
import 'package:sakan/shared/models/schedule_block.dart';
import 'package:sakan/shared/models/privacy_preferences.dart';

abstract interface class ProfileRepository {
  Stream<Member?> watchMember({
    required String familyId,
    required String memberId,
  });

  Future<void> updateProfile({
    required String familyId,
    required String memberId,
    required String displayName,
    required models.AgeGroup ageGroup,
    required String? photoUrl,
  });

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

  Future<void> updatePreferredFamilyTime({
    required String familyId,
    required String memberId,
    required List<int> preferredDays,
    required int preferredStartMinutes,
    required int preferredEndMinutes,
  });

  Future<void> updatePreferredActivities({
    required String familyId,
    required String memberId,
    required List<String> activities,
  });

  Future<void> updateFamilyTimePreferences({
    required String familyId,
    required String memberId,
    required List<int> preferredDays,
    required int preferredStartMinutes,
    required int preferredEndMinutes,
    required List<String> activities,
  });

  Future<NotificationPreferences> getNotificationPreferences({
    required String familyId,
    required String memberId,
  });

  Future<void> updateNotificationPreferences({
    required String familyId,
    required String memberId,
    required NotificationPreferences preferences,
  });

  Future<PrivacyPreferences> getPrivacyPreferences({
    required String familyId,
    required String memberId,
  });

  Future<void> updatePrivacySettings({
    required String familyId,
    required String memberId,
    required bool aiConsent,
    required bool analyticsConsent,
  });

  Stream<Family?> watchFamily(String familyId);

  Future<void> updateFamilyName({
    required String familyId,
    required String familyName,
  });
}
