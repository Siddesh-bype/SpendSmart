import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Local, offline credential checking for the app lock.
///
/// The password never leaves the device and is never stored. Only a PBKDF2
/// digest and its salt are kept, so reading the app's preferences off a rooted
/// phone does not reveal the password.
///
/// PBKDF2-HMAC-SHA256 rather than a bare SHA-256: a single hash is far too fast
/// to brute-force, since a four-digit-style password falls in milliseconds. The
/// iteration count deliberately costs ~100ms on a mid-range phone -- slow enough
/// to make guessing expensive, fast enough that unlocking feels instant.
///
/// ponytail: PBKDF2 over Argon2id because it needs no new dependency (`crypto`
/// was already a transitive dep). Move to Argon2id if the threat model ever
/// includes an attacker with GPUs and a stolen backup.
class PasswordHasher {
  static const int iterations = 100000;
  static const int _saltBytes = 16;
  static const int _keyBytes = 32;

  /// Cryptographically secure; falls back only if the platform lacks one.
  static final Random _random = Random.secure();

  const PasswordHasher._();

  static String generateSalt() {
    final bytes = Uint8List(_saltBytes);
    for (var i = 0; i < _saltBytes; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  /// Derives a digest for [password] using [salt] from [generateSalt].
  ///
  /// Runs ~100k HMAC rounds, so call it off the UI thread if the frame budget
  /// matters. At unlock time it happens once, behind a spinner.
  static String hash(String password, String salt) {
    final saltBytes = base64Url.decode(salt);
    final passwordBytes = utf8.encode(password);
    return base64Url.encode(_pbkdf2(passwordBytes, saltBytes));
  }

  /// Constant-time comparison. A plain `==` leaks how many leading characters
  /// matched via timing, which narrows a guess one character at a time.
  static bool verify(String password, String salt, String expectedHash) {
    return constantTimeEquals(hash(password, salt), expectedHash);
  }

  /// Compares two digests without an early exit on the first difference.
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }

  /// PBKDF2-HMAC-SHA256 (RFC 8018). One output block is enough: SHA-256 emits
  /// 32 bytes, which is exactly [_keyBytes].
  static Uint8List _pbkdf2(List<int> password, List<int> salt) {
    final hmac = Hmac(sha256, password);

    // Block index 1, big-endian, appended to the salt per the spec.
    final block = <int>[...salt, 0, 0, 0, 1];
    var current = Uint8List.fromList(hmac.convert(block).bytes);
    final result = Uint8List.fromList(current);

    for (var i = 1; i < iterations; i++) {
      current = Uint8List.fromList(hmac.convert(current).bytes);
      for (var j = 0; j < _keyBytes; j++) {
        result[j] ^= current[j];
      }
    }
    return result;
  }
}
