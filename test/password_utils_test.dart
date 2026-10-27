import 'package:flutter_test/flutter_test.dart';
import 'package:petguardian/auth/password_utils.dart';

void main() {
  group('PasswordUtils', () {
    test('a password verifies against its own hash', () {
      final hash = PasswordUtils.hashPassword('Sifre123!');
      expect(PasswordUtils.verifyPassword('Sifre123!', hash), isTrue);
    });

    test('a wrong password does not verify', () {
      final hash = PasswordUtils.hashPassword('Sifre123!');
      expect(PasswordUtils.verifyPassword('sifre123!', hash), isFalse);
      expect(PasswordUtils.verifyPassword('', hash), isFalse);
      expect(PasswordUtils.verifyPassword('Sifre123! ', hash), isFalse);
    });

    test('the same password hashes differently every time (salted)', () {
      final a = PasswordUtils.hashPassword('AyniSifre');
      final b = PasswordUtils.hashPassword('AyniSifre');
      expect(a, isNot(equals(b)));
      // Both still verify, otherwise the salt broke the round trip.
      expect(PasswordUtils.verifyPassword('AyniSifre', a), isTrue);
      expect(PasswordUtils.verifyPassword('AyniSifre', b), isTrue);
    });

    test('hashes carry the bcrypt algorithm and cost prefix', () {
      final hash = PasswordUtils.hashPassword('Sifre123!');
      expect(hash, startsWith(r'$2'));
    });

    test('does not store the plaintext', () {
      expect(PasswordUtils.hashPassword('GizliSifre'), isNot(contains('GizliSifre')));
    });

    test('supports Turkish characters', () {
      const password = 'ŞifreĞüİöç123!';
      final hash = PasswordUtils.hashPassword(password);
      expect(PasswordUtils.verifyPassword(password, hash), isTrue);
    });

    test('verifyPassword tolerates a malformed hash instead of throwing', () {
      expect(PasswordUtils.verifyPassword('Sifre123!', 'not-a-bcrypt-hash'), isFalse);
      expect(PasswordUtils.verifyPassword('Sifre123!', ''), isFalse);
    });
  });
}