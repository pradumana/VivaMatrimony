import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_basic_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_bio_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_education_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_career_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_family_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_lifestyle_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_native_place_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_preferences_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_photos_screen.dart';
import '../../features/verification/presentation/screens/verification_select_screen.dart';
import '../../features/verification/presentation/screens/verification_reference_screen.dart';
import '../../features/verification/presentation/screens/verification_certificate_screen.dart';
import '../../features/verification/presentation/screens/verification_status_screen.dart';
import '../../features/home/presentation/screens/main_shell_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/interests/presentation/screens/interests_screen.dart';
import '../../features/messaging/presentation/screens/conversations_screen.dart';
import '../../features/profile/presentation/screens/my_profile_screen.dart';
import '../../features/shortlist/presentation/screens/shortlist_screen.dart';
import '../../features/profile/presentation/screens/profile_detail_screen.dart';
import '../../features/biodata/presentation/screens/biodata_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/privacy_screen.dart';
import '../../features/settings/presentation/screens/help_screen.dart';
import '../../features/settings/presentation/screens/report_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../providers/auth_provider.dart';
import '../../shared/constants/app_constants.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authAsync = ref.read(authProvider);
      final auth = authAsync.valueOrNull;

      print('[Router] redirect — status=${auth?.status} location=${state.matchedLocation}');

      if (auth == null) return null; // Still loading

      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isOnAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.otp ||
          state.matchedLocation == AppRoutes.welcome;
      final isOnOnboardingRoute =
          state.matchedLocation.startsWith('/onboarding') ||
          state.matchedLocation.startsWith('/verification');

      switch (auth.status) {
        case AuthStatus.loading:
          return isSplash ? null : AppRoutes.splash;
        case AuthStatus.unauthenticated:
          if (isOnAuthRoute) return null;
          return AppRoutes.login;
        case AuthStatus.onboardingRequired:
          if (isOnOnboardingRoute) return null;
          return AppRoutes.onboardingBasic;
        case AuthStatus.authenticated:
          if (isSplash || isOnAuthRoute || isOnOnboardingRoute) return AppRoutes.home;
          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpScreen(phone: phone);
        },
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, __) => const WelcomeScreen(),
      ),

      // Onboarding
      GoRoute(path: AppRoutes.onboardingBasic, builder: (_, __) => const OnboardingBasicScreen()),
      GoRoute(path: AppRoutes.onboardingBio, builder: (_, __) => const OnboardingBioScreen()),
      GoRoute(path: AppRoutes.onboardingEducation, builder: (_, __) => const OnboardingEducationScreen()),
      GoRoute(path: AppRoutes.onboardingCareer, builder: (_, __) => const OnboardingCareerScreen()),
      GoRoute(path: AppRoutes.onboardingFamily, builder: (_, __) => const OnboardingFamilyScreen()),
      GoRoute(path: AppRoutes.onboardingLifestyle, builder: (_, __) => const OnboardingLifestyleScreen()),
      GoRoute(path: AppRoutes.onboardingNativePlace, builder: (_, __) => const OnboardingNativePlaceScreen()),
      GoRoute(path: AppRoutes.onboardingPreferences, builder: (_, __) => const OnboardingPreferencesScreen()),
      GoRoute(path: AppRoutes.onboardingPhotos, builder: (_, __) => const OnboardingPhotosScreen()),

      // Verification
      GoRoute(path: AppRoutes.verificationSelect, builder: (_, __) => const VerificationSelectScreen()),
      GoRoute(path: AppRoutes.verificationReference, builder: (_, __) => const VerificationReferenceScreen()),
      GoRoute(path: AppRoutes.verificationCertificate, builder: (_, __) => const VerificationCertificateScreen()),
      GoRoute(path: AppRoutes.verificationStatus, builder: (_, __) => const VerificationStatusScreen()),

      // Main app shell (with bottom nav)
      ShellRoute(
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, __) => const _HomeTab()),
          GoRoute(path: AppRoutes.search, builder: (_, __) => const _SearchTab()),
          GoRoute(path: AppRoutes.interests, builder: (_, __) => const _InterestsTab()),
          GoRoute(path: AppRoutes.connections, builder: (_, __) => const _ConversationsTab()),
          GoRoute(path: AppRoutes.myProfile, builder: (_, __) => const _ProfileTab()),
          GoRoute(path: AppRoutes.shortlist, builder: (_, __) => const _ShortlistTab()),
        ],
      ),

      // Detail routes (no shell)
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return ProfileDetailScreen(userId: userId);
        },
      ),
      GoRoute(path: AppRoutes.biodata, builder: (_, __) => const BiodataScreen()),
      GoRoute(path: AppRoutes.editProfile, builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: AppRoutes.notifications, builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: AppRoutes.settings, builder: (_, __) => const SettingsScreen()),
      GoRoute(path: AppRoutes.privacy, builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: AppRoutes.helpSupport, builder: (_, __) => const HelpScreen()),
      GoRoute(
        path: '/report/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return ReportScreen(reportedUserId: userId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Page not found', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

// These tab classes pass routing control to MainShellScreen
// which renders the correct screen based on selected tab index.
// The GoRouter shell handles state, not these wrappers.
class _HomeTab extends StatelessWidget {
  const _HomeTab();
  @override Widget build(BuildContext context) => const HomeScreen();
}
class _SearchTab extends StatelessWidget {
  const _SearchTab();
  @override Widget build(BuildContext context) => const SearchScreen();
}
class _InterestsTab extends StatelessWidget {
  const _InterestsTab();
  @override Widget build(BuildContext context) => const InterestsScreen();
}
class _ConversationsTab extends StatelessWidget {
  const _ConversationsTab();
  @override Widget build(BuildContext context) => const ConversationsScreen();
}
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();
  @override Widget build(BuildContext context) => const MyProfileScreen();
}
class _ShortlistTab extends StatelessWidget {
  const _ShortlistTab();
  @override Widget build(BuildContext context) => const ShortlistScreen();
}

/// Bridges Riverpod auth state changes to GoRouter's [refreshListenable].
/// When [authProvider] emits a new value the router re-runs its redirect.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AsyncValue<AuthState>>(authProvider, (previous, next) {
      // Only notify when the auth status actually changes
      if (previous?.valueOrNull?.status != next.valueOrNull?.status) {
        notifyListeners();
      }
    });
  }
}

/// Exposes the resolved [AuthState] (or null while loading) and notifies
/// GoRouter whenever auth changes so redirects are re-evaluated.
final _routerNotifierProvider =
    AsyncNotifierProvider<_RouterNotifier, AuthState?>(_RouterNotifier.new);

class _RouterNotifier extends AsyncNotifier<AuthState?> implements Listenable {
  final List<VoidCallback> _listeners = [];

  @override
  Future<AuthState?> build() async {
    // Watch authProvider — rebuilds whenever auth changes
    final authAsync = ref.watch(authProvider);
    final value = authAsync.valueOrNull;
    // Schedule notification after the current build frame completes
    Future.microtask(() {
      for (final l in _listeners) l();
    });
    return value;
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}
