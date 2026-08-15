import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      createdAt: now,
      updatedAt: now,
    );

    final adminMember = Member(
      id: user.uid,
      familyId: familyReference.id,
      displayName: user.displayName ?? 'Family Admin',
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

    final memberReference = familyReference.collection('members').doc(user.uid);

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
  }

  @override
  Future<FamilyInvitation?> getInvitation(String code) async {
    final normalizedCode = InvitationCodeService.normalize(code);

    final snapshot = await _firestore
        .collection('invitations')
        .doc(normalizedCode)
        .get();

    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return FamilyInvitation.fromMap(snapshot.id, data);
  }

  @override
  Future<String> joinFamily({
    required String code,
    required String displayName,
    required FamilyRole role,
    required AgeGroup ageGroup,
  }) async {
    final user = _currentUser;
    final normalizedCode = InvitationCodeService.normalize(code);

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

    if (role == FamilyRole.admin) {
      throw ArgumentError('Joining members cannot assign themselves as admin.');
    }

    final familyReference = _firestore
        .collection('families')
        .doc(invitation.familyId);

    final memberReference = familyReference.collection('members').doc(user.uid);

    final existingMember = await memberReference.get();

    final now = DateTime.now().toUtc();
    final batch = _firestore.batch();

    if (!existingMember.exists) {
      final member = Member(
        id: user.uid,
        familyId: invitation.familyId,
        displayName: displayName.trim(),
        role: role,
        ageGroup: ageGroup,
        interests: const [],
        preferredDays: const [],
        isActive: true,
        joinedAt: now,
        updatedAt: now,
      );

      final memberData = member.toMap();
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
  }
}
