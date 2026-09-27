import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/api_client.dart';
import '../storage/cache_service.dart';
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
  // Incremented on every logout/forceUnauthenticated call.
  // Any in-flight async callback that captured an older generation will bail
  // out before writing state, preventing stale "authenticated" restorations.
  int _authGeneration = 0;

  @override
  Future<AuthState> build() async {
    final sub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        final event = data.event;
        final session = data.session;
        final generation = ++_authGeneration;

        debugPrint('[Auth] stream event=$event session=${session?.user.id}');

        if (event == AuthChangeEvent.signedOut || session == null) {
          // Idempotent: logout() already set this, but the stream fires too.
          state = const AsyncValue.data(AuthState.unauthenticated());
          return;
        }

        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.initialSession) {
          if (event == AuthChangeEvent.signedIn) {
            await _ensureUserRow(session, generation);
            return;
          }
          final newState = await _stateFromSession(session);
          if (_isCurrentGeneration(generation)) {
            state = AsyncValue.data(newState);
          }
        }
      },
    );
    ref.onDispose(sub.cancel);

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const AuthState.unauthenticated();
    final generation = ++_authGeneration;
    final initialState = await _stateFromSession(session);
    return _isCurrentGeneration(generation)
        ? initialState
        : const AuthState.unauthenticated();
  }

  // Simpler guard: just check the generation number. We no longer need to
  // verify session.user.id because _authGeneration is only incremented by
  // logout/forceUnauthenticated, which means any callback from a prior
  // "signed-in" era is stale.
  bool _isCurrentGeneration(int generation) => _authGeneration == generation;

  void _setUnauthenticated() {
    _authGeneration++;
    debugPrint('[Auth] _setUnauthenticated gen=$_authGeneration');
    state = const AsyncValue.data(AuthState.unauthenticated());
  }

  /// Escape hatch for the splash 8-second timeout.
  void forceUnauthenticated() {
    _setUnauthenticated();
    unawaited(Supabase.instance.client.auth.signOut().catchError((_) {}));
  }

  Future<void> _ensureUserRow(Session session, int generation) async {
    try {
      final response = await ref.read(apiClientProvider).post('/auth/register');
      if (!_isCurrentGeneration(generation)) return;
      final data = response.data as Map<String, dynamic>?;
      final storage = ref.read(secureStorageProvider);
      if (data != null) {
        final onboardingDone = data['onboarding_completed'] as bool? ?? false;
        final memberId = data['member_id'] as String?;
        if (memberId != null) await storage.saveMemberId(memberId);
        await storage.setOnboardingCompleted(onboardingDone);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await Supabase.instance.client.auth.signOut();
        if (_isCurrentGeneration(generation)) _setUnauthenticated();
        return;
      }
      // Non-401 (network error, 5xx) — proceed; row likely already exists.
    } catch (_) {}
    final newState = await _stateFromSession(session);
    if (_isCurrentGeneration(generation)) {
      state = AsyncValue.data(newState);
    }
  }

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

  Future<void> onLoginSuccess({
    required bool onboardingCompleted,
    String? memberId,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    final generation = ++_authGeneration;
    final storage = ref.read(secureStorageProvider);
    if (memberId != null) await storage.saveMemberId(memberId);
    await storage.setOnboardingCompleted(onboardingCompleted);
    final newState = await _stateFromSession(session);
    if (_isCurrentGeneration(generation)) {
      state = AsyncValue.data(newState);
    }
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

  /// Logout: synchronously set unauthenticated so the router redirects to
  /// /login immediately, then clean up in the background.
  ///
  /// Edge cases handled:
  /// - No await after _setUnauthenticated() — cleanup never blocks navigation.
  /// - signOut() fires onAuthStateChange(signedOut) which sets unauthenticated
  ///   again — idempotent, harmless.
  /// - ref.invalidate() is NOT called — that would invoke build() again,
  ///   emitting AsyncLoading, which makes the router redirect to /splash
  ///   (the black screen). autoDispose on all data providers handles cleanup.
  /// - If the Riverpod ref is disposed before cleanup finishes (e.g. hot
  ///   restart), every ref.read inside _cleanupAfterLogout is wrapped in
  ///   try/catch so it fails silently.
  Future<void> logout() async {
    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
    debugPrint('[Auth] logout() called, gen before=${_authGeneration}');
    _setUnauthenticated();
    debugPrint('[Auth] logout() unauthenticated set, gen after=${_authGeneration}');
    unawaited(_cleanupAfterLogout(accessToken));
  }

  Future<void> _cleanupAfterLogout(String? accessToken) async {
    debugPrint('[Auth] _cleanupAfterLogout start');
    // Sign out Supabase — this clears the SDK's persisted session so a cold
    // start after logout shows the login screen, not the home screen.
    try {
      await Supabase.instance.client.auth.signOut();
      debugPrint('[Auth] Supabase.signOut() done');
    } catch (e) {
      debugPrint('[Auth] Supabase.signOut() failed: $e');
    }
    // Wipe CacheService keys from SharedPreferences.
    try { await CacheService.invalidateAll(); } catch (_) {}
    // Wipe secure storage (memberId, onboarding flag).
    try {
      await ref.read(secureStorageProvider).clearAppData();
      debugPrint('[Auth] clearAppData done');
    } catch (e) {
      debugPrint('[Auth] clearAppData failed: $e');
    }
    // Best-effort backend audit log — use the captured token because the
    // Supabase session is already gone by this point.
    if (accessToken != null) {
      try {
        await ref.read(apiClientProvider).post(
          '/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
        debugPrint('[Auth] backend /auth/logout done');
      } catch (e) {
        debugPrint('[Auth] backend /auth/logout failed: $e');
      }
    }
    debugPrint('[Auth] _cleanupAfterLogout done');
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
