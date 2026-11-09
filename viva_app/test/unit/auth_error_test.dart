// Unit tests for AppAuthError.fromFirebase — all 10 known error codes + unknown.
//
// Run with: flutter test test/unit/auth_error_test.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viva_app/core/auth/auth_error.dart';

void main() {
  group('AppAuthError.fromFirebase', () {
    AppAuthError fromCode(String code) =>
        AppAuthError.fromFirebase(FirebaseAuthException(code: code));

    test('invalid-credential → invalidCredential', () {
      final e = fromCode('invalid-credential');
      expect(e.code, AppAuthErrorCode.invalidCredential);
      expect(e.userMessage, isNotEmpty);
    });

    test('wrong-password → invalidCredential (same user message)', () {
      final e = fromCode('wrong-password');
      expect(e.code, AppAuthErrorCode.invalidCredential);
    });

    test('user-not-found → invalidCredential (never reveal existence)', () {
      final e = fromCode('user-not-found');
      expect(e.code, AppAuthErrorCode.invalidCredential);
    });

    test('email-already-in-use → emailAlreadyInUse', () {
      final e = fromCode('email-already-in-use');
      expect(e.code, AppAuthErrorCode.emailAlreadyInUse);
      expect(e.userMessage, isNotEmpty);
    });

    test('weak-password → weakPassword', () {
      final e = fromCode('weak-password');
      expect(e.code, AppAuthErrorCode.weakPassword);
      expect(e.userMessage, contains('6'));
    });

    test('user-disabled → userDisabled', () {
      final e = fromCode('user-disabled');
      expect(e.code, AppAuthErrorCode.userDisabled);
      expect(e.userMessage, isNotEmpty);
    });

    test('user-token-expired → tokenExpired', () {
      final e = fromCode('user-token-expired');
      expect(e.code, AppAuthErrorCode.tokenExpired);
    });

    test('id-token-expired → tokenExpired', () {
      final e = fromCode('id-token-expired');
      expect(e.code, AppAuthErrorCode.tokenExpired);
    });

    test('requires-recent-login → requiresRecentLogin', () {
      final e = fromCode('requires-recent-login');
      expect(e.code, AppAuthErrorCode.requiresRecentLogin);
    });

    test('too-many-requests → tooManyRequests', () {
      final e = fromCode('too-many-requests');
      expect(e.code, AppAuthErrorCode.tooManyRequests);
    });

    test('network-request-failed → networkError', () {
      final e = fromCode('network-request-failed');
      expect(e.code, AppAuthErrorCode.networkError);
      expect(e.userMessage, contains('internet'));
    });

    test('operation-not-allowed → operationNotAllowed', () {
      final e = fromCode('operation-not-allowed');
      expect(e.code, AppAuthErrorCode.operationNotAllowed);
    });

    test('unknown code → unknown with code in message', () {
      final e = fromCode('some-unknown-firebase-error');
      expect(e.code, AppAuthErrorCode.unknown);
      expect(e.userMessage, contains('some-unknown-firebase-error'));
    });
  });
}
