import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:sakan/shared/models/family.dart';
import "package:sakan/shared/models/member.dart";
import "package:sakan/shared/models/model_enums.dart" as models;
import 'package:sakan/shared/models/notification_preferences.dart';
import 'package:sakan/shared/models/schedule_block.dart';
import 'package:sakan/shared/models/privacy_preferences.dart';
import 'package:sakan/shared/repositories/profile_repository.dart';

class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _memberReference({
    required String familyId,
    required String memberId,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(memberId);
  }

  @override
  Stream<Member?> watchMember({
    required String familyId,
    required String memberId,
  }) {
    return _memberReference(
      familyId: familyId,
      memberId: memberId,
    ).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return Member.fromMap(snapshot.id, data);
    });
  }

  @override
  Future<void> updateProfile({
    required String familyId,
    required String memberId,
    required String displayName,
    required models.AgeGroup ageGroup,
    required String? photoUrl,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('A signed-in user is required.');
    }

    if (currentUser.uid != memberId) {
      throw StateError('You may update only your own profile.');
    }

    final cleanDisplayName = displayName.trim();

    if (cleanDisplayName.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }

    final now = DateTime.now().toUtc();

    final batch = _firestore.batch();

    batch.update(_memberReference(familyId: familyId, memberId: memberId), {
      'displayName': cleanDisplayName,
      'ageGroup': ageGroup.name,
      'photoUrl': photoUrl,
      'updatedAt': Timestamp.fromDate(now),
    });

    batch.set(_firestore.collection('users').doc(memberId), {
      'displayName': cleanDisplayName,
      'photoUrl': photoUrl,
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    await batch.commit();

    try {
      await currentUser.updateDisplayName(cleanDisplayName);
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'Could not synchronize Firebase Auth '
        'display name: ${error.code}',
      );
    }
  }

  @override
  Stream<List<ScheduleBlock>> watchScheduleBlocks({
    required String familyId,
    required String memberId,
  }) {
    return _memberReference(
      familyId: familyId,
      memberId: memberId,
    ).collection('scheduleBlocks').snapshots().map((snapshot) {
      final blocks = snapshot.docs
          .map(
            (document) => ScheduleBlock.fromMap(document.id, document.data()),
          )
          .toList();

      blocks.sort((first, second) {
        final dayComparison = first.dayOfWeek.compareTo(second.dayOfWeek);

        if (dayComparison != 0) {
          return dayComparison;
        }

        return first.startMinutes.compareTo(second.startMinutes);
      });

      return blocks;
    });
  }

  @override
  Future<void> createScheduleBlock(ScheduleBlock block) {
    return _memberReference(
      familyId: block.familyId,
      memberId: block.memberId,
    ).collection('scheduleBlocks').doc(block.id).set(block.toMap());
  }

  @override
  Future<void> updateScheduleBlock(ScheduleBlock block) {
    return _memberReference(
      familyId: block.familyId,
      memberId: block.memberId,
    ).collection('scheduleBlocks').doc(block.id).update(block.toMap());
  }

  @override
  Future<void> deleteScheduleBlock({
    required String familyId,
    required String memberId,
    required String blockId,
  }) {
    return _memberReference(
      familyId: familyId,
      memberId: memberId,
    ).collection('scheduleBlocks').doc(blockId).delete();
  }

  @override
  Future<void> updatePreferredFamilyTime({
    required String familyId,
    required String memberId,
    required List<int> preferredDays,
    required int preferredStartMinutes,
    required int preferredEndMinutes,
  }) {
    return _memberReference(familyId: familyId, memberId: memberId).update({
      'preferredDays': preferredDays,
      'preferredStartMinutes': preferredStartMinutes,
      'preferredEndMinutes': preferredEndMinutes,
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> updatePreferredActivities({
    required String familyId,
    required String memberId,
    required List<String> activities,
  }) {
    return _memberReference(
      familyId: familyId,
      memberId: memberId,
    ).update({'interests': activities, 'updatedAt': Timestamp.now()});
  }

  @override
  Future<void> updateFamilyTimePreferences({
    required String familyId,
    required String memberId,
    required List<int> preferredDays,
    required int preferredStartMinutes,
    required int preferredEndMinutes,
    required List<String> activities,
  }) {
    return _memberReference(familyId: familyId, memberId: memberId).update({
      'preferredDays': preferredDays,
      'preferredStartMinutes': preferredStartMinutes,
      'preferredEndMinutes': preferredEndMinutes,
      'interests': activities,
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String familyId,
    required String memberId,
  }) async {
    final snapshot = await _memberReference(
      familyId: familyId,
      memberId: memberId,
    ).get();

    final data = snapshot.data();

    final rawPreferences = data?['notificationPreferences'];

    final preferencesMap = rawPreferences is Map
        ? Map<String, dynamic>.from(rawPreferences)
        : null;

    return NotificationPreferences.fromMap(preferencesMap);
  }

  @override
  Future<void> updateNotificationPreferences({
    required String familyId,
    required String memberId,
    required NotificationPreferences preferences,
  }) {
    return _memberReference(familyId: familyId, memberId: memberId).update({
      'notificationPreferences': preferences.toMap(),
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<PrivacyPreferences> getPrivacyPreferences({
    required String familyId,
    required String memberId,
  }) async {
    final snapshot = await _memberReference(
      familyId: familyId,
      memberId: memberId,
    ).get();

    final data = snapshot.data();

    final rawPreferences = data?['privacyConsent'];

    final preferencesMap = rawPreferences is Map
        ? Map<String, dynamic>.from(rawPreferences)
        : null;

    return PrivacyPreferences.fromMap(preferencesMap);
  }

  @override
  Future<void> updatePrivacySettings({
    required String familyId,
    required String memberId,
    required bool aiConsent,
    required bool analyticsConsent,
  }) {
    return _memberReference(familyId: familyId, memberId: memberId).update({
      'privacyConsent': {
        'aiConsent': aiConsent,
        'analyticsConsent': analyticsConsent,
        'updatedAt': Timestamp.now(),
      },
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Stream<Family?> watchFamily(String familyId) {
    return _firestore.collection('families').doc(familyId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return Family.fromMap(snapshot.id, data);
    });
  }

  @override
  Future<void> updateFamilyName({
    required String familyId,
    required String familyName,
  }) {
    final cleanFamilyName = familyName.trim();

    if (cleanFamilyName.isEmpty) {
      throw ArgumentError('Family name cannot be empty.');
    }

    return _firestore.collection('families').doc(familyId).update({
      'name': cleanFamilyName,
      'updatedAt': Timestamp.now(),
    });
  }
}
