import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../providers/profile_provider.dart';
import '../providers/notification_provider.dart';
import '../router/app_router.dart' show rootNavigatorKey;
import '../storage/cache_service.dart';
import '../storage/secure_storage.dart';
import '../../shared/constants/app_constants.dart';

/// Single-instance logout orchestrator.
///
/// Re-entrancy guard: if logout() is already in progress, the second call
/// returns the same Future instead of starting a new execution.
///
/// Invariant: step 10 (navigate to login) ALWAYS runs even if every
/// previous step throws. Each step is isolated in its own try/catch.
class LogoutService {
  final Ref _ref;
  LogoutService(this._ref);

  Future<void>? _ongoingLogout;

  // Persisted flag to detect incomplete logout on next cold start.
  static const _logoutInProgressKey = 'viva_logout_in_progress';

  /// Start or join an in-progress logout.
  Future<void> logout() {
    _ongoingLogout ??= _doLogout().whenComplete(() {
      _ongoingLogout = null;
    });
    return _ongoingLogout!;
  }

  Future<void> _doLogout() async {
    debugPrint('[LogoutService] START');

    // ── Step 1: Persist the in-progress flag ─────────────────────────────
    // On next cold start, if this flag is still set, the incomplete logout
    // will be completed before showing any UI.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_logoutInProgressKey, true);
    } catch (e) {
      debugPrint('[LogoutService] step 1 (persist flag) failed: $e');
    }

    // ── Step 2: Deregister FCM token ─────────────────────────────────────
    try {
      final api = _ref.read(apiClientProvider);
      await api
          .delete('/fcm/token')
          .timeout(const Duration(seconds: 4));
      debugPrint('[LogoutService] step 2: FCM token deregistered');
    } catch (e) {
      // Swallow: token will be deregistered on next login attempt, or
      // the server will ignore the stale token.
      debugPrint('[LogoutService] step 2 (FCM deregister) failed (non-fatal): $e');
    }

    // ── Step 3: Clear FCM token from Firebase SDK ─────────────────────────
    try {
      await FirebaseMessaging.instance.deleteToken();
      debugPrint('[LogoutService] step 3: FCM SDK token deleted');
    } catch (e) {
      debugPrint('[LogoutService] step 3 (delete FCM token) failed: $e');
    }

    // ── Step 4: Clear user caches ─────────────────────────────────────────
    try {
      await CacheService.invalidateAll();
      debugPrint('[LogoutService] step 4: caches cleared');
    } catch (e) {
      debugPrint('[LogoutService] step 4 (cache clear) failed: $e');
    }

    // ── Step 5: Clear user-specific secure storage ────────────────────────
    // KEEP: viva_locale (language preference — app-wide, not user-specific)
    try {
      await _ref.read(secureStorageProvider).clearAppData();
      debugPrint('[LogoutService] step 5: secure storage cleared');
    } catch (e) {
      debugPrint('[LogoutService] step 5 (secure storage) failed: $e');
    }

    // ── Step 6: Reset user-specific Riverpod providers ───────────────────
    try {
      _ref.invalidate(myProfileProvider);
      _ref.invalidate(unreadNotificationCountProvider);
      debugPrint('[LogoutService] step 6: providers invalidated');
    } catch (e) {
      debugPrint('[LogoutService] step 6 (provider reset) failed: $e');
    }

    // ── Step 7: Firebase sign out ─────────────────────────────────────────
    // This fires idTokenChanges(null) which flips firebaseAuthProvider to
    // unauthenticated, triggering the router redirect automatically.
    try {
      await FirebaseAuth.instance.signOut();
      debugPrint('[LogoutService] step 7: Firebase signed out');
    } catch (e) {
      debugPrint('[LogoutService] step 7 (Firebase signOut) failed: $e');
      try {
        FirebaseCrashlytics.instance.recordError(
          e, null, reason: 'LogoutService Firebase signOut failed',
        );
      } catch (_) {}
    }

    // ── Step 8: Navigate to login (ALWAYS runs) ───────────────────────────
    // Use the root navigator key so this works regardless of which screen
    // triggered logout or whether any BuildContext is still valid.
    try {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        GoRouter.of(ctx).go(AppRoutes.login);
        debugPrint('[LogoutService] step 8: navigated to login');
      } else {
        debugPrint('[LogoutService] step 8: no valid context — Firebase signOut '
            'should have triggered router redirect');
      }
    } catch (e) {
      debugPrint('[LogoutService] step 8 (navigate) failed: $e');
    }

    // ── Clear the in-progress flag ────────────────────────────────────────
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logoutInProgressKey);
    } catch (_) {}

    debugPrint('[LogoutService] COMPLETE');
  }

  /// Call during cold start to detect and complete an interrupted logout.
  static Future<bool> hasIncompleteLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_logoutInProgressKey) ?? false;
    } catch (_) {
      return false;
    }
  }
}

final logoutServiceProvider = Provider<LogoutService>((ref) {
  return LogoutService(ref);
});
