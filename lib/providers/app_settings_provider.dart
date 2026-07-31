import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../services/key_vault.dart';
import '../services/password_hasher.dart';

/// Sendable across an isolate boundary, unlike a closure over provider state.
class _HashRequest {
  const _HashRequest({required this.password, required this.salt});
  final String password;
  final String salt;
}

class _AccountRequest {
  const _AccountRequest({
    required this.password,
    required this.salt,
    required this.recoveryCode,
    required this.recoverySalt,
    required this.masterKey,
  });
  final String password;
  final String salt;
  final String recoveryCode;
  final String recoverySalt;
  final Uint8List masterKey;
}

class _AccountSetup {
  const _AccountSetup({
    required this.hash,
    required this.wrappedByPassword,
    required this.wrappedByRecovery,
  });
  final String hash;
  final String wrappedByPassword;
  final String wrappedByRecovery;
}

class _UnwrapRequest {
  const _UnwrapRequest({
    required this.secret,
    required this.salt,
    required this.wrapped,
  });
  final String secret;
  final String salt;
  final String wrapped;
}

/// Isolate entry points: must stay top-level.
String _hashInIsolate(_HashRequest request) =>
    PasswordHasher.hash(request.password, request.salt);

/// Three PBKDF2 runs at 100k rounds each -- firmly off the UI thread.
_AccountSetup _prepareAccount(_AccountRequest request) => _AccountSetup(
  hash: PasswordHasher.hash(request.password, request.salt),
  wrappedByPassword: KeyVault.wrap(
    request.masterKey,
    request.password,
    request.salt,
  ),
  wrappedByRecovery: KeyVault.wrap(
    request.masterKey,
    request.recoveryCode,
    request.recoverySalt,
  ),
);

List<int>? _unwrapInIsolate(_UnwrapRequest request) =>
    KeyVault.unwrap(request.wrapped, request.secret, request.salt);

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
      aiCategorizeConsent: prefs.getBool('aiCategorizeConsent') ?? false,
      username: prefs.getString('username') ?? '',
      passwordHash: prefs.getString('passwordHash') ?? '',
      passwordSalt: prefs.getString('passwordSalt') ?? '',
      wrappedKeyByPassword: prefs.getString('wrappedKeyByPassword') ?? '',
      wrappedKeyByRecovery: prefs.getString('wrappedKeyByRecovery') ?? '',
      recoverySalt: prefs.getString('recoverySalt') ?? '',
      aiSessionToken: prefs.getString('aiSessionToken') ?? '',
      aiAccountEmail: prefs.getString('aiAccountEmail') ?? '',
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

  /// Stores the username, a PBKDF2 digest of [password], and a master key
  /// wrapped by both the password and a freshly generated recovery code.
  ///
  /// Returns the recovery code. It is shown once and never stored in the clear,
  /// so the caller must display it before moving on.
  Future<String> createAccount(String username, String password) async {
    final salt = PasswordHasher.generateSalt();
    final recoverySalt = PasswordHasher.generateSalt();
    final recoveryCode = KeyVault.generateRecoveryCode();
    final masterKey = KeyVault.generateMasterKey();

    final setup = await compute(
      _prepareAccount,
      _AccountRequest(
        password: password,
        salt: salt,
        recoveryCode: KeyVault.normalizeRecoveryCode(recoveryCode),
        recoverySalt: recoverySalt,
        masterKey: masterKey,
      ),
    );

    final prefs = ref.read(sharedPreferencesProvider);
    final trimmed = username.trim();
    await prefs.setString('username', trimmed);
    await prefs.setString('passwordHash', setup.hash);
    await prefs.setString('passwordSalt', salt);
    await prefs.setString('wrappedKeyByPassword', setup.wrappedByPassword);
    await prefs.setString('wrappedKeyByRecovery', setup.wrappedByRecovery);
    await prefs.setString('recoverySalt', recoverySalt);
    state = state.copyWith(
      username: trimmed,
      passwordHash: setup.hash,
      passwordSalt: salt,
      wrappedKeyByPassword: setup.wrappedByPassword,
      wrappedKeyByRecovery: setup.wrappedByRecovery,
      recoverySalt: recoverySalt,
    );
    return recoveryCode;
  }

  /// Recovers the master key from [password], or null when it is wrong.
  ///
  /// Unwrapping is the real check: it fails closed on a bad password because
  /// the wrapped blob carries a MAC.
  Future<List<int>?> unlockWithPassword(String password) async {
    if (!state.hasAccount) return null;
    if (!state.isEncrypted) {
      // Account created before encryption shipped. Verify the old way, then
      // build a vault so the boxes are encrypted from this unlock onward.
      if (!await verifyPassword(password)) return null;
      return upgradeToEncrypted(password);
    }
    return compute(
      _unwrapInIsolate,
      _UnwrapRequest(
        secret: password,
        salt: state.passwordSalt,
        wrapped: state.wrappedKeyByPassword,
      ),
    );
  }

  /// Creates a master key and recovery wrapping for an account that predates
  /// encryption. Returns the key so the caller can open the boxes with it; the
  /// migration itself happens in [StorageService.init].
  ///
  /// The recovery code is regenerated here and surfaced through
  /// [pendingRecoveryCode] so the UI can show it once.
  Future<List<int>> upgradeToEncrypted(String password) async {
    final recoverySalt = PasswordHasher.generateSalt();
    final recoveryCode = KeyVault.generateRecoveryCode();
    final masterKey = KeyVault.generateMasterKey();

    final setup = await compute(
      _prepareAccount,
      _AccountRequest(
        password: password,
        salt: state.passwordSalt,
        recoveryCode: KeyVault.normalizeRecoveryCode(recoveryCode),
        recoverySalt: recoverySalt,
        masterKey: masterKey,
      ),
    );

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('wrappedKeyByPassword', setup.wrappedByPassword);
    await prefs.setString('wrappedKeyByRecovery', setup.wrappedByRecovery);
    await prefs.setString('recoverySalt', recoverySalt);
    state = state.copyWith(
      wrappedKeyByPassword: setup.wrappedByPassword,
      wrappedKeyByRecovery: setup.wrappedByRecovery,
      recoverySalt: recoverySalt,
    );
    pendingRecoveryCode = recoveryCode;
    return masterKey;
  }

  /// Set when an existing account is upgraded to encryption, so the unlock
  /// screen can show the new recovery code once. Cleared after display.
  String? pendingRecoveryCode;

  /// Recovers the master key from a recovery code, or null when it is wrong.
  Future<List<int>?> unlockWithRecoveryCode(String code) async {
    if (state.wrappedKeyByRecovery.isEmpty) return null;
    return compute(
      _unwrapInIsolate,
      _UnwrapRequest(
        secret: KeyVault.normalizeRecoveryCode(code),
        salt: state.recoverySalt,
        wrapped: state.wrappedKeyByRecovery,
      ),
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

  /// Re-hashes and rewraps the existing master key under the new password.
  ///
  /// Crucially it rewraps rather than generating a new key: a new key would
  /// leave every encrypted box unreadable. The recovery wrapping is untouched,
  /// so an old recovery code keeps working. Callers must verify the current
  /// password first -- this trusts that it has already happened.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final masterKey = await unlockWithPassword(currentPassword);
    if (masterKey == null) {
      throw StateError('Current password did not verify.');
    }

    final salt = PasswordHasher.generateSalt();
    final hash = await compute(
      _hashInIsolate,
      _HashRequest(password: newPassword, salt: salt),
    );
    final wrapped = masterKey.isEmpty
        ? ''
        : KeyVault.wrap(Uint8List.fromList(masterKey), newPassword, salt);

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('passwordHash', hash);
    await prefs.setString('passwordSalt', salt);
    if (wrapped.isNotEmpty) {
      await prefs.setString('wrappedKeyByPassword', wrapped);
    }
    state = state.copyWith(
      passwordHash: hash,
      passwordSalt: salt,
      wrappedKeyByPassword: wrapped.isEmpty ? null : wrapped,
    );
  }

  /// Stores the AI session returned by the Worker.
  Future<void> setAiSession(String token, String email) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('aiSessionToken', token);
    await prefs.setString('aiAccountEmail', email);
    state = state.copyWith(aiSessionToken: token, aiAccountEmail: email);
  }

  /// Drops the AI session. Consent is reset too: the next sign-in may be a
  /// different account, which has not agreed to anything yet.
  Future<void> clearAiSession() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('aiSessionToken');
    await prefs.remove('aiAccountEmail');
    await prefs.remove('aiCategorizeConsent');
    state = state.copyWith(
      aiSessionToken: '',
      aiAccountEmail: '',
      aiCategorizeConsent: false,
    );
  }
}
