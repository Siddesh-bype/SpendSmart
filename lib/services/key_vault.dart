import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Wraps and unwraps the Hive master key.
///
/// The boxes are encrypted with a random 32-byte master key, not with the
/// password directly. That key is stored twice, wrapped once by a
/// password-derived key and once by a recovery-code-derived key, so:
///
///  * either secret can open the data;
///  * changing the password rewraps 32 bytes instead of re-encrypting every
///    box, which would otherwise risk data loss on every change.
///
/// Wrapping is XOR with a PBKDF2-derived keystream plus a MAC. XOR is safe
/// here specifically because each derived key is used to wrap exactly one
/// value one time -- the keystream reuse that breaks XOR never happens.
class KeyVault {
  static const int _keyBytes = 32;
  static final Random _random = Random.secure();

  const KeyVault._();

  /// A fresh master key for encrypting the Hive boxes.
  static Uint8List generateMasterKey() => _randomBytes(_keyBytes);

  /// A human-transcribable recovery code, e.g. `4RXT-9K2M-PQW7-H3ND`.
  ///
  /// Crockford-style alphabet: no I, L, O, U, so it cannot be misread as 1/0
  /// or spell anything unfortunate. 16 chars over 32 symbols is 80 bits.
  static String generateRecoveryCode() {
    const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    final chars = List.generate(
      16,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    );
    final groups = <String>[
      for (var i = 0; i < 16; i += 4) chars.sublist(i, i + 4).join(),
    ];
    return groups.join('-');
  }

  /// Accepts a code with any spacing or casing the user typed.
  static String normalizeRecoveryCode(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

  /// Wraps [masterKey] with a key derived from [secret] and [salt].
  ///
  /// Returns base64 of `mac(32) || ciphertext(32)`. The MAC is what makes a
  /// wrong password detectable -- without it, a bad password would silently
  /// yield garbage and Hive would fail with an unreadable corruption error.
  static String wrap(Uint8List masterKey, String secret, String salt) {
    final derived = _derive(secret, salt);
    final ciphertext = Uint8List(_keyBytes);
    for (var i = 0; i < _keyBytes; i++) {
      ciphertext[i] = masterKey[i] ^ derived[i];
    }
    final mac = Hmac(sha256, derived).convert(ciphertext).bytes;
    return base64.encode([...mac, ...ciphertext]);
  }

  /// Reverses [wrap]. Returns null when [secret] is wrong or the blob is
  /// damaged, so callers can show "incorrect password" rather than crashing.
  static Uint8List? unwrap(String wrapped, String secret, String salt) {
    final List<int> raw;
    try {
      raw = base64.decode(wrapped);
    } catch (_) {
      return null;
    }
    if (raw.length != _keyBytes * 2) return null;

    final mac = raw.sublist(0, _keyBytes);
    final ciphertext = raw.sublist(_keyBytes);
    final derived = _derive(secret, salt);

    final expected = Hmac(sha256, derived).convert(ciphertext).bytes;
    var difference = 0;
    for (var i = 0; i < _keyBytes; i++) {
      difference |= mac[i] ^ expected[i];
    }
    if (difference != 0) return null;

    final masterKey = Uint8List(_keyBytes);
    for (var i = 0; i < _keyBytes; i++) {
      masterKey[i] = ciphertext[i] ^ derived[i];
    }
    return masterKey;
  }

  /// PBKDF2-HMAC-SHA256. Same work factor as the login hash: one output block
  /// is exactly 32 bytes, which is the key size.
  static Uint8List _derive(String secret, String salt) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final saltBytes = base64Url.decode(salt);

    var current = Uint8List.fromList(
      hmac.convert(<int>[...saltBytes, 0, 0, 0, 1]).bytes,
    );
    final result = Uint8List.fromList(current);
    for (var i = 1; i < 100000; i++) {
      current = Uint8List.fromList(hmac.convert(current).bytes);
      for (var j = 0; j < _keyBytes; j++) {
        result[j] ^= current[j];
      }
    }
    return result;
  }

  static Uint8List _randomBytes(int count) {
    final bytes = Uint8List(count);
    for (var i = 0; i < count; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}
