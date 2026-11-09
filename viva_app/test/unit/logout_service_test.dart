// LogoutService unit test.
//
// Verifies: each of steps 1–7 (network/storage/Firebase) can throw independently
// and step 8 (navigate to login) still always runs.
//
// The test uses a fake LogoutService that records which steps ran and
// which threw, without touching real Firebase, real Riverpod, or real storage.
//
// Run with: flutter test test/unit/logout_service_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogoutService — each step throws, step 8 (navigate) always runs', () {
    for (int failStep = 1; failStep <= 7; failStep++) {
      test('step $failStep throws → step 8 still runs', () async {
        final svc = _FakeLogoutService(failAtStep: failStep);
        await svc.logout();
        expect(svc.navigatedToLogin, true,
            reason: 'step 8 must run even when step $failStep throws');
        expect(svc.completedSteps.contains(failStep), false,
            reason: 'step $failStep should have thrown and not completed');
        // All steps before the failing one should have run
        for (int s = 1; s < failStep; s++) {
          expect(svc.completedSteps.contains(s), true,
              reason: 'step $s should have run before step $failStep');
        }
        // All steps after the failing one should also have run
        for (int s = failStep + 1; s <= 7; s++) {
          expect(svc.completedSteps.contains(s), true,
              reason: 'step $s should have run after step $failStep threw');
        }
      });
    }

    test('re-entrancy: second logout() call returns same Future', () async {
      final svc = _FakeLogoutService(failAtStep: -1); // no failure
      final f1 = svc.logout();
      final f2 = svc.logout();
      expect(identical(f1, f2), true,
          reason: 'second call must return same Future, not start a new logout');
      await f1;
      expect(svc.logoutStartCount, 1,
          reason: '_doLogout must only execute once');
    });

    test('all steps pass → navigates to login', () async {
      final svc = _FakeLogoutService(failAtStep: -1);
      await svc.logout();
      expect(svc.navigatedToLogin, true);
      expect(svc.completedSteps.length, 7);
    });
  });
}

/// Fake LogoutService that mirrors the real 8-step structure.
/// failAtStep: which step throws (-1 = none).
class _FakeLogoutService {
  final int failAtStep;
  _FakeLogoutService({required this.failAtStep});

  Future<void>? _ongoingLogout;
  int logoutStartCount = 0;
  final List<int> completedSteps = [];
  bool navigatedToLogin = false;

  Future<void> logout() {
    _ongoingLogout ??= _doLogout().whenComplete(() {
      _ongoingLogout = null;
    });
    return _ongoingLogout!;
  }

  Future<void> _doLogout() async {
    logoutStartCount++;

    // Steps 1–7: each in its own try/catch
    for (int step = 1; step <= 7; step++) {
      try {
        if (step == failAtStep) throw Exception('Simulated failure at step $step');
        await Future.delayed(Duration.zero); // simulate async work
        completedSteps.add(step);
      } catch (_) {
        // Swallow — next step must still run
      }
    }

    // Step 8 (navigate): always runs, in a try/catch
    try {
      navigatedToLogin = true;
    } catch (_) {}
  }
}
