import 'dart:async';

import 'package:dio/dio.dart';
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
  // Each asynchronous auth operation captures this generation counter.
  // A later auth event (e.g. logout) increments this, causing stale
  // async callbacks to bail out before writing routing state.
  int _authGeneration = 0;

  @override
  Future<AuthState> build() async {
    final sub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        final event = data.event;
        final session = data.session;
        final generation = ++_authGeneration;

        if (event == AuthChangeEvent.signedOut || session == null) {
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
          if (_isCurrentSession(generation, session)) {
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
    return _isCurrentSession(generation, session)
        ? initialState
        : const AuthState.unauthenticated();
  }

  bool _isCurrentSession(int generation, Session session) {
    final current = Supabase.instance.client.auth.currentSession;
    return _authGeneration == generation &&
        current != null &&
        current.user.id == session.user.id;
  }

  void _setUnauthenticated() {
    _authGeneration++;
    state = const AsyncValue.data(AuthState.unauthenticated());
  }

  /// Escape hatch for the splash 8s timeout.
  void forceUnauthenticated() {
    _setUnauthenticated();
    unawaited(Supabase.instance.client.auth.signOut().catchError((_) {}));
  }

  Future<void> _ensureUserRow(Session session, int generation) async {
    try {
      final response = await ref.read(apiClientProvider).post('/auth/register');
      if (!_isCurrentSession(generation, session)) return;
      final data = response.data as Map<String, dynamic>?;
      final storage = ref.read(secureStorageProvider);
      if (data != null) {
        final onboardingDone = data['onboarding_completed'] as bool? ?? false;
        final memberId = data['member_id'] as String?;
        if (memberId != null) await storage.saveMemberId(memberId);
        await storage.setOnboardingCompleted(onboardingDone);
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        await Supabase.instance.client.auth.signOut();
        if (_isCurrentSession(generation, session)) {
          _setUnauthenticated();
        }
        return;
      }
    } catch (_) {}
    final newState = await _stateFromSession(session);
    if (_isCurrentSession(generation, session)) {
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
    if (_isCurrentSession(generation, session)) {
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

  Future<void> logout() async {
    // 1. Immediately set unauthenticated — router navigates to /login instantly.
    //    Capture the token before the session is cleared.
    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
    _setUnauthenticated();

    // 2. All cleanup is fire-and-forget so it NEVER awaits here.
    //    Awaiting signOut() would block this method and, more importantly,
    //    signOut() fires the onAuthStateChange stream which would call
    //    _setUnauthenticated() again — harmless but noisy.
    //    ref.invalidate() is intentionally NOT called: myProfileProvider is
    //    autoDispose and cleans itself up. Calling invalidate() here can
    //    trigger a notifier rebuild that briefly puts authProvider into
    //    AsyncLoading, causing the router to redirect to /splash (black screen).
    unawaited(_cleanupAfterLogout(accessToken));
  }

  Future<void> _cleanupAfterLogout(String? accessToken) async {
    try { await Supabase.instance.client.auth.signOut(); } catch (_) {}
    try { await CacheService.invalidateAll(); } catch (_) {}
    try { await ref.read(secureStorageProvider).clearAppData(); } catch (_) {}
    if (accessToken != null) {
      try {
        await ref.read(apiClientProvider).post(
          '/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
      } catch (_) {}
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
