# D53 Part 2 — Settings/profile screen for signed-in students

Decision D53, part 2 of 2. Part 1 (name at sign-up, shown on the admin
Reports table) was already committed and is unchanged by this task.

`home_page.dart` is Gaith's area — D48 pre-approval applies. Noted
again in the suggested commit message at the bottom.

## Changes made

1. **New screen** — `lib/features/profile/presentation/profile_screen.dart`
   (`ProfileScreen`). Three independent things on one screen, matching
   the existing form-screen visual convention (card containers —
   `AppColors.surface` fill, `AppRadius.card` corners,
   `AppColors.surfaceBorder` border — `AppSpacing.md`/`.lg` gaps,
   `FilledButton` actions) already established by
   `student_signup_screen.dart` and `student_login_screen.dart`:

   - **Name section.** First/Last name fields pre-filled from
     `AuthRepository().currentUser?.displayName`, split on the first
     space via a new `splitDisplayName()` function (see below). Same
     non-empty-after-trim validation as the sign-up form. Save calls
     `user.updateDisplayName('$first $last')` then `await
     user.reload()` — the exact sequence D53 part 1 established in
     `student_signup_screen.dart`, not re-derived — then shows a
     SnackBar ("Name updated.").
   - **Password section.** Current/New/Confirm password fields.
     Client-side checks first (new-password length ≥ 6 — the same
     number as the sign-up form's "Password (6 characters or more)"
     hint; new matches confirm), then
     `EmailAuthProvider.credential(email:, password:)` →
     `user.reauthenticateWithCredential(credential)` →
     `user.updatePassword(newPassword)`, in that order, per Firebase
     Auth's requirement (skipping re-authentication throws
     `requires-recent-login`). A wrong current password is caught as
     `FirebaseAuthException` and mapped to a readable inline message
     ("That current password is incorrect.") rather than a raw
     exception — both `wrong-password` and `invalid-credential` codes
     are handled, since Firebase's backend has been consolidating
     credential-related codes and this project's Firebase Auth SDK
     version (`firebase_auth: ^6.5.7`, confirmed in `pubspec.yaml`)
     could surface either depending on backend config. On success, all
     three fields are cleared and a SnackBar confirms ("Password
     changed.").
   - **Sign out.** An `OutlinedButton.icon` at the bottom, styled in
     `AppColors.error` to read as a distinct/destructive action from
     the two save buttons above it. Its confirmation dialog and
     post-sign-out navigation are copied verbatim from the app-bar
     icon's `onPressed` that this task removes from `home_page.dart`
     (see "Sign-out navigation source" below) — not re-derived.

   Guest/edge case: `build()` checks `AuthRepository().currentUser ==
   null` first and renders a plain "You are not signed in." screen
   instead of the form if so. This is defensive only — the settings
   icon that opens `ProfileScreen` only renders in `home_page.dart`'s
   signed-in app-bar branch, so this path should never actually be
   reached in normal use.

2. **`home_page.dart`** — in the signed-in app-bar branch, the
   `Icons.logout` "Sign out" `IconButton` (and its `_signOut()` method,
   now dead code since nothing else called it) were removed. In their
   place: an `Icons.settings_outlined` "Settings" `IconButton` that
   does `Navigator.push(context, MaterialPageRoute(builder: (_) =>
   const ProfileScreen()))` — a normal forward push with a back arrow,
   not `pushAndRemoveUntil`, matching the existing Favorites icon's own
   navigation style right next to it (also a plain `Navigator.push`).
   The Favorites (star) and About (info) icons are unchanged.

3. **`AuthRepository`** — not touched. No wrapper method was added;
   `ProfileScreen` calls `_authRepository.currentUser` (the existing
   getter) and then `updateDisplayName()` /
   `reauthenticateWithCredential()` / `updatePassword()` /
   `EmailAuthProvider.credential()` directly on the returned `User`, as
   the task specified.

4. **`splitDisplayName()`** — extracted as a public (not
   underscore-prefixed) top-level function in `profile_screen.dart`,
   specifically so it's unit-testable: Dart's `_`-privacy is
   per-library (per-file), so a private top-level function could not
   be reached from a separate test file at all. This mirrors the
   existing pattern in `route_status_badge.dart`
   (`routeRunsToday`/`minutesUntilNextDeparture`/etc. — public
   top-level functions colocated with the widget, tested directly from
   `route_status_test.dart`). New tests in
   `test/profile_screen_test.dart` cover: normal "First Last", a name
   with more than one space (splits on the FIRST space only — "Ahmad Al
   Rawi" → `("Ahmad", "Al Rawi")`, not three parts), a single word with
   no space, `null` input, empty/whitespace-only input, and extra
   internal/leading/trailing whitespace.

## A locked-architecture deviation, flagged as instructed

CLAUDE.md's "Auth" rule states: "All authentication ... goes through
`AuthRepository`" and the general state-management rule says "Zero
direct Firebase calls outside `lib/features/*/data/`. Widgets never
import `cloud_firestore` or `firebase_auth` directly." This task's own
instructions explicitly directed the opposite for this screen — call
`FirebaseAuth`/`User` methods (`updateDisplayName`,
`reauthenticateWithCredential`, `updatePassword`,
`EmailAuthProvider.credential`) straight from `ProfileScreen`, and NOT
add repository wrapper methods that would just forward to those calls
with no added logic. I followed the task's explicit instruction rather
than the general rule, since the instruction was specific,
deliberate, and reasoned ("rather than inventing a new repository
layer for a screen that only touches the already-signed-in user's own
profile") — but per CLAUDE.md's own "flag it and ask instead of
silently deviating" guidance, I'm stating this plainly here rather than
letting it pass unremarked. `profile_screen.dart` now `import
'package:firebase_auth/firebase_auth.dart'` directly — the first
widget file in this project to do so explicitly (`student_signup_screen.dart`
reaches `User` members only through type inference on
`AuthRepository.signUp()`'s return value, without an explicit import).
If this should instead be pulled behind `AuthRepository` after all,
that's a follow-up, not something I decided unilaterally here.

## Sign-out navigation source

Copied from `home_page.dart`'s `_HomeViewState._signOut()` as it stood
immediately before this task removed it (added across D52/D53 part 1):
a `showDialog<bool>` confirmation ("Sign out?" / "You will need to
sign in again to use a saved account. You can still search buses as a
guest." / Cancel / Sign out), and on confirmation, `await
_authRepository.signOut()` then
`Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:
(_) => const StudentLoginScreen()), (route) => false)`. Both the
dialog copy and the navigation call are reproduced verbatim in
`ProfileScreen._signOut()`.

## Files modified

- `lib/features/profile/presentation/profile_screen.dart` — new file
  (`ProfileScreen`, `splitDisplayName()`).
- `lib/features/search/presentation/home_page.dart` — swapped the
  sign-out icon for a settings icon pushing `ProfileScreen`; removed
  the now-dead `_signOut()` method; added the `ProfileScreen` import.
- `test/profile_screen_test.dart` — new file, 7 tests for
  `splitDisplayName()`.

Not touched, per constraints: `ReportModel`, `ReportsRepository`,
`PendingIntentHolder`, the favorites flow, the admin Reports table, any
new package. No email change, account deletion, or avatar/photo upload
was added — name-edit, password-change, and sign-out are the only
three capabilities on this screen.

## flutter analyze output

```
No issues found! (ran in 1.5s)
```

Full raw output: `d53-part2-profile-screen-analyze.txt`.

## flutter test output

```
00:00 +79: All tests passed!
```

All 79 tests pass — the 72 that existed before this change, plus the 7
new `splitDisplayName()` tests in `test/profile_screen_test.dart`.

Full raw output: `d53-part2-profile-screen-test.txt`.

## What still needs manual verification

The following require a real device/emulator against the live
`coasterna-fa940` Firebase project — nothing in this session ran the
app:

1. **Open Settings from Home.** Sign in, confirm the app bar now shows
   About / Favorites / Settings (no separate sign-out icon), and
   tapping Settings pushes `ProfileScreen` with a back arrow (not a
   full nav-stack reset).
2. **Name fields pre-fill correctly.** For an account with a name set
   (any account created after D53 part 1 with a real first/last name),
   confirm both fields are pre-filled and split correctly. For one of
   the 9 pre-D53 test accounts, if one is reachable/known, confirm both
   fields start blank rather than showing an error or a placeholder.
3. **Edit and save the name.** Change either field, tap "Save name,"
   confirm the SnackBar appears and — without restarting the app —
   that the new name is what shows immediately elsewhere that reads
   `displayName` (e.g. submitting a report right after, per D53 part
   1's REPORTED BY column).
4. **Wrong current password.** Enter an incorrect current password
   with a valid new password, confirm a clear inline message ("That
   current password is incorrect.") appears — not a raw
   `FirebaseAuthException` dump — and that the new/confirm password
   fields are NOT silently accepted.
5. **Correct password change, end to end.** Enter the correct current
   password and a valid new password/confirm pair, confirm the success
   SnackBar and that all three fields clear. Then sign out and sign
   back in using the NEW password to confirm the change actually took
   effect server-side (not just locally).
6. **Sign out from the new screen behaves identically to the old
   app-bar icon.** Confirm the same confirmation dialog copy appears,
   and that confirming lands on the sign-in screen with the nav stack
   cleared (no back arrow returning to a signed-in Home) — matching
   the pre-this-task behavior described under "Sign-out navigation
   source" above.

## Suggested commit message

```
feat(profile): settings/profile screen for signed-in students (D53 part 2)

Gaith pre-approval D48 applies (home_page.dart).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_018uH7tcwu4EAGR9cCHf9DQM
```
