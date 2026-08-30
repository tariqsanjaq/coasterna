# FR-10 Code Review Input

Scope: `lib/features/auth/data/auth_repository.dart`, `lib/features/admin/presentation/admin_login_screen.dart`, plus a repository-pattern scan of `lib/`. Everything under `.claude/worktrees/` was excluded.

## 1. AuthRepository public API

Public members of `AuthRepository` in `lib/features/auth/data/auth_repository.dart`:

**Constructor — line 18**
```dart
AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;
```

**Getter — line 26**
```dart
User? get currentUser => _auth.currentUser;
```

**Method — lines 29-32 (signature)**
```dart
Future<void> signUp({
  required String email,
  required String password,
}) async {
```

**Method — lines 49-52 (signature)**
```dart
Future<void> signIn({
  required String email,
  required String password,
}) async {
```

**Method — line 69**
```dart
Future<void> signOut() => _auth.signOut();
```

**Method — line 79 (signature)**
```dart
Future<bool> isCurrentUserAdmin() async {
```

The only other member in the file is the private helper `String _signUpMessage(String code)` (line 94), which is not public.

The file also declares a second public class, `AuthFailure` (lines 6-12), with the public const constructor `const AuthFailure(this.message);` (line 7), the public field `final String message;` (line 8), and the override `String toString() => message;` (line 11).

## 2. AuthRepository imports

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
```

(lines 1-2; the file has no other import lines)

## 3. admin_login_screen.dart imports

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import 'admin_home_screen.dart';
```

(lines 1-4; the file has no other import lines)

- `package:firebase_auth/firebase_auth.dart` — **NOT PRESENT** in this file.
- `package:cloud_firestore/cloud_firestore.dart` — **NOT PRESENT** in this file.

## 4. Direct Firebase usage in admin_login_screen.dart

Searched identifiers: `FirebaseAuth`, `FirebaseFirestore`, `signInWithEmailAndPassword`, `currentUser`, `.collection(`, `.doc(`

NONE FOUND.

Note (case-sensitive search, as the identifiers were given): a case-insensitive search matches only the substring `CurrentUser` inside the repository call `isCurrentUserAdmin()` — line 9 (a doc comment) and line 51 (`final isAdmin = await _authRepository.isCurrentUserAdmin();`). Neither is an occurrence of the identifier `currentUser`.

## 5. The sign-in handler, verbatim

The login button at line 174 is `onPressed: _isLoading ? null : _signIn,`. The handler is `_signIn`, lines 33-86:

```dart
  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step 1: authenticate with Firebase Auth. This succeeds for
      // ANY valid account — student or admin — because Firebase Auth
      // is shared across the whole project. Being authenticated is
      // NOT the same as being an admin.
      await _authRepository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Step 2: confirm this specific account is actually listed in
      // the admins collection. This is the check that was missing.
      final isAdmin = await _authRepository.isCurrentUserAdmin();

      if (!isAdmin) {
        // Do not leave a non-admin signed in on this device.
        await _authRepository.signOut();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          // Safe to be specific here: these credentials were already
          // correct, so this message reveals nothing an attacker
          // couldn't already learn from a valid login attempt.
          _errorMessage =
          'This account is not authorized for the Admin Dashboard.';
        });
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong. Check your connection.';
      });
    }
  }
```

## 6. Admin membership check

The Firestore read against the `admins` collection happens **inside `AuthRepository`**, not inside `admin_login_screen.dart`.

`lib/features/auth/data/auth_repository.dart`, lines 79-89:

```dart
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
```

The membership read itself is `lib/features/auth/data/auth_repository.dart:84`:

```dart
      final doc = await _firestore.collection('admins').doc(uid).get();
```

`admin_login_screen.dart` only calls that method and branches on its result — `lib/features/admin/presentation/admin_login_screen.dart`, lines 51-66:

```dart
      final isAdmin = await _authRepository.isCurrentUserAdmin();

      if (!isAdmin) {
        // Do not leave a non-admin signed in on this device.
        await _authRepository.signOut();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          // Safe to be specific here: these credentials were already
          // correct, so this message reveals nothing an attacker
          // couldn't already learn from a valid login attempt.
          _errorMessage =
          'This account is not authorized for the Admin Dashboard.';
        });
        return;
      }
```

## 7. Repository-pattern violations across the whole app

Scanned all 23 `.dart` files under `lib/` for imports of `package:firebase_auth/firebase_auth.dart` or `package:cloud_firestore/cloud_firestore.dart` in files living under a `presentation/` folder.

| File path | Package imported | Line number |
| --- | --- | --- |
| `lib/features/admin/presentation/admin_home_screen.dart` | `package:firebase_auth/firebase_auth.dart` | 2 |

For completeness, the other files in `lib/` that import either package are **not** under a `presentation/` folder and therefore are not listed above:

| File path | Package imported | Line number |
| --- | --- | --- |
| `lib/core/models/route_model.dart` | `package:cloud_firestore/cloud_firestore.dart` | 1 |
| `lib/core/models/stop_model.dart` | `package:cloud_firestore/cloud_firestore.dart` | 1 |
| `lib/features/auth/data/auth_repository.dart` | `package:cloud_firestore/cloud_firestore.dart` | 1 |
| `lib/features/auth/data/auth_repository.dart` | `package:firebase_auth/firebase_auth.dart` | 2 |
| `lib/features/search/data/route_repository.dart` | `package:cloud_firestore/cloud_firestore.dart` | 2 |
