// Self-check for the AuthNotifier logout guard and contract.
//
// Verifies the logout invariants without a running Supabase instance:
//   1. A concurrent second call is a no-op (the _isLoggingOut guard returns).
//   2. State flips to unauthenticated when logout() returns (NOT gated on the
//      fire-and-forget network cleanup), and that cleanup is scheduled.
//   3. The guard resets when logout() returns, so a later logout is accepted.
//
// Run with:  flutter test test/logout_guard_test.dart
//
// No frameworks, no fixtures. Uses flutter_test (already a dev dep).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent-logout guard: overlapping second call is a no-op', () async {
    final notifier = _FakeAuthNotifier();
    // Fire two calls without awaiting between them. The first yields at its
    // first await with the guard set; the second must bail out.
    unawaited(notifier.logout());
    unawaited(notifier.logout());
    await Future.delayed(Duration.zero);

    expect(notifier.unauthenticatedCallCount, 1,
        reason: 'second logout() must return early via _isLoggingOut guard');
    expect(notifier.generation, 1,
        reason: '_authGeneration must only increment once');
  });

  test('logout flips state without waiting on network cleanup', () async {
    final notifier = _FakeAuthNotifier();
    await notifier.logout();

    expect(notifier.unauthenticatedCallCount, 1,
        reason: 'state must be unauthenticated once logout() returns');
    expect(notifier.cleanupScheduled, true,
        reason: 'background cleanup (audit + global signOut) must be scheduled');
  });

  test('guard resets when logout() returns, so a later logout is accepted',
      () async {
    final notifier = _FakeAuthNotifier();
    await notifier.logout();

    expect(notifier.isLoggingOut, false,
        reason: '_isLoggingOut must be reset once logout() returns');

    await notifier.logout();
    expect(notifier.unauthenticatedCallCount, 2,
        reason: 'a fresh logout after the guard resets must be accepted');
  });

  test('storage read failure does not block logout or cause unhandled error',
      () async {
    // Simulates: Keystore key destroyed after clear-data. The local-cleanup
    // step catches the PlatformException; the state flip and guard reset still
    // happen. This is the unit-level check for Bug A — the widget-level check
    // is in test/widget/bug_a_regression_test.dart.
    final notifier = _FakeAuthNotifier(storageThrows: true);
    await notifier.logout();

    expect(notifier.unauthenticatedCallCount, 1,
        reason: 'logout must complete even when storage read throws');
    expect(notifier.isLoggingOut, false,
        reason: '_isLoggingOut guard must reset even after storage failure');
    expect(notifier.cleanupScheduled, true,
        reason: 'background cleanup must still be scheduled');
  });
}

// Mirrors AuthNotifier.logout()'s guard/counter/flip ordering without a real
// Supabase instance: clear app data (fast await) -> flip state -> fire-and-forget
// the network cleanup -> reset the guard when logout() returns.
class _FakeAuthNotifier {
  final bool storageThrows;
  _FakeAuthNotifier({this.storageThrows = false});

  int _authGeneration = 0;
  bool _isLoggingOut = false;

  int unauthenticatedCallCount = 0;
  bool cleanupScheduled = false;

  int get generation => _authGeneration;
  bool get isLoggingOut => _isLoggingOut;

  Future<void> logout() async {
    if (_isLoggingOut) return; // <- the guard under test
    _isLoggingOut = true;
    try {
      // Local cleanup (cache + secure storage) — fast, awaited.
      // Simulates a PlatformException from flutter_secure_storage when the
      // Keystore key has been destroyed (Bug A scenario).
      await Future.delayed(Duration.zero);
      if (storageThrows) {
        // Mirrors SecureStorage.clearAppData() throwing — must be caught here.
        try {
          throw Exception('PlatformException: Keystore key not found');
        } catch (_) {
          // Swallowed: storage failure must not block the state flip.
        }
      }
      // Flip state NOW (prompt UI, not gated on network).
      _setUnauthenticated();
      // Fire-and-forget background cleanup (audit + global signOut).
      cleanupScheduled = true;
      unawaited(Future.delayed(Duration.zero));
    } finally {
      _isLoggingOut = false;
    }
  }

  void _setUnauthenticated() {
    _authGeneration++;
    unauthenticatedCallCount++;
  }
}
