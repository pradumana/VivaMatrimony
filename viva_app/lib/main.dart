import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  print('VIVA: App main() started');
  WidgetsFlutterBinding.ensureInitialized();
  print('VIVA: WidgetsBinding initialized');

  // Catch Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('VIVA: Flutter error: ${details.exception}');
  };

  // Catch async errors outside the Flutter framework
  PlatformDispatcher.instance.onError = (error, stack) {
    print('VIVA: Platform error: $error');
    return true;
  };

  // Lock to portrait - move after runApp if it hangs
  try {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    print('VIVA: SystemChrome error: $e');
  }

  runApp(const ProviderScope(child: VivaApp()));
  print('VIVA: runApp called');
}

class VivaApp extends ConsumerWidget {
  const VivaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Viva',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'IN'),
        Locale('hi', 'IN'),
      ],
    );
  }
}
