import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Thrown when sign-in or sign-up fails. Carries a message that is
/// safe to show the user directly.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// All authentication — student AND admin — goes through this class.
/// No screen calls FirebaseAuth or Firestore directly — the same
/// architectural rule we follow for Firestore in RouteRepository.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// The signed-in user, or null when nobody is signed in.
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

  /// Signs an existing user in. Used by BOTH the student login screen
  /// and the admin login screen — this method does not know or care
  /// whether the account turns out to be an admin. That check happens
  /// separately, via isCurrentUserAdmin(), after a successful sign-in.
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
      // attacker discover which accounts are registered.
      throw const AuthFailure('Incorrect email or password.');
    } catch (_) {
      throw const AuthFailure('Something went wrong. Check your connection.');
    }
  }

  /// Signs the current user out.
  Future<void> signOut() => _auth.signOut();

  /// True only if the currently signed-in user has a matching document
  /// in the admins collection. Must be called AFTER a successful
  /// signIn() — it reads the already-signed-in user, it does not sign
  /// anyone in itself.
  ///
  /// Fails CLOSED: if nobody is signed in, if the read is denied, or
  /// if anything else goes wrong (offline, etc.), this returns false.
  /// Never let an error here be mistaken for "yes, admin".
  Future<bool> isCurrentUserAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final doc = await _firestore.collection('admins').doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

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