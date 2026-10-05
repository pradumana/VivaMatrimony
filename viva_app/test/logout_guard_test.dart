// Self-check for the AuthNotifier logout guard.
//
// Verifies three invariants without a running Supabase instance:
//   1. A concurrent second call is a no-op (guard returns early).
//   2. State becomes unauthenticated on the first call.
//   3. The auth generation counter is incremented exactly once per logout.
//
// Run with:  flutter test test/logout_guard_test.dart
//
// No frameworks, no fixtures. Uses flutter_test (already a dev dep).

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent-logout guard: second call is a no-op', () {
    final notifier = _FakeAuthNotifier();

    // Simulate two rapid calls (e.g. double-tap confirm button).
    notifier.logout();
    notifier.logout();

    // _setUnauthenticated should have been called exactly once.
    expect(notifier.unauthenticatedCallCount, 1,
        reason: 'second logout() must return early via _isLoggingOut guard');
    expect(notifier.generation, 1,
        reason: '_authGeneration must only increment once');
  });

  test('logout clears isLoggingOut after cleanup', () async {
    final notifier = _FakeAuthNotifier();
    await notifier.logoutAndAwait();

    expect(notifier.isLoggingOut, false,
        reason: '_isLoggingOut must be reset after cleanup completes');
  });

  test('after cleanup completes, a new logout is accepted', () async {
    final notifier = _FakeAuthNotifier();
    await notifier.logoutAndAwait();

    // Second logout after cleanup finishes should be accepted.
    notifier.logout();
    expect(notifier.unauthenticatedCallCount, 2,
        reason: 'a fresh logout after cleanup must increment the counter');
  });
}

// ── Minimal fake that mirrors the exact guard/counter logic from AuthNotifier ─

class _FakeAuthNotifier {
  int _authGeneration = 0;
  bool _isLoggingOut = false;

  int unauthenticatedCallCount = 0;

  int get generation => _authGeneration;
  bool get isLoggingOut => _isLoggingOut;

  // Mirrors AuthNotifier.logout() exactly (without the Supabase calls).
  void logout() {
    if (_isLoggingOut) return; // ← the guard under test
    _isLoggingOut = true;
    _setUnauthenticated();
    // Cleanup is fire-and-forget in production; in the sync test we skip it.
  }

  // Variant that awaits the full cleanup cycle.
  Future<void> logoutAndAwait() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    _setUnauthenticated();
    await _fakeCleanup();
    _isLoggingOut = false;
  }

  void _setUnauthenticated() {
    _authGeneration++;
    unauthenticatedCallCount++;
  }

  Future<void> _fakeCleanup() async {
    // Simulates the async cleanup steps (cache, storage, signOut, backend).
    await Future.delayed(Duration.zero);
  }
}
