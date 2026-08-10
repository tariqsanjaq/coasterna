import 'package:firebase_auth/firebase_auth.dart';

/// Thrown when sign-in or sign-up fails. Carries a message that is
/// safe to show the user directly.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// All student authentication goes through this class. No screen
/// calls FirebaseAuth directly — the same architectural rule we
/// follow for Firestore in RouteRepository.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// The signed-in student, or null when nobody is signed in.
  User? get currentUser => _auth.currentUser;

  /// Creates a new student account, then leaves them signed in.
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_signUpMessage(e.code));
    } catch (_) {
      throw const AuthFailure('Something went wrong. Check your connection.');
    }
  }

  /// Signs an existing student in.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (_) {
      // SECURITY: every sign-in failure returns the SAME message.
      // Telling the user whether the email exists would let an
      // attacker discover which accounts are registered. This is the
      // same rule already applied on the admin login screen.
      throw const AuthFailure('Incorrect email or password.');
    } catch (_) {
      throw const AuthFailure('Something went wrong. Check your connection.');
    }
  }

  /// Signs the current student out.
  Future<void> signOut() => _auth.signOut();

  /// Sign-up errors CAN be specific: the user is choosing these
  /// values right now, so telling them what is wrong is helpful and
  /// does not leak anything they did not already type.
  String _signUpMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      default:
        return 'Could not create the account. Try again.';
    }
  }
}