import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/auth/logout_service.dart';
import 'core/storage/cache_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/constants/app_constants.dart';

import 'firebase_options.dart';
// Must be a top-level function (not a closure or instance method).
// Runs in a separate isolate — must NOT touch UI, Riverpod, or BuildContext.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase.initializeApp() is called automatically by the FlutterFire plugin
  // before this handler runs in the background isolate.
  debugPrint('[FCM] background message: ${message.messageId}');
}

// ── Locale provider ───────────────────────────────────────────────────────────
// Persisted in SharedPreferences so the choice survives restarts.
// The initial value is loaded synchronously at startup (see main()) to avoid
// a one-frame English flicker when the user has selected Hindi.

Locale _initialLocale = const Locale('en', 'IN');

final _localeProvider = StateNotifierProvider<_LocaleNotifier, Locale>((ref) {
  return _LocaleNotifier(_initialLocale);
});

class _LocaleNotifier extends StateNotifier<Locale> {
  static const _key = 'viva_locale';

  _LocaleNotifier(super.initial);

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }
}

/// Call from any widget to switch the app language.
Future<void> setAppLocale(WidgetRef ref, Locale locale) =>
    ref.read(_localeProvider.notifier).setLocale(locale);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register FCM background handler before runApp.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Catch Flutter framework errors → Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Catch async errors outside the Flutter framework → Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Initialise Supabase with Firebase ID token as the auth source
  // (Supabase Third-Party Auth — Phase 4).
  // The `accessToken` callback is called by the Supabase client before every
  // authenticated request. It returns a fresh Firebase ID token (SDK-cached;
  // automatically refreshed ~5 min before expiry).
  // IMPORTANT: once `accessToken` is set, `supabase.auth.*` calls will throw.
  // All Supabase Auth calls have been removed from Dart code at this point.
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
    accessToken: () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      try {
        return await user.getIdToken();
      } catch (_) {
        // Token fetch failed (offline, account deleted) — return null so
        // Supabase sends the request unauthenticated (backend returns 401).
        return null;
      }
    },
  );

  // Deep links for Firebase Auth (email verification, password reset) are
  // handled automatically by the firebase_auth SDK — no manual interception needed.
  // The Supabase-specific app_links handler has been removed (it called
  // supabase.auth.getSessionFromUrl which will throw after Phase 4).

  try {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (_) {}

  // Load persisted locale before runApp so there is no English flicker.
  final prefs = await SharedPreferences.getInstance();
  final localeCode = prefs.getString('viva_locale');
  if (localeCode != null) _initialLocale = Locale(localeCode, 'IN');

  // Detect incomplete logout (app was terminated mid-logout).
  // Complete cleanup before showing any UI.
  final incompleteLogout = await LogoutService.hasIncompleteLogout();
  if (incompleteLogout) {
    debugPrint('[main] incomplete logout detected — completing cleanup');
    try {
      await CacheService.invalidateAll();
    } catch (_) {}
    // SecureStorage needs a Provider — do a best-effort cleanup without it.
    // The full cleanup happens when LogoutService runs inside the app.
    await FirebaseAuth.instance.signOut().catchError((_) {});
    // Clear the flag (it will be re-cleared by LogoutService but we clear now
    // so a crash loop can't permanently block startup).
    await prefs.remove('viva_logout_in_progress');
  }

  runApp(const ProviderScope(child: VivaApp()));
}

class VivaApp extends ConsumerWidget {
  const VivaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(_localeProvider);

    return MaterialApp.router(
      title: 'Viva',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
