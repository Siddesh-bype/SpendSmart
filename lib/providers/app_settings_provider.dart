import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../services/session_store.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => const SessionStore(),
);

/// The token read out of the keystore at startup. Overridden in `main`, because
/// the read is async and [AppSettingsNotifier.build] is not.
final initialSessionTokenProvider = Provider<String>((ref) => '');

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final token = ref.watch(initialSessionTokenProvider);

    return AppSettings(
      currency: prefs.getString('currency') ?? '₹',
      monthlyBudget:
          prefs.getDouble('monthlyBudget') ??
          prefs.getDouble('monthlyIncome') ??
          0.0,
      theme: prefs.getString('theme') ?? 'system',
      onboardingDone: prefs.getBool('onboardingDone') ?? false,
      startingDayOfMonth: prefs.getInt('startingDayOfMonth') ?? 1,
      aiCategorizeConsent: prefs.getBool('aiCategorizeConsent') ?? false,
      aiSessionToken: token,
      aiAccountEmail: prefs.getString('aiAccountEmail') ?? '',
      aiSessionExpiresAt: prefs.getInt('aiSessionExpiresAt') ?? 0,
    );
  }

  Future<void> updateCurrency(String currency) async {
    await ref.read(sharedPreferencesProvider).setString('currency', currency);
    state = state.copyWith(currency: currency);
  }

  Future<void> updateBudget(double budget) async {
    await ref
        .read(sharedPreferencesProvider)
        .setDouble('monthlyBudget', budget);
    state = state.copyWith(monthlyBudget: budget);
  }

  Future<void> updateTheme(String theme) async {
    await ref.read(sharedPreferencesProvider).setString('theme', theme);
    state = state.copyWith(theme: theme);
  }

  Future<void> updateStartingDay(int day) async {
    await ref.read(sharedPreferencesProvider).setInt('startingDayOfMonth', day);
    state = state.copyWith(startingDayOfMonth: day);
  }

  Future<void> completeOnboarding() async {
    await ref.read(sharedPreferencesProvider).setBool('onboardingDone', true);
    state = state.copyWith(onboardingDone: true);
  }

  Future<void> setAiCategorizeConsent(bool consented) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool('aiCategorizeConsent', consented);
    state = state.copyWith(aiCategorizeConsent: consented);
  }

  /// Stores the AI session returned by the Worker. The token goes to the
  /// keystore; only the email and expiry are kept in prefs.
  Future<void> setAiSession(String token, String email, int expiresAt) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await ref.read(sessionStoreProvider).writeToken(token);
    await prefs.setString('aiAccountEmail', email);
    await prefs.setInt('aiSessionExpiresAt', expiresAt);
    state = state.copyWith(
      aiSessionToken: token,
      aiAccountEmail: email,
      aiSessionExpiresAt: expiresAt,
    );
  }

  /// Drops the AI session. Consent is reset too: the next sign-in may be a
  /// different account, which has not agreed to anything yet.
  Future<void> clearAiSession() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await ref.read(sessionStoreProvider).deleteToken();
    await prefs.remove('aiSessionToken'); // pre-keystore builds
    await prefs.remove('aiAccountEmail');
    await prefs.remove('aiSessionExpiresAt');
    await prefs.remove('aiCategorizeConsent');
    state = state.copyWith(
      aiSessionToken: '',
      aiAccountEmail: '',
      aiSessionExpiresAt: 0,
      aiCategorizeConsent: false,
    );
  }
}
