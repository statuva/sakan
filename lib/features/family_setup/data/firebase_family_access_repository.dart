import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:sakan/shared/models/family.dart';
import 'package:sakan/shared/models/family_creation_result.dart';
import 'package:sakan/shared/models/family_invitation.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/repositories/family_access_repository.dart';
import 'package:sakan/shared/services/invitation_code_service.dart';

class FirebaseFamilyAccessRepository implements FamilyAccessRepository {
  FirebaseFamilyAccessRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _codeService = InvitationCodeService(
         firestore ?? FirebaseFirestore.instance,
       );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final InvitationCodeService _codeService;

  User get _currentUser {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('A signed-in user is required.');
    }

    return user;
  }

  @override
  Future<FamilyCreationResult> createFamily({
    required String name,
    required String countryCode,
    required String city,
    required String preferredLanguage,
  }) async {
    try {
      final user = _currentUser;
      final now = DateTime.now().toUtc();

      final familyReference = _firestore.collection('families').doc();

      final invitationCode = await _codeService.generateUniqueCode();

      final family = Family(
        id: familyReference.id,
        name: name.trim(),
        createdBy: user.uid,
        countryCode: countryCode.trim().toUpperCase(),
        city: city.trim(),
        preferredLanguage: preferredLanguage,
        setupComplete: false,
        activeInvitationCode: invitationCode,
        createdAt: now,
        updatedAt: now,
      );

      final adminMember = Member(
        id: user.uid,
        familyId: familyReference.id,
        displayName: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Family Admin',
        role: FamilyRole.admin,
        ageGroup: AgeGroup.adult,
        interests: const [],
        preferredDays: const [],
        isActive: true,
        joinedAt: now,
        updatedAt: now,
      );

      final invitation = FamilyInvitation(
        code: invitationCode,
        familyId: familyReference.id,
        familyName: family.name,
        createdBy: user.uid,
        isActive: true,
        expiresAt: now.add(const Duration(days: 30)),
        createdAt: now,
      );

      final userReference = _firestore.collection('users').doc(user.uid);

      final memberReference = familyReference
          .collection('members')
          .doc(user.uid);

      final invitationReference = _firestore
          .collection('invitations')
          .doc(invitationCode);

      final batch = _firestore.batch();

      batch.set(familyReference, family.toMap());

      batch.set(memberReference, adminMember.toMap());

      batch.set(invitationReference, invitation.toMap());

      batch.set(userReference, {
        'familyIds': FieldValue.arrayUnion([familyReference.id]),
        'currentFamilyId': familyReference.id,
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      await batch.commit();

      return FamilyCreationResult(
        familyId: familyReference.id,
        invitationCode: invitationCode,
      );
    } on FirebaseException catch (error) {
      _throwFirebaseError(
        error,
        fallbackMessage: 'We could not create your family home.',
      );
    }
  }

  @override
  Future<FamilyInvitation?> getInvitation(String code) async {
    try {
      final normalizedCode = InvitationCodeService.normalize(code);

      if (normalizedCode.isEmpty) {
        return null;
      }

      final snapshot = await _firestore
          .collection('invitations')
          .doc(normalizedCode)
          .get();

      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return FamilyInvitation.fromMap(snapshot.id, data);
    } on FirebaseException catch (error) {
      _throwFirebaseError(
        error,
        fallbackMessage: 'We could not verify this invitation.',
      );
    }
  }

  @override
  Future<String> joinFamily({
    required String code,
    required String displayName,
    required FamilyRole role,
    required AgeGroup ageGroup,
  }) async {
    try {
      final user = _currentUser;

      final normalizedCode = InvitationCodeService.normalize(code);

      if (normalizedCode.isEmpty) {
        throw StateError('Enter a valid invitation code.');
      }

      final cleanDisplayName = displayName.trim();

      if (cleanDisplayName.isEmpty) {
        throw StateError('Enter your name before joining.');
      }

      if (role != FamilyRole.child) {
        throw ArgumentError(
          'New members must be confirmed by the family admin.',
        );
      }

      final invitation = await getInvitation(normalizedCode);

      if (invitation == null) {
        throw StateError('The invitation code is invalid.');
      }

      if (!invitation.isActive) {
        throw StateError('This invitation is no longer active.');
      }

      if (invitation.expiresAt.isBefore(DateTime.now().toUtc())) {
        throw StateError('This invitation has expired.');
      }

      final familyReference = _firestore
          .collection('families')
          .doc(invitation.familyId);

      final memberReference = familyReference
          .collection('members')
          .doc(user.uid);

      // The final Firestore rules allow a signed-in user to
      // read only their own prospective membership document.
      final existingMember = await memberReference.get();

      final now = DateTime.now().toUtc();
      final batch = _firestore.batch();

      if (!existingMember.exists) {
        final member = Member(
          id: user.uid,
          familyId: invitation.familyId,
          displayName: cleanDisplayName,
          role: FamilyRole.child,
          ageGroup: ageGroup,
          interests: const [],
          preferredDays: const [],
          isActive: true,
          joinedAt: now,
          updatedAt: now,
        );

        final memberData = Map<String, dynamic>.from(member.toMap());

        memberData['joinedViaInviteCode'] = normalizedCode;

        batch.set(memberReference, memberData);
      }

      batch.set(_firestore.collection('users').doc(user.uid), {
        'familyIds': FieldValue.arrayUnion([invitation.familyId]),
        'currentFamilyId': invitation.familyId,
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      await batch.commit();

      return invitation.familyId;
    } on FirebaseException catch (error) {
      _throwFirebaseError(
        error,
        fallbackMessage: 'We could not join this family home.',
      );
    }
  }

  Never _throwFirebaseError(
    FirebaseException error, {
    required String fallbackMessage,
  }) {
    debugPrint(
      'Firebase family access error '
      '[${error.code}]: ${error.message}',
    );

    switch (error.code) {
      case 'permission-denied':
        throw StateError(
          'The family request was blocked by Firebase permissions. '
          'Deploy the latest Firestore rules and try again.',
        );

      case 'unavailable':
        throw StateError(
          'Firebase is temporarily unavailable. '
          'Check your connection and try again.',
        );

      case 'deadline-exceeded':
        throw StateError('The request took too long. Please try again.');

      case 'unauthenticated':
        throw StateError('Your session has expired. Sign in again.');

      default:
        throw StateError(fallbackMessage);
    }
  }
}
