import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../services/password_hasher.dart';

/// Sendable across an isolate boundary, unlike a closure over provider state.
class _HashRequest {
  const _HashRequest({required this.password, required this.salt});
  final String password;
  final String salt;
}

/// Isolate entry point: must stay top-level.
String _hashInIsolate(_HashRequest request) =>
    PasswordHasher.hash(request.password, request.salt);

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      currency: prefs.getString('currency') ?? '₹',
      monthlyBudget:
          prefs.getDouble('monthlyBudget') ??
          prefs.getDouble('monthlyIncome') ??
          0.0,
      theme: prefs.getString('theme') ?? 'system',
      onboardingDone: prefs.getBool('onboardingDone') ?? false,
      startingDayOfMonth: prefs.getInt('startingDayOfMonth') ?? 1,
      aiWorkerUrl: prefs.getString('aiWorkerUrl') ?? '',
      aiProxyToken: prefs.getString('aiProxyToken') ?? '',
      aiCategorizeConsent: prefs.getBool('aiCategorizeConsent') ?? false,
      username: prefs.getString('username') ?? '',
      passwordHash: prefs.getString('passwordHash') ?? '',
      passwordSalt: prefs.getString('passwordSalt') ?? '',
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

  Future<void> updateAiConnection(String workerUrl, String proxyToken) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('aiWorkerUrl', workerUrl.trim());
    await prefs.setString('aiProxyToken', proxyToken.trim());
    state = state.copyWith(
      aiWorkerUrl: workerUrl.trim(),
      aiProxyToken: proxyToken.trim(),
    );
  }

  Future<void> setAiCategorizeConsent(bool consented) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool('aiCategorizeConsent', consented);
    state = state.copyWith(aiCategorizeConsent: consented);
  }

  /// Stores the username and a PBKDF2 digest of [password]. The password itself
  /// is never persisted. Hashing runs in an isolate -- 100k HMAC rounds would
  /// otherwise drop frames.
  Future<void> createAccount(String username, String password) async {
    final salt = PasswordHasher.generateSalt();
    final hash = await compute(
      _hashInIsolate,
      _HashRequest(password: password, salt: salt),
    );
    final prefs = ref.read(sharedPreferencesProvider);
    final trimmed = username.trim();
    await prefs.setString('username', trimmed);
    await prefs.setString('passwordHash', hash);
    await prefs.setString('passwordSalt', salt);
    state = state.copyWith(
      username: trimmed,
      passwordHash: hash,
      passwordSalt: salt,
    );
  }

  /// Verifies [password] against the stored digest. Returns false when no
  /// account exists, so a missing credential can never read as a valid unlock.
  Future<bool> verifyPassword(String password) async {
    if (!state.hasAccount) return false;
    final hash = await compute(
      _hashInIsolate,
      _HashRequest(password: password, salt: state.passwordSalt),
    );
    return PasswordHasher.constantTimeEquals(hash, state.passwordHash);
  }

  /// Re-hashes with a fresh salt. Callers must verify the current password
  /// first -- this method trusts that it has already happened.
  Future<void> changePassword(String password) async {
    await createAccount(state.username, password);
  }

  Future<void> clearAiConnection() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('aiWorkerUrl');
    await prefs.remove('aiProxyToken');
    // Disconnecting revokes consent: a new endpoint must be consented to afresh.
    await prefs.remove('aiCategorizeConsent');
    state = state.copyWith(
      aiWorkerUrl: '',
      aiProxyToken: '',
      aiCategorizeConsent: false,
    );
  }
}
