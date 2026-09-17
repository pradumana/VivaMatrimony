import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';

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

  // ── Registration ───────────────────────────────────────────────────────────

  Future<void> register({
    required String email,
    required String password,
    required void Function() onEmailConfirmationRequired,
    required void Function() onSuccess,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      dev.log('🔵 Registration: Starting for $email', name: 'Auth');

      final response = await Supabase.instance.client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: 'https://vivamatrimony.in/auth/callback',
      );

      dev.log('🟢 Supabase signUp OK. Session: ${response.session != null}', name: 'Auth');

      if (response.session == null) {
        dev.log('📧 Email confirmation required', name: 'Auth');
        state = state.copyWith(isLoading: false);
        onEmailConfirmationRequired();
        return;
      }

      dev.log('🔵 Calling backend POST /auth/register', name: 'Auth');
      await _postRegister();
      dev.log('✅ Registration complete', name: 'Auth');
      state = state.copyWith(isLoading: false);
      onSuccess();
    } on AuthException catch (e, stack) {
      dev.log('❌ AuthException: ${e.message}', name: 'Auth', error: e, stackTrace: stack);
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'Registration AuthException');
      state = state.copyWith(isLoading: false, error: _authError(e.message));
    } on DioException catch (e, stack) {
      final apiError = ApiException.fromDioError(e);
      dev.log('❌ DioException: ${apiError.message} (${apiError.statusCode})', name: 'Auth', error: e, stackTrace: stack);
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'Registration DioException');
      state = state.copyWith(isLoading: false, error: apiError.message);
    } catch (e, stack) {
      dev.log('❌ Unexpected registration error', name: 'Auth', error: e, stackTrace: stack);
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'Registration unexpected error', fatal: true);
      state = state.copyWith(isLoading: false, error: 'Error: ${e.toString()}');
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
      dev.log('🔵 Login: Starting for $email', name: 'Auth');

      await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      dev.log('🟢 Supabase signIn OK', name: 'Auth');
      dev.log('🔵 Calling backend POST /auth/register', name: 'Auth');

      // Create/update users row idempotently
      await _postRegister();
      dev.log('✅ Login complete', name: 'Auth');
      state = state.copyWith(isLoading: false);
      onSuccess();
    } on AuthException catch (e, stack) {
      dev.log('❌ Login AuthException: ${e.message}', name: 'Auth', error: e);
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'Login AuthException');
      state = state.copyWith(isLoading: false, error: _authError(e.message));
    } on DioException catch (e, stack) {
      final apiError = ApiException.fromDioError(e);
      dev.log('❌ Login DioException: ${apiError.message}', name: 'Auth', error: e);
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'Login DioException');
      state = state.copyWith(isLoading: false, error: apiError.message);
    } catch (e, stack) {
      dev.log('❌ Unexpected login error', name: 'Auth', error: e, stackTrace: stack);
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'Login unexpected error', fatal: true);
      state = state.copyWith(isLoading: false, error: 'Error: ${e.toString()}');
    }
  }

  // ── Password reset ─────────────────────────────────────────────────────────

  Future<void> sendPasswordReset({
    required String email,
    required void Function() onSuccess,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: 'https://vivamatrimony.in/auth/callback',
      );
      state = state.copyWith(isLoading: false);
      onSuccess();
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authError(e.message));
    } catch (_) {
      state = state.copyWith(
          isLoading: false, error: 'Could not send reset email. Please try again.');
    }
  }

  // ── Shared ─────────────────────────────────────────────────────────────────

  void clearError() => state = state.copyWith(clearError: true);

  /// Call POST /auth/register to create/get the users row, then update
  /// the auth provider with onboarding state and memberId.
  Future<void> _postRegister() async {
    final client = ref.read(apiClientProvider);
    final response = await client.post('/auth/register');
    final data = response.data as Map<String, dynamic>;

    await ref.read(authProvider.notifier).onLoginSuccess(
          onboardingCompleted: data['onboarding_completed'] as bool? ?? false,
          memberId: data['member_id'] as String?,
        );
  }

  /// Maps raw Supabase AuthException messages to user-friendly strings.
  /// Never expose internal details.
  String _authError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials') ||
        msg.contains('wrong password') || msg.contains('invalid email or password')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email before logging in.';
    }
    if (msg.contains('already registered') || msg.contains('already exists') ||
        msg.contains('user already')) {
      return 'An account with this email already exists. Please log in.';
    }
    if (msg.contains('password should be at least') ||
        msg.contains('weak password')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (msg.contains('network') || msg.contains('connection') ||
        msg.contains('timeout') || msg.contains('fetch')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('user not found') || msg.contains('no user found')) {
      // Don't reveal whether email exists — generic message
      return 'Incorrect email or password.';
    }
    return 'Something went wrong. Please try again.';
  }
}

final authScreenProvider =
    NotifierProvider<AuthScreenNotifier, AuthScreenState>(
  AuthScreenNotifier.new,
);
