import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../storage/secure_storage.dart';

/// Auth state for the app — drives routing decisions.
enum AuthStatus {
  loading,
  unauthenticated,
  authenticated,
  onboardingRequired,
}

class AuthState {
  final AuthStatus status;
  final String? userId;
  final bool onboardingCompleted;
  final String? error;

  const AuthState({
    required this.status,
    this.userId,
    this.onboardingCompleted = false,
    this.error,
  });

  const AuthState.loading()
      : status = AuthStatus.loading,
        userId = null,
        onboardingCompleted = false,
        error = null;

  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        userId = null,
        onboardingCompleted = false,
        error = null;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    bool? onboardingCompleted,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        userId: userId ?? this.userId,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        error: error,
      );
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async => _checkSession();

  Future<AuthState> _checkSession() async {
    debugPrint('[Auth] Bypassing session check for debugging...');
    return const AuthState.unauthenticated();
  }

  Future<void> onLoginSuccess({
    required String userId,
    required bool onboardingCompleted,
    required String accessToken,
    required String refreshToken,
  }) async {
    final storage = ref.read(secureStorageProvider);
    await storage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
    );
    if (onboardingCompleted) {
      await storage.setOnboardingCompleted(true);
    }

    state = AsyncValue.data(AuthState(
      status: onboardingCompleted
          ? AuthStatus.authenticated
          : AuthStatus.onboardingRequired,
      userId: userId,
      onboardingCompleted: onboardingCompleted,
    ));
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
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/auth/logout');
    } catch (_) {
      // Best-effort logout
    }
    final storage = ref.read(secureStorageProvider);
    await storage.clearSession();
    state = const AsyncValue.data(AuthState.unauthenticated());
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
