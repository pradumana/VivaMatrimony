import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../storage/cache_service.dart';
import '../storage/secure_storage.dart';
import 'auth_error.dart';
import 'auth_state.dart';

// ── Interface ─────────────────────────────────────────────────────────────────

abstract interface class AuthRepository {
  /// Single stream covering auth-state changes, sign-in, sign-out, and token
  /// refresh. Backed by [FirebaseAuth.idTokenChanges()].
  Stream<AuthState> authStateChanges();

  /// Register a new account. Sends a verification email automatically.
  /// Throws [AppAuthError] on failure.
  Future<void> register({required String email, required String password});

  /// Send (or resend) the email verification link to the current user.
  /// Throws [AppAuthError] if no user is signed in.
  Future<void> sendVerificationEmail();

  /// Reloads the current Firebase user and checks [emailVerified].
  /// If verified, force-refreshes the ID token so downstream consumers
  /// (Supabase accessToken callback, API client) see the updated state.
  /// Returns true if verified.
  Future<bool> reloadAndCheckVerification();

  /// Sign in with email/password.
  /// Throws [AppAuthError] on failure.
  Future<void> login({required String email, required String password});

  /// Send a password-reset email.
  /// Throws [AppAuthError] on failure.
  Future<void> forgotPassword({required String email});

  /// Sign out the current user and clear local data.
  Future<void> logout();

  /// Returns the current Firebase ID token (cached; refreshes automatically
  /// when within 5 min of expiry). Pass [forceRefresh: true] after
  /// email verification or custom-claim changes.
  Future<String?> getIdToken({bool forceRefresh = false});

  /// The currently signed-in Firebase user, or null if unauthenticated.
  User? get currentFirebaseUser;
}

// ── Implementation ────────────────────────────────────────────────────────────

class FirebaseAuthRepository implements AuthRepository {
  final Ref _ref;

  FirebaseAuthRepository(this._ref);

  @override
  User? get currentFirebaseUser => FirebaseAuth.instance.currentUser;

  @override
  Stream<AuthState> authStateChanges() {
    // idTokenChanges() emits on: sign-in, sign-out, token refresh, user reload.
    // One stream covers everything — no duplicate subscriptions needed.
    return FirebaseAuth.instance.idTokenChanges().asyncMap(_mapUserToState);
  }

  Future<AuthState> _mapUserToState(User? user) async {
    if (user == null) return const AuthState.unauthenticated();

    if (!user.emailVerified) {
      return AuthState(
        status: AuthStatus.emailUnverified,
        userId: user.uid,
        email: user.email,
      );
    }

    // Verified user — fetch onboarding state from secure storage.
    try {
      final storage = _ref.read(secureStorageProvider);
      final onboardingDone = await storage.isOnboardingCompleted();
      final memberId = await storage.getMemberId();
      return AuthState(
        status: onboardingDone
            ? AuthStatus.authenticated
            : AuthStatus.onboardingRequired,
        userId: user.uid,
        email: user.email,
        memberId: memberId,
        onboardingCompleted: onboardingDone,
      );
    } catch (e, stack) {
      debugPrint('[Auth] _mapUserToState storage error: $e');
      try {
        FirebaseCrashlytics.instance.recordError(
          e, stack, reason: '_mapUserToState storage failure',
        );
      } catch (_) {}
      return const AuthState.unauthenticated();
    }
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      // Send verification email immediately after registration.
      await cred.user?.sendEmailVerification();
      // Upsert the users row on the backend (idempotent).
      await _postRegister();
    } on FirebaseAuthException catch (e) {
      throw AppAuthError.fromFirebase(e);
    } on DioException catch (e) {
      // Backend /auth/register failed. Not fatal for auth flow — user row will
      // be created on next login. Log and rethrow as generic error.
      debugPrint('[Auth] register: backend /auth/register failed: $e');
      // Don't rethrow — Firebase account was created; user can verify then log in.
    }
  }

  @override
  Future<void> sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AppAuthError(
        AppAuthErrorCode.unknown,
        'No user is currently signed in.',
      );
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AppAuthError.fromFirebase(e);
    }
  }

  @override
  Future<bool> reloadAndCheckVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed?.emailVerified == true) {
        // Force-refresh the ID token so the Supabase accessToken callback and
        // API client get a token with updated claims immediately.
        await refreshed?.getIdToken(true);
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      throw AppAuthError.fromFirebase(e);
    }
  }

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      // Upsert users row (idempotent) and fetch onboarding state.
      await _postRegister();
      // Register FCM token after login.
      await _registerFcmToken();
    } on FirebaseAuthException catch (e) {
      throw AppAuthError.fromFirebase(e);
    }
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );
    } on FirebaseAuthException catch (e) {
      throw AppAuthError.fromFirebase(e);
    }
  }

  @override
  Future<void> logout() async {
    // Simple logout for Phase 3. Replaced by LogoutService in Phase 7.
    try {
      await CacheService.invalidateAll();
    } catch (_) {}
    try {
      await _ref.read(secureStorageProvider).clearAppData();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      return await FirebaseAuth.instance.currentUser
          ?.getIdToken(forceRefresh);
    } catch (_) {
      return null;
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  /// POST /auth/register — creates/upserts the users row and stores
  /// onboarding state + memberId in secure storage.
  Future<void> _postRegister() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.post('/auth/register');
    final data = response.data as Map<String, dynamic>?;
    if (data != null) {
      final storage = _ref.read(secureStorageProvider);
      final onboardingDone = data['onboarding_completed'] as bool? ?? false;
      final memberId = data['member_id'] as String?;
      if (memberId != null) await storage.saveMemberId(memberId);
      await storage.setOnboardingCompleted(onboardingDone);
    }
  }

  /// Register the FCM token with the backend after login.
  Future<void> _registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _ref.read(apiClientProvider).post(
          '/fcm/token',
          data: {'token': token, 'platform': 'android'},
        );
      }
    } catch (e) {
      // Non-fatal: push notifications won't work until next login, but the
      // user can still use the app.
      debugPrint('[Auth] FCM token registration failed: $e');
    }
  }

  // ── Debug-only token decoder ───────────────────────────────────────────────

  /// Decodes and prints JWT claims to the debug console.
  /// Protected by [assert] so it is a compile-time no-op in release.
  /// Never logs the full token string.
  void debugPrintTokenClaims(String idToken) {
    assert(() {
      try {
        final parts = idToken.split('.');
        if (parts.length < 2) return true;
        final padded = parts[1].padRight(
          (parts[1].length + 3) & ~3,
          '=',
        );
        final decoded = utf8.decode(base64Url.decode(padded));
        debugPrint('[TokenDebug] JWT claims: $decoded');
      } catch (e) {
        debugPrint('[TokenDebug] decode failed: $e');
      }
      return true;
    }());
  }
}
