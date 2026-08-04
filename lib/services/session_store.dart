import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keystore-backed storage for the AI session token.
///
/// The token is a bearer credential: anything holding it can spend the
/// account's AI quota until it expires. SharedPreferences is a plain XML file
/// readable by any process with the app's uid, and by anyone with a backup or
/// a rooted device, so the token lives here instead. The email and expiry are
/// not secrets and stay in prefs.
class SessionStore {
  const SessionStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'aiSessionToken';

  /// Returns an empty string when there is no token, or when the keystore
  /// entry cannot be decrypted — which happens after a restore onto a new
  /// device, where the right answer is to sign in again, not to crash.
  Future<String> readToken() async {
    try {
      return await _storage.read(key: _tokenKey) ?? '';
    } catch (_) {
      await deleteToken();
      return '';
    }
  }

  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // Already gone, or unreadable. Either way there is nothing to clear.
    }
  }

  /// Reads the token, first moving [legacyToken] into the keystore if an
  /// older build left one behind in SharedPreferences.
  ///
  /// Returns an empty string when [expiresAt] is in the past, and drops the
  /// stored token: an expired session can only produce 401s, so keeping it
  /// would leave the AI screens offering a button that cannot work.
  Future<String> loadMigrating(String? legacyToken, {int expiresAt = 0}) async {
    var token = legacyToken ?? '';
    if (token.isNotEmpty) {
      try {
        await writeToken(token);
      } catch (_) {
        // No keystore on this device. Signing in again is the recovery.
        return '';
      }
    } else {
      token = await readToken();
    }

    if (token.isNotEmpty &&
        expiresAt > 0 &&
        DateTime.now().millisecondsSinceEpoch >= expiresAt) {
      await deleteToken();
      return '';
    }
    return token;
  }
}
