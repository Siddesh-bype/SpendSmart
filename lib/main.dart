import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/app_settings_provider.dart';
import 'providers/service_provider.dart';
import 'screens/splash_screen.dart';
import 'services/session_store.dart';
import 'services/storage_service.dart';
import 'utils/globals.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  // The session token lives in the keystore, but AppSettingsNotifier.build is
  // synchronous, so it is read here and injected.
  const sessionStore = SessionStore();
  final sessionToken = await sessionStore.loadMigrating(
    prefs.getString('aiSessionToken'),
    expiresAt: prefs.getInt('aiSessionExpiresAt') ?? 0,
  );
  await prefs.remove('aiSessionToken');

  // Boxes are NOT opened here. Opening them is slow enough to stall the first
  // frame, so SplashScreen and OnboardingScreen call init() where a spinner is
  // already on screen and an open failure has somewhere to be reported.
  final storageService = StorageService();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionStoreProvider.overrideWithValue(sessionStore),
        initialSessionTokenProvider.overrideWithValue(sessionToken),
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const SpendSmartApp(),
    ),
  );
}

class SpendSmartApp extends ConsumerWidget {
  const SpendSmartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    ThemeMode themeMode = ThemeMode.system;
    if (settings.theme == 'light') themeMode = ThemeMode.light;
    if (settings.theme == 'dark') themeMode = ThemeMode.dark;

    return MaterialApp(
      title: 'SpendSmart',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
