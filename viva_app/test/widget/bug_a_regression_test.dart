// Regression test for Bug A: clear-data → logout → black screen.
//
// Scenario: after Android clear-data, auth state resolves to unauthenticated
// (either because Supabase session is gone or because secure storage throws).
// The router must redirect to LoginScreen. No black/blank screen allowed.
//
// What we CAN test here without a device or Supabase instance:
//   - authProvider overridden with a fake AuthNotifier that immediately returns
//     AuthState.unauthenticated() — the state after clear-data + logout.
//   - The GoRouter redirect must route to /login.
//   - LoginScreen must be present in the widget tree.
//
// What CANNOT be tested here (requires a device):
//   - Real Keystore failure on Android hardware.
//   - The full cold-start flow with a real Supabase session.
// These are listed in manual-checklist.md as NOT VERIFIED — manual test required.
//
// Run with: flutter test test/widget/bug_a_regression_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:viva_app/core/providers/auth_provider.dart';
import 'package:viva_app/features/auth/presentation/screens/login_screen.dart';
import 'package:viva_app/shared/constants/app_constants.dart';

// ── Fake AuthNotifier ─────────────────────────────────────────────────────────

/// Returns unauthenticated immediately — simulates cleared-data cold start.
class _UnauthenticatedNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState.unauthenticated();
}

/// Stays in AsyncLoading indefinitely — simulates the resolving window.
/// Uses a Completer (no timer) so the test framework doesn't complain about
/// pending timers when the widget tree is disposed.
class _LoadingNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() {
    // Never completes — stays in AsyncLoading for the duration of the test.
    return Completer<AuthState>().future;
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  testWidgets(
    'Bug A: unauthenticated auth state routes to LoginScreen (no black screen)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_UnauthenticatedNotifier.new),
          ],
          child: const _TestApp(),
        ),
      );

      // Let the router settle — the redirect fires once the provider emits.
      await tester.pumpAndSettle();

      // LoginScreen must be in the tree.
      expect(find.byType(LoginScreen), findsOneWidget,
          reason: 'unauthenticated state must route to LoginScreen');

      // A Scaffold must be present — no blank/black screen.
      expect(find.byType(Scaffold), findsWidgets,
          reason: 'LoginScreen Scaffold must be rendered');
    },
  );

  testWidgets(
    'Bug A: loading auth state shows a Scaffold (not blank screen)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_LoadingNotifier.new),
          ],
          child: const _TestApp(),
        ),
      );

      // Single pump — stay in loading state.
      await tester.pump();

      // Router stays at splash; a Scaffold must be visible (not a blank screen).
      expect(find.byType(Scaffold), findsWidgets,
          reason: 'loading state must render SplashScreen Scaffold, not blank');
    },
  );
}

// ── Minimal test app ──────────────────────────────────────────────────────────

/// Minimal GoRouter app that mirrors the real redirect logic for the
/// auth states under test. Avoids importing the full app (which depends on
/// Supabase.initialize being called).
class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

    final router = GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: _AlwaysNotifier(),
      redirect: (context, state) {
        if (authAsync is AsyncError) return AppRoutes.login;
        if (authAsync is AsyncLoading || authAsync.valueOrNull == null) {
          return null; // stay on current route (splash)
        }
        final auth = authAsync.value!;
        final loc = state.matchedLocation;
        switch (auth.status) {
          case AuthStatus.loading:
            return loc == AppRoutes.splash ? null : AppRoutes.splash;
          case AuthStatus.unauthenticated:
            if (loc == AppRoutes.login) return null;
            return AppRoutes.login;
          case AuthStatus.onboardingRequired:
            return AppRoutes.onboardingBasic;
          case AuthStatus.authenticated:
            if (loc == AppRoutes.splash || loc == AppRoutes.login) {
              return AppRoutes.home;
            }
            return null;
        }
      },
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (_, __) => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboardingBasic,
          builder: (_, __) => const Scaffold(body: Text('Onboarding')),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }
}

// GoRouter needs a refreshListenable; this one never notifies (the redirect
// is driven by Riverpod watching authProvider above).
class _AlwaysNotifier extends ChangeNotifier {}
