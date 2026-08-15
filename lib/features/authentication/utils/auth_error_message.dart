import 'package:firebase_auth/firebase_auth.dart';

String authErrorMessage(Object error) {
  if (error is! FirebaseAuthException) {
    return 'Something went wrong. Please try again.';
  }

  return switch (error.code) {
    'email-already-in-use' =>
      'An account already exists for this email address.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Use a stronger password with at least 8 characters.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'The email or password is incorrect.',
    'user-disabled' => 'This account has been disabled.',
    'too-many-requests' => 'Too many attempts. Please wait and try again.',
    'network-request-failed' => 'Check your internet connection and try again.',
    'operation-not-allowed' =>
      'Email and password authentication is not enabled.',
    _ => 'Authentication failed. Please try again.',
  };
}
