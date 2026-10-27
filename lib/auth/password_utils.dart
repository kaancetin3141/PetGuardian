import 'package:bcrypt/bcrypt.dart';

class PasswordUtils {
  /// Hashes [password] with a fresh random salt.
  ///
  /// The result is self-contained (`$2<cost>$<salt><digest>`), so the salt does
  /// not need to be stored separately.
  static String hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  /// Checks [password] against [hash].
  ///
  /// Returns `false` for any hash that is not a well-formed bcrypt hash rather
  /// than letting `BCrypt` throw. A user document can legitimately hold an
  /// empty or corrupted `passwordHash` (for example an account created straight
  /// through Firebase Auth), and that must read as "wrong password" instead of
  /// crashing the caller.
  static bool verifyPassword(String password, String hash) {
    if (hash.isEmpty) return false;
    try {
      return BCrypt.checkpw(password, hash);
    } catch (_) {
      return false;
    }
  }
}