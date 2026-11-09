import 'package:firebase_auth/firebase_auth.dart';

/// Typed auth error codes covering all FirebaseAuthException codes
/// the app handles explicitly.
enum AppAuthErrorCode {
  invalidCredential,
  userNotFound,
  wrongPassword,
  emailAlreadyInUse,
  weakPassword,
  userDisabled,
  tokenExpired,
  requiresRecentLogin,
  tooManyRequests,
  networkError,
  operationNotAllowed,
  unknown,
}

class AppAuthError implements Exception {
  final AppAuthErrorCode code;
  final String userMessage;

  const AppAuthError(this.code, this.userMessage);

  /// Maps a [FirebaseAuthException] to a typed [AppAuthError] with a
  /// user-friendly message. Never exposes internal Firebase error details.
  factory AppAuthError.fromFirebase(FirebaseAuthException e) {
    return switch (e.code) {
      // Invalid credentials — combine into one message to avoid
      // confirming whether an email address is registered.
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        const AppAuthError(
          AppAuthErrorCode.invalidCredential,
          'Incorrect email or password.',
        ),
      'email-already-in-use' => const AppAuthError(
          AppAuthErrorCode.emailAlreadyInUse,
          'An account with this email already exists. Please log in.',
        ),
      'weak-password' => const AppAuthError(
          AppAuthErrorCode.weakPassword,
          'Password must be at least 6 characters.',
        ),
      'user-disabled' => const AppAuthError(
          AppAuthErrorCode.userDisabled,
          'This account has been disabled. Please contact support.',
        ),
      'user-token-expired' || 'id-token-expired' => const AppAuthError(
          AppAuthErrorCode.tokenExpired,
          'Session expired. Please log in again.',
        ),
      'requires-recent-login' => const AppAuthError(
          AppAuthErrorCode.requiresRecentLogin,
          'Please log in again to continue.',
        ),
      'too-many-requests' => const AppAuthError(
          AppAuthErrorCode.tooManyRequests,
          'Too many attempts. Please wait a moment and try again.',
        ),
      'network-request-failed' => const AppAuthError(
          AppAuthErrorCode.networkError,
          'No internet connection. Please check your network.',
        ),
      'operation-not-allowed' => const AppAuthError(
          AppAuthErrorCode.operationNotAllowed,
          'This sign-in method is not enabled. Please contact support.',
        ),
      _ => AppAuthError(
          AppAuthErrorCode.unknown,
          'Something went wrong. Please try again. (${e.code})',
        ),
    };
  }

  @override
  String toString() => 'AppAuthError($code): $userMessage';
}
