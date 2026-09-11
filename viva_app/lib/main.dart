import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/constants/app_constants.dart';
import 'firebase_options.dart';

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

  // Catch Flutter framework errors → Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Catch async errors outside the Flutter framework → Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Initialise Supabase — must happen before runApp so the SDK can
  // restore any persisted session before the router reads auth state.
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
  );

  // Handle deep links (email confirmation, password reset, magic link).
  // supabase_flutter v2 no longer intercepts URIs automatically — we do it here.
  final appLinks = AppLinks();

  // Handle the link that cold-started the app
  final initialUri = await appLinks.getInitialLink();
  if (initialUri != null) {
    await Supabase.instance.client.auth.getSessionFromUrl(initialUri);
  }

  // Handle links while the app is already running
  appLinks.uriLinkStream.listen((uri) {
    Supabase.instance.client.auth.getSessionFromUrl(uri);
  });

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
