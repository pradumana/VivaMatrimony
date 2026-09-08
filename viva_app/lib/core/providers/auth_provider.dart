import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/api_client.dart';
import '../storage/secure_storage.dart';

/// Auth states that drive all routing decisions.
enum AuthStatus {
  loading,
  unauthenticated,
  onboardingRequired,
  authenticated,
}

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? email;
  final String? memberId;
  final bool onboardingCompleted;

  const AuthState({
    required this.status,
    this.userId,
    this.email,
    this.memberId,
    this.onboardingCompleted = false,
  });

  const AuthState.loading()
      : status = AuthStatus.loading,
        userId = null,
        email = null,
        memberId = null,
        onboardingCompleted = false;

  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        userId = null,
        email = null,
        memberId = null,
        onboardingCompleted = false;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? email,
    String? memberId,
    bool? onboardingCompleted,
  }) =>
      AuthState(
        status: status ?? this.status,
        userId: userId ?? this.userId,
        email: email ?? this.email,
        memberId: memberId ?? this.memberId,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      );
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // Listen to Supabase auth state changes and refresh our state.
    // The stream fires immediately with the current session on startup.
    final sub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        final event = data.event;
        final session = data.session;

        if (event == AuthChangeEvent.signedOut ||
            session == null) {
          await ref.read(secureStorageProvider).clearAppData();
          state = const AsyncValue.data(AuthState.unauthenticated());
          return;
        }

        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.initialSession) {
          // signedIn fires after email confirmation (deep-link callback) as
          // well as direct login. Ensure the users row exists BEFORE we set
          // auth state — the router will redirect to onboarding screens which
          // immediately call /profile, so the row must exist first.
          if (event == AuthChangeEvent.signedIn) {
            await _ensureUserRow(session);
            // _ensureUserRow already calls onLoginSuccess which sets state.
            return;
          }
          final newState = await _stateFromSession(session);
          state = AsyncValue.data(newState);
        }
      },
    );
    // Cancel subscription when this provider is disposed
    ref.onDispose(sub.cancel);

    // Derive initial state from whatever session Supabase SDK has on disk
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const AuthState.unauthenticated();
    return _stateFromSession(session);
  }

  /// Ensures the users row exists in the backend DB, then sets auth state.
  /// Called on signedIn — blocks navigation until the row is confirmed.
  Future<void> _ensureUserRow(Session session) async {
    try {
      final response = await ref.read(apiClientProvider).post('/auth/register');
      final data = response.data as Map<String, dynamic>?;
      final storage = ref.read(secureStorageProvider);
      if (data != null) {
        final onboardingDone = data['onboarding_completed'] as bool? ?? false;
        final memberId = data['member_id'] as String?;
        if (memberId != null) await storage.saveMemberId(memberId);
        await storage.setOnboardingCompleted(onboardingDone);
      }
    } on DioException catch (e) {
      // If register itself 401s the token is invalid — sign out.
      // For any other network error, proceed with local state (row may
      // already exist for returning users).
      final status = e.response?.statusCode;
      if (status == 401) {
        await Supabase.instance.client.auth.signOut();
        state = const AsyncValue.data(AuthState.unauthenticated());
        return;
      }
      // Non-401 error (500, network timeout, etc.) — proceed anyway;
      // the row likely already exists for returning users.
    } catch (_) {
      // Non-fatal unexpected error — proceed with local state.
    }
    // Always set state after register attempt so navigation can proceed.
    final newState = await _stateFromSession(session);
    state = AsyncValue.data(newState);
  }

  /// Build AuthState from a live Supabase session.
  /// Reads onboarding flag from local storage (fast, no network).
  Future<AuthState> _stateFromSession(Session session) async {
    final storage = ref.read(secureStorageProvider);
    final onboardingDone = await storage.isOnboardingCompleted();
    final memberId = await storage.getMemberId();

    return AuthState(
      status: onboardingDone
          ? AuthStatus.authenticated
          : AuthStatus.onboardingRequired,
      userId: session.user.id,
      email: session.user.email,
      memberId: memberId,
      onboardingCompleted: onboardingDone,
    );
  }

  // ---------------------------------------------------------------------------
  // Called by AuthScreenNotifier after a successful register/login API call
  // so we can store the memberId and mark onboarding state.
  // ---------------------------------------------------------------------------
  Future<void> onLoginSuccess({
    required bool onboardingCompleted,
    String? memberId,
  }) async {
    final storage = ref.read(secureStorageProvider);
    if (memberId != null) await storage.saveMemberId(memberId);
    await storage.setOnboardingCompleted(onboardingCompleted);

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    final newState = await _stateFromSession(session);
    state = AsyncValue.data(newState);
  }

  Future<void> onOnboardingCompleted() async {
    final storage = ref.read(secureStorageProvider);
    await storage.setOnboardingCompleted(true);

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(
        status: AuthStatus.authenticated,
        onboardingCompleted: true,
      ));
    }
  }

  Future<void> logout() async {
    // Best-effort server audit log
    try {
      await ref.read(apiClientProvider).post('/auth/logout');
    } catch (_) {}

    // Supabase signOut clears the local session and fires onAuthStateChange
    // which will set state to unauthenticated via the listener above.
    await Supabase.instance.client.auth.signOut();

    // Clear app-level local data (memberId, onboarding flag)
    await ref.read(secureStorageProvider).clearAppData();
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
