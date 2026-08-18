import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:sakan/shared/models/current_family_context.dart';
import 'package:sakan/shared/models/family.dart';
import 'package:sakan/shared/models/member.dart';

class CurrentFamilyService {
  CurrentFamilyService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<CurrentFamilyContext> load() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw StateError('A signed-in user is required.');
    }

    final userSnapshot = await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    final userData = userSnapshot.data();

    if (userData == null) {
      throw StateError('The Sakan user profile could not be found.');
    }

    final familyId = userData['currentFamilyId'] as String?;

    if (familyId == null || familyId.trim().isEmpty) {
      throw StateError('No family is currently selected.');
    }

    final familySnapshot = await _firestore
        .collection('families')
        .doc(familyId)
        .get();

    final familyData = familySnapshot.data();

    if (!familySnapshot.exists || familyData == null) {
      throw StateError('The selected family could not be found.');
    }

    final memberSnapshot = await _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(firebaseUser.uid)
        .get();

    final memberData = memberSnapshot.data();

    if (!memberSnapshot.exists || memberData == null) {
      throw StateError('Your family membership could not be found.');
    }

    return CurrentFamilyContext(
      userId: firebaseUser.uid,
      familyId: familyId,
      family: Family.fromMap(familySnapshot.id, familyData),
      member: Member.fromMap(memberSnapshot.id, memberData),
    );
  }

  Stream<Member?> watchCurrentMember({
    required String familyId,
    required String userId,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();

          if (!snapshot.exists || data == null) {
            return null;
          }

          return Member.fromMap(snapshot.id, data);
        });
  }

  Stream<Family?> watchCurrentFamily(String familyId) {
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

  Stream<List<Member>> watchFamilyMembers(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final members = snapshot.docs
              .map((document) => Member.fromMap(document.id, document.data()))
              .toList();

          members.sort(
            (first, second) => first.displayName.compareTo(second.displayName),
          );

          return members;
        });
  }
}
