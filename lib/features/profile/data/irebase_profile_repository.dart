import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sakan/shared/models/family.dart';
import 'package:sakan/shared/models/hub.dart';
import "package:sakan/shared/models/member.dart";
import 'package:sakan/shared/models/notification_preferences.dart';
import 'package:sakan/shared/models/schedule_block.dart';
import 'package:sakan/shared/repositories/profile_repository.dart';

class FirebaseProfileRepository
    implements ProfileRepository {
  FirebaseProfileRepository({
    FirebaseFirestore? firestore,
  }) : _firestore =
           firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<Member?> watchMember({
    required String familyId,
    required String memberId,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(memberId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;

      return Member.fromMap(
        snapshot.id,
        snapshot.data()!,
      );
    });
  }

  @override
  Future<void> updateProfile({
    required String familyId,
    required String memberId,
    required String displayName,
    required String? photoUrl,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(memberId)
        .update({
      'displayName': displayName,
      'photoUrl': photoUrl,
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Stream<List<ScheduleBlock>> watchScheduleBlocks({
    required String familyId,
    required String memberId,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(memberId)
        .collection('scheduleBlocks')
        .orderBy('dayOfWeek')
        .orderBy('startMinutes')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => ScheduleBlock.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .toList();
    });
  }

  @override
  Future<void> createScheduleBlock(
    ScheduleBlock block,
  ) {
    return _firestore
        .collection('families')
        .doc(block.familyId)
        .collection('members')
        .doc(block.memberId)
        .collection('scheduleBlocks')
        .doc(block.id)
        .set(block.toMap());
  }

  @override
  Future<void> updateScheduleBlock(
    ScheduleBlock block,
  ) {
    return _firestore
        .collection('families')
        .doc(block.familyId)
        .collection('members')
        .doc(block.memberId)
        .collection('scheduleBlocks')
        .doc(block.id)
        .update(block.toMap());
  }

  @override
  Future<void> deleteScheduleBlock({
    required String familyId,
    required String memberId,
    required String blockId,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(memberId)
        .collection('scheduleBlocks')
        .doc(blockId)
        .delete();
  }

  @override
  Future<void> updatePreferredFamilyTime({
    required String familyId,
    required String memberId,
    required List<int> preferredDays,
    required int preferredStartMinutes,
    required int preferredEndMinutes,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(memberId)
        .update({
      'preferredDays': preferredDays,
      'preferredStartMinutes':
          preferredStartMinutes,
      'preferredEndMinutes':
          preferredEndMinutes,
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> updatePreferredActivities({
    required String familyId,
    required String memberId,
    required List<String> activities,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(memberId)
        .update({
      'interests': activities,
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> updateNotificationPreferences({
    required String familyId,
    required String memberId,
    required NotificationPreferences preferences,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(memberId)
        .update({
      'notificationPreferences':
          preferences.toMap(),
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> updatePrivacySettings({
    required String familyId,
    required String memberId,
    required bool aiConsent,
    required bool analyticsConsent,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(memberId)
        .update({
      'privacyConsent': {
        'aiConsent': aiConsent,
        'analyticsConsent':
            analyticsConsent,
      },
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Stream<Family?> watchFamily(
    String familyId,
  ) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;

      return Family.fromMap(
        snapshot.id,
        snapshot.data()!,
      );
    });
  }

  @override
  Future<void> updateFamilyName({
    required String familyId,
    required String familyName,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .update({
      'name': familyName,
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Stream<List<Hub>> watchHubs(
    String familyId,
  ) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('hubs')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(
            (doc) =>
                Hub.fromMap(doc.id, doc.data()),
          )
          .toList();
    });
  }

  @override
  Future<void> saveHub(Hub hub) {
    return _firestore
        .collection('families')
        .doc(hub.familyId)
        .collection('hubs')
        .doc(hub.id)
        .set(hub.toMap());
  }

  @override
  Future<void> removeHub({
    required String familyId,
    required String hubId,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('hubs')
        .doc(hubId)
        .delete();
  }

  @override
  Future<void> updateManualCheckIn({
    required String familyId,
    required bool enabled,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .update({
      'manualCheckInEnabled':
          enabled,
      'updatedAt': Timestamp.now(),
    });
  }
}