import "package:sakan/shared/models/app_user.dart";

abstract interface class AuthRepository {
  Stream<AppUser?> watchCurrentUser();

  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AppUser> signIn({required String email, required String password});

  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
}
