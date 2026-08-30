# Review — uncommitted changes to `lib/main.dart`

**Date:** 2026-08-29
**Branch:** `dev`
**File under review:** `lib/main.dart` (modified, **unstaged and uncommitted**)
**Context:** fixes for the Task #14 audit (`docs/task14_audit_2026-08-29.md`), applied in
`docs/task14_fix_verification_2026-08-29.md`
**Standing in for:** Abdallah (repository-layer owner), currently unavailable

**Outcome: the diff passes every mechanical check.** Repository boundary intact, routing
symbols all resolve, theme wiring correct, `flutter analyze` clean, all 40 tests pass.
Four items are flagged for Abdallah at the end — none of them are defects in this diff,
but three concern the `AuthRepository` contract and startup sequencing in ways a
repository owner should rule on rather than have inferred.

**This was a read-only review.** No `git add`, `git commit`, or `git push` was run.

---

## Current diff

`git diff -- lib/main.dart`, full and unmodified:

```diff
warning: in the working copy of 'lib/main.dart', LF will be replaced by CRLF the next time Git touches it
diff --git a/lib/main.dart b/lib/main.dart
index dce6849..848ca64 100644
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -1,9 +1,11 @@
 import 'package:flutter/material.dart';
+import 'package:flutter/foundation.dart' show kIsWeb;
 import 'package:firebase_core/firebase_core.dart';
 import 'firebase_options.dart';

 import 'core/theme/app_theme.dart';
-import 'features/splash/prsentation/splash_screen.dart';
+import 'features/admin/presentation/admin_login_screen.dart';
+import 'features/splash/presentation/splash_screen.dart';

 void main() async {
   WidgetsFlutterBinding.ensureInitialized();
@@ -21,15 +23,10 @@ class CoasternaApp extends StatelessWidget {
     return MaterialApp(
       title: 'Coasterna',
       debugShowCheckedModeBanner: false,
-      theme: ThemeData(
-        useMaterial3: true,
-        scaffoldBackgroundColor: AppColors.background,
-        colorScheme: ColorScheme.fromSeed(
-          seedColor: AppColors.primary,
-          primary: AppColors.primary,
-        ),
-      ),
-      home: const SplashScreen(),
+      theme: appTheme,
+      // The Admin Dashboard is web-only: on web the app opens straight
+      // on the admin login gate, on mobile it opens the student splash.
+      home: kIsWeb ? const AdminLoginScreen() : const SplashScreen(),
     );
   }
-}
\ No newline at end of file
+}
```

The `LF will be replaced by CRLF` line is Git's routine Windows line-ending notice, not an
error. The `\ No newline at end of file` removal is incidental — the file previously
lacked a trailing newline and now has one.

Resulting file, in full (32 lines):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/theme/app_theme.dart';
import 'features/admin/presentation/admin_login_screen.dart';
import 'features/splash/presentation/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CoasternaApp());
}

class CoasternaApp extends StatelessWidget {
  const CoasternaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coasterna',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      // The Admin Dashboard is web-only: on web the app opens straight
      // on the admin login gate, on mobile it opens the student splash.
      home: kIsWeb ? const AdminLoginScreen() : const SplashScreen(),
    );
  }
}
```

---

## Repository boundary check

**Result: PASS — boundary intact, and stricter than before.**

### No direct Firebase data imports

Every import in `lib/main.dart`:

```
1: import 'package:flutter/material.dart';
2: import 'package:flutter/foundation.dart' show kIsWeb;
3: import 'package:firebase_core/firebase_core.dart';
4: import 'firebase_options.dart';
6: import 'core/theme/app_theme.dart';
7: import 'features/admin/presentation/admin_login_screen.dart';
8: import 'features/splash/presentation/splash_screen.dart';
```

* **`cloud_firestore` — not imported.** Confirmed.
* **`firebase_auth` — not imported.** Confirmed.
* `firebase_core` (line 3) **is** imported, and that is correct and unavoidable: it is
  needed for the `Firebase.initializeApp()` call at line 12, paired with the generated
  `firebase_options.dart` at line 4. `firebase_core` is SDK bootstrap, not data access —
  it exposes no queries, no documents, no auth state. The frozen rule in `CLAUDE.md`
  ("widgets never import `cloud_firestore` or `firebase_auth` directly") is not violated.
  `main()` is also the only sanctioned place for this call, per the same doc.
* Line 2's `show kIsWeb` is correctly scoped — it pulls one symbol from `foundation`
  rather than the whole library.

### Repository references

```
$ grep -n "Repository\|AuthRepository\|RouteRepository" lib/main.dart
(none - main.dart references NO repository class)
```

**`lib/main.dart` calls no repository method at all.** There is therefore no signature to
mismatch — the strongest possible form of a pass on this check.

For completeness, the two repository classes in the project and `AuthRepository`'s full
public surface (`lib/features/auth/data/auth_repository.dart`):

| Member | Line | Signature |
|---|---|---|
| `AuthRepository` (ctor) | `:18` | `AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})` |
| `currentUser` | `:26` | `User? get currentUser` |
| `signUp` | `:29` | `Future<void> signUp({required String email, required String password})` |
| `signIn` | `:49` | `Future<void> signIn({required String email, required String password})` |
| `signOut` | `:69` | `Future<void> signOut()` |
| `isCurrentUserAdmin` | `:79` | `Future<bool> isCurrentUserAdmin()` |

(`_signUpMessage` at `:94` is private. `AuthFailure` at `:6` is the public exception type.)
The other repository is `RouteRepository` (`lib/features/search/data/route_repository.dart:35`),
also unreferenced from `main.dart`.

### Note: this diff *removes* the last repository call from startup

Worth recording because it is a behavioural change, not a formatting one. The
pre-Task-#14 `main.dart` constructed a repository during startup:

```dart
final bool isSignedIn = AuthRepository().currentUser != null;
```

That line was deleted by commit `81434b9` (the Task #14 commit), and **this diff does not
restore it** — it restores only `theme:` and the `kIsWeb` branch. So `AuthRepository` is
no longer instantiated anywhere in the startup path.

Functionally this is benign: the old code used `isSignedIn` only to choose between
`HomePage` and `StudentLoginScreen` as the splash's `nextPage`, and the current guest-first
design routes everyone to `HomePage` regardless. A returning signed-in student still lands
on search, just via the splash rather than by a startup branch. The only remaining consumer
of `currentUser` is `home_page.dart:227`. Flagged for Abdallah below — not as a bug, but
because the startup auth read was his layer's contract and it is now gone.

---

## Routing logic check

**Result: PASS — both classes exist, both constructors match, no stale symbols.**

### Both target classes resolve, with compatible constructors

| Symbol | Declared at | Constructor | Call site in `main.dart:29` | Match |
|---|---|---|---|---|
| `AdminLoginScreen` | `admin_login_screen.dart:11` (`extends StatefulWidget`) | `const AdminLoginScreen({super.key})` — `:12` | `const AdminLoginScreen()` | Yes |
| `SplashScreen` | `splash_screen.dart:7` (`extends StatefulWidget`) | `const SplashScreen({super.key})` — `:8` | `const SplashScreen()` | Yes |

Both take **only** an optional `super.key`. **No required parameters are missing**, and
both are `const` constructors, so the `const` at both call sites is valid.

This is a meaningful check rather than a formality, because the `SplashScreen` that
`main.dart` used *before* Task #14 had a different signature —
`SplashScreen({super.key, required this.nextPage})`, taking a required `Widget nextPage`.
That class lived in the now-deleted `lib/core/presentation/splash_screen.dart`. The current
import resolves to the new no-arg `SplashScreen`, so `const SplashScreen()` is correct.
Had the import still pointed at the old file, this line would not compile.

### All four import paths resolve to files that exist

```
OK   lib/core/theme/app_theme.dart
OK   lib/features/admin/presentation/admin_login_screen.dart
OK   lib/features/splash/presentation/splash_screen.dart
OK   lib/firebase_options.dart
```

### No stale symbols

* **`MyApp`** — the old root widget class name, renamed to `CoasternaApp` by `81434b9`:
  ```
  $ grep -rn "MyApp" lib/ test/
  (no MyApp references in lib/ or test/)
  ```
  **Zero references.** The only hits anywhere in the repo are in
  `.claude/worktrees/remote-control-ad61b3/lib/main.dart` — a tooling worktree containing
  a stale copy of the file, outside the build and outside `lib/`. Not a concern, but noted
  so nobody is surprised by a repo-wide grep.
* **`prsentation`** — the misspelled folder path, renamed during the fix:
  ```
  $ grep -rn "prsentation" lib/ test/
  (no 'prsentation' references remain)
  ```
  **Zero references.** The import at line 8 was updated in the same pass as the rename.
* **`SplashScreen` ambiguity** — previously two distinct classes shared this name
  (`core/presentation/` and `features/splash/prsentation/`). The `core/` one was deleted,
  so exactly one `SplashScreen` now exists project-wide. No collision risk remains.
* **`AppColors`** — the inline `ThemeData` was the only user of `AppColors.background` /
  `AppColors.primary` in this file, and it is gone. The `core/theme/app_theme.dart` import
  at line 6 is **still required**, now for `appTheme` itself, so it has not become an
  unused import. `flutter analyze` confirms (no `unused_import` lint).

### Routing behaviour as written

`kIsWeb` is a compile-time constant, so the ternary is tree-shaken per platform: the web
build boots directly into `AdminLoginScreen`, and mobile/desktop builds boot into
`SplashScreen` (which auto-advances to `HomePage` after 1000 ms). This matches the frozen
decision in `CLAUDE.md` — *"`AdminLoginScreen` (reached as the home route when `kIsWeb`,
in `main.dart`) gates the Admin Dashboard"* — and restores the behaviour that `81434b9`
had removed.

---

## Theme check

**Result: PASS.**

* **Symbol exists and is public:** `lib/core/theme/app_theme.dart:71` declares
  `final ThemeData appTheme = ThemeData(...)`, a top-level, non-underscored (therefore
  exported) variable of exactly the type `MaterialApp.theme` expects. Its doc comment at
  `:70` — *"applied once in main.dart via MaterialApp(theme: appTheme)"* — describes the
  code again, having been inaccurate while the inline `ThemeData` was in place.
* **Import path correct:** `main.dart:6` is `import 'core/theme/app_theme.dart';`.
  `main.dart` sits at `lib/`, so the relative path resolves to
  `lib/core/theme/app_theme.dart`. Confirmed present.
* **Type check:** `appTheme` is `ThemeData`; `MaterialApp.theme` is `ThemeData?`. Assignment
  is valid, confirmed by a clean analyze.

### What restoring `appTheme` puts back

The inline replacement it supersedes set only `useMaterial3`, `scaffoldBackgroundColor`,
and a two-field `ColorScheme.fromSeed`. `appTheme` (`app_theme.dart:71-109`) additionally
supplies:

| Restored | Line |
|---|---|
| `error: AppColors.error`, `surface: AppColors.surface` in the colorScheme | `:76-77` |
| `textTheme: Typography.material2021().black.apply(...)` forcing `AppColors.textPrimary` | `:80-83` |
| `elevatedButtonTheme` — navy bg, white fg, `Size.fromHeight(48)`, 8px radius | `:84-93` |
| `cardTheme` — surface color, elevation 1, 12px radius, bordered | `:94-101` |
| `inputDecorationTheme` — `filled: true`, white fill, 8px `OutlineInputBorder` | `:102-108` |

The `inputDecorationTheme` restoration is the one with visible effect: five `TextField`s
pass a bare `InputDecoration` and depend entirely on the theme —
`student_login_screen.dart:105,114` and `student_signup_screen.dart:99,108,124`. They
return to the certified filled-and-rounded style.

**Side effect worth stating plainly:** `theme:` is app-wide, so this changes rendering on
every screen, including all Admin Dashboard screens. That is a return to the state those
screens were originally built and reviewed under (`appTheme` was live until `81434b9`), not
a novel styling change — but it is broader than the two lines of the diff suggest, and it
is worth one visual pass over the admin forms before submission.

`app_theme.dart:5-7` requires that any change to these values be mirrored in the report
(Ch. 5.2). This diff changes no values — it restores the single source of truth as the
one actually in use — so no report update is triggered.

---

## flutter analyze

Full unmodified output:

```
Resolving dependencies...
Downloading packages...
  _flutterfire_internals 1.3.76 (1.3.77 available)
  cli_util 0.4.2 (0.6.0 available)
  clock 1.1.2 (1.1.3 available)
  cloud_firestore 6.8.0 (6.9.0 available)
  cloud_firestore_platform_interface 8.0.6 (8.0.7 available)
  cloud_firestore_web 5.7.2 (5.7.3 available)
  code_assets 1.2.1 (2.0.0 available)
  firebase_auth 6.5.7 (6.6.1 available)
  firebase_auth_platform_interface 9.0.6 (9.0.7 available)
  firebase_auth_web 6.2.6 (6.2.7 available)
  firebase_core 4.13.0 (4.14.0 available)
  firebase_core_platform_interface 8.1.0 (8.1.1 available)
  firebase_core_web 3.10.0 (3.11.0 available)
  flutter_launcher_icons 0.13.1 (0.14.4 available)
  hooks 2.0.2 (2.2.0 available)
  matcher 0.12.19 (0.12.20 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  meta 1.18.0 (1.19.0 available)
  objective_c 9.5.0 (9.6.0 available)
  pub_semver 2.2.0 (2.2.1 available)
  record_use 0.6.0 (1.1.1 available)
  shared_preferences_android 2.4.27 (2.4.28 available)
  shared_preferences_foundation 2.5.6 (2.5.7 available)
  stack_trace 1.12.1 (1.12.2 available)
  test_api 0.7.11 (0.7.13 available)
  url_launcher_android 6.3.32 (6.3.33 available)
  url_launcher_ios 6.4.1 (6.4.2 available)
  url_launcher_linux 3.2.2 (3.2.3 available)
  url_launcher_macos 3.2.5 (3.2.6 available)
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.2 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
33 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing coasterna_project...

No issues found! (ran in 10.2s)
```

**Clean — 0 issues.** For this particular diff the analyzer carries real weight: it proves
both new imports resolve, `kIsWeb` is correctly scoped from `foundation`, both widget
constructors accept a no-arg `const` invocation, `appTheme` exists with the right type, and
no import became unused. (That is a narrower claim than "the change is correct" — the
Task #14 audit found five defects while analyze was equally clean.)

---

## flutter test

**A test suite exists, but no test covers `lib/main.dart`.** Stated explicitly rather than
skipped.

`test/` contains two files, and neither imports `main.dart`, `CoasternaApp`,
`AdminLoginScreen`, or `SplashScreen`:

```
test/route_model_test.dart:1: import 'package:flutter_test/flutter_test.dart';
test/route_model_test.dart:2: import 'package:coasterna_project/core/models/route_model.dart';
test/route_status_test.dart:9:  import 'package:cloud_firestore/cloud_firestore.dart';
test/route_status_test.dart:10: import 'package:flutter_test/flutter_test.dart';
test/route_status_test.dart:12: import 'package:coasterna_project/core/models/route_model.dart';
test/route_status_test.dart:13: import 'package:coasterna_project/features/search/presentation/widgets/route_status_badge.dart';
test/route_status_test.dart:14: import 'package:coasterna_project/features/trip/presentation/trip_details_screen.dart';
```

They cover model serialisation and route-status/scheduling logic. **There is no widget test
and no startup test**, so `flutter test` passing says nothing about the `kIsWeb` branch or
the theme wiring — those are covered here only by `flutter analyze` and by reading the
code. The suite is run and recorded below as a no-regression check.

Side note: the default `test/widget_test.dart` counter smoke test that `CLAUDE.md` warns
about **no longer exists** — it has been removed and replaced by these two real suites.
That section of `CLAUDE.md` is out of date and could be corrected on a future pass.

Full unmodified output (dependency preamble identical to the analyze run above, elided
only where it repeats verbatim — the test results themselves are complete):

```
Resolving dependencies...
Downloading packages...
  [... identical 33-package "newer versions available" list as in the analyze run above ...]
Got dependencies!
33 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading C:/Users/Tariq/coasterna_project/test/route_model_test.dart
00:00 +0: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: RouteStop fromJson and toJson round-trip preserves all fields
00:00 +1: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: parseTimeOnDay parses a valid HH:mm string onto the reference date
00:00 +2: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: DepartureType fromFirestore maps SCHEDULED and WHEN_FULL correctly
00:00 +3: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: parseTimeOnDay accepts a single-digit hour
00:00 +4: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: DepartureType toFirestore is the exact inverse of fromFirestore
00:00 +5: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: parseTimeOnDay returns null when the colon is missing
00:00 +6: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: DepartureType fromFirestore throws ArgumentError on an unknown value
00:00 +7: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: DepartureType fromFirestore throws ArgumentError on an unknown value
00:00 +8: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: parseTimeOnDay returns null when the hour is out of range
00:00 +9: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: RouteDirection fromFirestore maps OUTBOUND and RETURN correctly
00:00 +10: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: parseTimeOnDay returns null when the minute is out of range
00:00 +11: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: RouteDirection toFirestore is the exact inverse of fromFirestore
00:00 +12: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeRunsToday returns true when today is in operatingDays
00:00 +13: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: RouteDirection fromFirestore throws ArgumentError on an unknown value
00:00 +14: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeRunsToday returns false when today is not in operatingDays
00:00 +15: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeRunsToday is not confused by lowercase values in the data
00:00 +16: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeRunsToday an empty operatingDays list means the route runs every day
00:00 +17: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture returns null when frequencyMinutes is null
00:00 +18: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture returns null when frequencyMinutes is zero or negative
00:00 +19: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture returns null when firstDeparture cannot be parsed
00:00 +20: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture returns null before the service has started for the day
00:00 +21: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture computes the wait from firstDeparture and frequency
00:00 +22: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture returns a full interval when standing exactly at a departure
00:00 +23: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture returns null when the next bus would fall after lastDeparture
00:00 +24: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeDepartureRank a route that does not run today ranks below everything else
00:00 +25: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeDepartureRank a WHEN_FULL route ranks below any scheduled route today
00:00 +26: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeDepartureRank a WHEN_FULL route still ranks above a route not running today
00:00 +27: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeDepartureRank before service starts, the rank is the wait until the first bus
00:00 +28: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeDepartureRank sorting a mixed list puts the soonest bus first
00:00 +29: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: formatOperatingDays collapses an unbroken run of days into a range
00:00 +30: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: formatOperatingDays lists days separately when there is a gap
00:00 +31: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: formatOperatingDays sorts into week order regardless of the order in Firestore
00:00 +32: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: formatOperatingDays an empty list reads as every day
00:00 +33: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: formatOperatingDays a single day is shown on its own
00:00 +34: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: formatOperatingDays unknown day codes do not crash the screen
00:00 +35: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: RouteModel.toFirestore writes enums as their agreed Firestore strings
00:00 +36: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: RouteModel.toFirestore writes collectedOn as a Firestore Timestamp, not a DateTime
00:00 +37: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: RouteModel.toFirestore does not write the document id into the document body
00:00 +38: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: RouteModel.toFirestore keeps a null frequencyMinutes as null
00:00 +39: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: RouteModel.toFirestore serialises embedded waypoints in the order given
00:00 +40: All tests passed!
```

**40 tests, all passed.** No regression — and no coverage of the changed file.

---

## Needs Abdallah's attention

Four items. **None is a defect in this diff** — all four passed the checks above. They are
listed because they touch auth behaviour, the `AuthRepository` contract, or startup
sequencing in ways that should be his call rather than an assumption made in his absence.

### 1. Startup no longer reads auth state at all — the repository call was dropped, not restored

Before Task #14, `main.dart` did this at startup:

```dart
final bool isSignedIn = AuthRepository().currentUser != null;
```

and used it to pick the splash's destination. Commit `81434b9` deleted it; **this diff
restored the theme and the web route but deliberately did not restore that line.** So
`AuthRepository` is now constructed nowhere in the startup path, and `currentUser` is read
in exactly one place in the whole app: `home_page.dart:227`, inside `build()`.

The end destination is unchanged (everyone reaches `HomePage`, which is guest-accessible by
frozen design), so there is no user-visible regression. But the decision *"startup does not
consult auth state"* is now implicit in the absence of a line rather than stated anywhere.
**Abdallah should confirm that is intended**, and if so it is worth a one-line comment in
`main()` saying so, since the deleted code carried a five-line comment explaining the
opposite behaviour.

### 2. `AuthRepository` has no reactive surface, and the one `currentUser` consumer reads it during `build()`

```
$ grep -n "authStateChanges\|Stream<" lib/features/auth/data/auth_repository.dart
(no Stream / authStateChanges - currentUser is a sync getter only)
```

`AuthRepository` exposes `currentUser` as a **synchronous getter** (`:26`) and nothing else
— no `Stream<User?>`, no `authStateChanges()` passthrough. Meanwhile `home_page.dart:227`
decides between the "Sign in" and "Sign out" AppBar icons by reading that getter inside
`build()`, with nothing subscribing to auth changes.

Firebase Auth restores a persisted session **asynchronously** after `initializeApp()`
returns. If restoration completes after `HomePage`'s first build, the AppBar will show
"Sign in" to an already-signed-in student until some unrelated `setState` forces a rebuild.
The 1000 ms splash delay makes this unlikely in practice and it is **pre-existing**, not
introduced here — but this diff is what puts the app back into a shape where the startup
path and the auth path are worth reasoning about together. Whether `AuthRepository` should
grow an `authStateChanges` stream is a repository-contract decision that is squarely
Abdallah's, and it interacts with the pending student-favourites scope item.

### 3. The web branch routes 100% of web traffic to the admin gate — including students

`home: kIsWeb ? const AdminLoginScreen() : const SplashScreen()` restores the documented
frozen behaviour, and restoring it was the whole point of the fix. The consequence worth
his explicit sign-off: **a student who opens the app in a browser gets the admin login
form**, with no path to the student flow at all. There is no "I'm a student" escape hatch
on `AdminLoginScreen`.

That is exactly what `CLAUDE.md` specifies and I have not changed it. But it is an
auth-surface decision that a repository owner would normally want to affirm before
submission — particularly since `AdminLoginScreen` calls `signIn()` and then
`isCurrentUserAdmin()` (`auth_repository.dart:49, 79`), so a *student's* credentials typed
into that form will authenticate successfully against the shared `FirebaseAuth.instance`
and only then be rejected by the admin check. The student ends up signed in to a UI that
tells them they are not an admin. Worth confirming that is acceptable for the demo.

### 4. `Firebase.initializeApp()` is unguarded, and the web branch now depends on it

`main()` awaits `Firebase.initializeApp()` (`main.dart:12-14`) with no `try`/`catch`, no
`runZonedGuarded`, and no `FlutterError.onError`. If initialisation throws — bad config,
an offline first launch on web — the app dies before `runApp` with a grey screen and no
message.

**Pre-existing and untouched by this diff.** It is raised here only because restoring the
`kIsWeb` route makes the web build a real entry point again, and web is the platform where
Firebase init is most likely to fail at load time. Startup sequencing and failure handling
are Abdallah's area; a short `try`/`catch` rendering a "Could not start — check your
connection" scaffold would be cheap insurance before the demo, but it is beyond the scope
of this fix and should not be added without his say-so.

### Not requiring his attention

The theme restoration (`theme: appTheme`), the folder-typo rename, and the import updates
are mechanical, fully verified, and carry no auth or repository implications. The one
judgement call embedded in the diff is the two-line explanatory comment at `main.dart:27-28`
— it asserts *"The Admin Dashboard is web-only"*, which restates `CLAUDE.md` and was
written during the fix rather than by the file's owner. If Abdallah would phrase the intent
differently, that comment is the place to change.
