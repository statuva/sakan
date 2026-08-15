import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sakan/shared/models/app_user.dart';
import 'package:sakan/shared/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _auth.authStateChanges().asyncExpand((firebaseUser) {
      if (firebaseUser == null) {
        return Stream<AppUser?>.value(null);
      }

      return _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots()
          .map((snapshot) {
            final data = snapshot.data();

            if (!snapshot.exists || data == null) {
              return null;
            }

            return AppUser.fromMap(snapshot.id, data);
          });
    });
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw StateError('Firebase did not return a user account.');
    }

    final cleanName = displayName.trim();
    await firebaseUser.updateDisplayName(cleanName);

    final now = DateTime.now().toUtc();

    final appUser = AppUser(
      id: firebaseUser.uid,
      email: email.trim().toLowerCase(),
      displayName: cleanName,
      familyIds: const [],
      createdAt: now,
      updatedAt: now,
    );

    await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .set(appUser.toMap());

    return appUser;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw StateError('Firebase did not return a user account.');
    }

    final userReference = _firestore.collection('users').doc(firebaseUser.uid);

    final userSnapshot = await userReference.get();
    final existingData = userSnapshot.data();

    if (userSnapshot.exists && existingData != null) {
      return AppUser.fromMap(userSnapshot.id, existingData);
    }

    final now = DateTime.now().toUtc();

    final appUser = AppUser(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? email.trim().toLowerCase(),
      displayName: firebaseUser.displayName ?? 'Sakan Member',
      familyIds: const [],
      createdAt: now,
      updatedAt: now,
    );

    await userReference.set(appUser.toMap());

    return appUser;
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
}
