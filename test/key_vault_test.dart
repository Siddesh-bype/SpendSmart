import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/services/key_vault.dart';
import 'package:spendsmart/services/password_hasher.dart';

void main() {
  group('KeyVault', () {
    test('the master key survives a wrap/unwrap round-trip', () {
      final key = KeyVault.generateMasterKey();
      final salt = PasswordHasher.generateSalt();
      final wrapped = KeyVault.wrap(key, 'my-password', salt);

      expect(KeyVault.unwrap(wrapped, 'my-password', salt), key);
    });

    test('a wrong secret returns null instead of garbage', () {
      // This is the whole point of the MAC. Returning wrong bytes would hand
      // Hive an invalid key and surface as data corruption, not a bad password.
      final key = KeyVault.generateMasterKey();
      final salt = PasswordHasher.generateSalt();
      final wrapped = KeyVault.wrap(key, 'right', salt);

      expect(KeyVault.unwrap(wrapped, 'wrong', salt), isNull);
      expect(KeyVault.unwrap(wrapped, 'righ', salt), isNull);
      expect(KeyVault.unwrap(wrapped, '', salt), isNull);
    });

    test('the same key wrapped by password and recovery code both open it', () {
      // Either secret must recover the identical master key, or the recovery
      // path would decrypt to a different key and lose the data.
      final key = KeyVault.generateMasterKey();
      final passwordSalt = PasswordHasher.generateSalt();
      final recoverySalt = PasswordHasher.generateSalt();
      final code = KeyVault.generateRecoveryCode();

      final byPassword = KeyVault.wrap(key, 'pw', passwordSalt);
      final byCode = KeyVault.wrap(key, code, recoverySalt);

      expect(KeyVault.unwrap(byPassword, 'pw', passwordSalt), key);
      expect(KeyVault.unwrap(byCode, code, recoverySalt), key);
    });

    test('a tampered blob is rejected', () {
      final key = KeyVault.generateMasterKey();
      final salt = PasswordHasher.generateSalt();
      final wrapped = KeyVault.wrap(key, 'pw', salt);

      // Flip one character of the base64 payload.
      final chars = wrapped.split('');
      chars[5] = chars[5] == 'A' ? 'B' : 'A';
      expect(KeyVault.unwrap(chars.join(), 'pw', salt), isNull);

      expect(KeyVault.unwrap('not-base64!!', 'pw', salt), isNull);
      expect(KeyVault.unwrap('', 'pw', salt), isNull);
      // Right length, wrong content.
      expect(KeyVault.unwrap('A' * 88, 'pw', salt), isNull);
    });

    test('the wrapped blob does not leak the key', () {
      final key = KeyVault.generateMasterKey();
      final salt = PasswordHasher.generateSalt();
      final wrapped = KeyVault.wrap(key, 'pw', salt);

      // The ciphertext must differ from the plaintext key everywhere that
      // matters -- a zero keystream would make wrap() a no-op.
      expect(wrapped.contains(String.fromCharCodes(key)), isFalse);
    });

    test('master keys and recovery codes are unique', () {
      final keys = List.generate(50, (_) => KeyVault.generateMasterKey());
      final seen = keys.map((k) => k.join(',')).toSet();
      expect(seen.length, 50, reason: 'master key generator repeated');

      final codes = List.generate(50, (_) => KeyVault.generateRecoveryCode());
      expect(codes.toSet().length, 50, reason: 'recovery code repeated');
    });

    test('recovery codes are readable and unambiguous', () {
      final code = KeyVault.generateRecoveryCode();
      expect(code, matches(RegExp(r'^[0-9A-Z]{4}(-[0-9A-Z]{4}){3}$')));
      // I, L, O and U are excluded so 1/l and 0/O cannot be confused.
      expect(code.contains(RegExp('[ILOU]')), isFalse);
    });

    test('a recovery code is accepted however the user types it', () {
      final code = KeyVault.generateRecoveryCode();
      final stripped = code.replaceAll('-', '');

      expect(KeyVault.normalizeRecoveryCode(code), stripped);
      expect(KeyVault.normalizeRecoveryCode(code.toLowerCase()), stripped);
      expect(KeyVault.normalizeRecoveryCode('  $code  '), stripped);
      expect(KeyVault.normalizeRecoveryCode(code.replaceAll('-', ' ')), stripped);
    });
  });
}
