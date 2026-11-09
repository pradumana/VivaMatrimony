// DEPRECATED — do not use in new code.
// Replaced by: lib/core/auth/auth_repository.dart (FirebaseAuthRepository)
// Rewired in Phase 3 to delegate to AuthRepository.
// Will be deleted in Phase 8 after device verification.

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/firebase_auth_provider.dart';

class AuthScreenState {
  final bool isLoading;
  final String? error;

  const AuthScreenState({this.isLoading = false, this.error});

  AuthScreenState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      AuthScreenState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthScreenNotifier extends Notifier<AuthScreenState> {
  @override
  AuthScreenState build() => const AuthScreenState();

  void reset() => state = const AuthScreenState();

  // ── Registration ───────────────────────────────────────────────────────────

  Future<void> register({
    required String email,
    required String password,
    // onEmailConfirmationRequired is now handled by the router redirecting to
    // the EmailVerificationScreen when authProvider emits emailUnverified.
    required void Function() onEmailConfirmationRequired,
    required void Function() onSuccess,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(authRepositoryProvider).register(
        email: email,
        password: password,
      );
      // After registration, Firebase emits emailUnverified on idTokenChanges.
      // The router redirects automatically — no manual navigation needed.
      state = state.copyWith(isLoading: false);
      // Call onSuccess so callers that navigate manually still work.
      onSuccess();
    } on AppAuthError catch (e) {
      state = state.copyWith(isLoading: false, error: e.userMessage);
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e, stack, reason: 'Registration unexpected error', fatal: true,
      );
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Please try again.',
      );
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<void> login({
    required String email,
    required String password,
    required void Function() onSuccess,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(authRepositoryProvider).login(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false);
      onSuccess();
    } on AppAuthError catch (e) {
      state = state.copyWith(isLoading: false, error: e.userMessage);
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e, stack, reason: 'Login unexpected error', fatal: true,
      );
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Please try again.',
      );
    }
  }

  // ── Password reset ─────────────────────────────────────────────────────────

  Future<void> sendPasswordReset({
    required String email,
    required void Function() onSuccess,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email: email);
      state = state.copyWith(isLoading: false);
      onSuccess();
    } on AppAuthError catch (e) {
      state = state.copyWith(isLoading: false, error: e.userMessage);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not send reset email. Please try again.',
      );
    }
  }

  // ── Shared ─────────────────────────────────────────────────────────────────

  void clearError() => state = state.copyWith(clearError: true);
}

final authScreenProvider =
    NotifierProvider<AuthScreenNotifier, AuthScreenState>(
  AuthScreenNotifier.new,
);
