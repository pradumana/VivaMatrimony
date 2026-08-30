import 'dart:convert';

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
    final storage = ref.read(secureStorageProvider);
    final token = await storage.getAccessToken();
    if (token == null || token.isEmpty) {
      return const AuthState.unauthenticated();
    }

    // Decode JWT expiry without verifying signature (client-side pre-check only).
    // The server still validates the signature on every request.
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        // Base64url decode the payload
        var payload = parts[1];
        // Pad to multiple of 4
        payload += '=' * ((4 - payload.length % 4) % 4);
        final decoded = String.fromCharCodes(
          base64Url.decode(payload),
        );
        final json = jsonDecode(decoded) as Map<String, dynamic>;
        final exp = json['exp'] as int?;
        if (exp != null) {
          final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
          if (expiry.isBefore(DateTime.now().toUtc())) {
            // Token expired — clear and require re-login
            await storage.clearSession();
            return const AuthState.unauthenticated();
          }
        }
      }
    } catch (_) {
      // Malformed token — clear and re-authenticate
      await storage.clearSession();
      return const AuthState.unauthenticated();
    }

    final userId = await storage.getUserId();
    final onboardingDone = await storage.isOnboardingCompleted();

    return AuthState(
      status: onboardingDone ? AuthStatus.authenticated : AuthStatus.onboardingRequired,
      userId: userId,
      onboardingCompleted: onboardingDone,
    );
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
