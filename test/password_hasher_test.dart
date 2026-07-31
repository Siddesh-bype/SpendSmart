import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/services/password_hasher.dart';

void main() {
  group('PasswordHasher', () {
    test('the correct password verifies and a wrong one does not', () {
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hash('correct horse battery', salt);

      expect(PasswordHasher.verify('correct horse battery', salt, hash), isTrue);
      expect(PasswordHasher.verify('wrong password', salt, hash), isFalse);
      // A near miss must fail as hard as a wild guess.
      expect(PasswordHasher.verify('correct horse batter', salt, hash), isFalse);
      expect(PasswordHasher.verify('', salt, hash), isFalse);
    });

    test('the password is not recoverable from the digest', () {
      const password = 'hunter2';
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hash(password, salt);

      expect(hash.contains(password), isFalse);
      expect(salt.contains(password), isFalse);
    });

    test('the same password under different salts gives different digests', () {
      // Without this, identical passwords collide and one rainbow table breaks
      // every install at once.
      const password = 'same-password';
      final first = PasswordHasher.generateSalt();
      final second = PasswordHasher.generateSalt();

      expect(first, isNot(second));
      expect(
        PasswordHasher.hash(password, first),
        isNot(PasswordHasher.hash(password, second)),
      );
    });

    test('hashing is deterministic for a given salt', () {
      final salt = PasswordHasher.generateSalt();
      expect(
        PasswordHasher.hash('repeatable', salt),
        PasswordHasher.hash('repeatable', salt),
      );
    });

    test('salts are unique across many draws', () {
      final salts = List.generate(100, (_) => PasswordHasher.generateSalt());
      expect(salts.toSet().length, 100, reason: 'salt generator repeated');
    });

    test('unicode and long passwords round-trip', () {
      final salt = PasswordHasher.generateSalt();
      const tricky = 'pässwörd-日本語-🔐';
      final hash = PasswordHasher.hash(tricky, salt);
      expect(PasswordHasher.verify(tricky, salt, hash), isTrue);

      final long = 'a' * 500;
      final longHash = PasswordHasher.hash(long, salt);
      expect(PasswordHasher.verify(long, salt, longHash), isTrue);
      expect(PasswordHasher.verify('a' * 499, salt, longHash), isFalse);
    });

    test('constantTimeEquals matches only on identical strings', () {
      expect(PasswordHasher.constantTimeEquals('abc', 'abc'), isTrue);
      expect(PasswordHasher.constantTimeEquals('abc', 'abd'), isFalse);
      expect(PasswordHasher.constantTimeEquals('abc', 'ab'), isFalse);
      expect(PasswordHasher.constantTimeEquals('', ''), isTrue);
    });

    test('the work factor is high enough to slow guessing', () {
      // A single fast hash is trivially brute-forced offline. If someone lowers
      // this constant for speed, that is a security regression, not a tuning
      // change -- fail loudly.
      expect(PasswordHasher.iterations, greaterThanOrEqualTo(100000));
    });
  });
}
