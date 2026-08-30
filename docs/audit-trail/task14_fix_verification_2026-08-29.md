# Task #14 Fix Verification

**Date:** 2026-08-29
**Branch:** `dev`
**Fixes source:** `docs/task14_audit_2026-08-29.md`
**Working tree only — nothing was staged or committed.**

All 5 issues from the audit were fixed. `flutter analyze` is clean. One item remains
open and is a team decision, not a bug (see Summary).

---

## What changed

| # | Issue | File | Status |
|---|---|---|---|
| 1a | Admin Dashboard unreachable (`kIsWeb` route deleted) | `lib/main.dart` | Fixed |
| 1b | App-wide theme replaced by weaker inline `ThemeData` | `lib/main.dart` | Fixed |
| 2 | Broken asset path on Admin login logo | `lib/features/admin/presentation/admin_login_screen.dart:118` | Fixed |
| 3 | Dead file with a second broken asset path | `lib/core/presentation/splash_screen.dart` | Deleted |
| 4a | Misspelled folder `prsentation` | `lib/features/splash/` | Renamed |
| 4b | Splash `Image.asset` had no `errorBuilder` | `lib/features/splash/presentation/splash_screen.dart:38-48` | Fixed |

---

## Issue 3 — pre-delete grep (required check)

Before deleting `lib/core/presentation/splash_screen.dart`, `lib/` was grepped for any
import of it. The delete was made conditional on this grep returning nothing:

```
$ grep -rn "core/presentation/splash_screen" lib/
(no matches - nothing imports it)
```

**Zero references.** The file was confirmed dead code — `lib/main.dart` had been its only
caller, and commit `81434b9` removed that import. Deletion was therefore safe:

```
removed 'lib/core/presentation/splash_screen.dart'
removed now-empty lib/core/presentation/
```

The parent directory `lib/core/presentation/` was left empty by the delete and was removed
too. `lib/core/` still holds `.gitkeep`, `models/`, `theme/`, and `widgets/`.

This also eliminated one of the two broken `assets/images/icon.png` references (the other
was Issue 2).

---

## Issue 4a — folder rename

```
$ mv lib/features/splash/prsentation lib/features/splash/presentation
renamed OK
```

`lib/features/splash/presentation/splash_screen.dart` now matches the feature-first
convention used by every other feature (`about/presentation/`, `search/presentation/`,
`auth/presentation/`, `admin/presentation/`). The matching import in `lib/main.dart` was
updated in the same pass — see the diff below.

Plain `mv` was used, not `git mv`, so nothing was staged. `git status` currently reports
this as a delete plus an untracked directory; it will collapse into a rename once Tariq
stages it.

---

## Issue 4b — splash errorBuilder

Added to the `Image.asset('assets/icon/icon.png')` call in
`lib/features/splash/presentation/splash_screen.dart`. The asset path itself was already
correct and was not changed:

```dart
        child: Image.asset(
          'assets/icon/icon.png',
          width: 140,
          fit: BoxFit.contain,
          // This is the very first frame the app ever draws, so it must
          // never be the thing that fails. If the asset cannot be
          // resolved, fall back to a plain icon instead of an error box.
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.directions_bus,
            size: 140,
            color: _kFallbackIcon,
          ),
        ),
```

`_kFallbackIcon` was added next to the existing `_kBackground` constant
(`static const Color _kFallbackIcon = Color(0xFF0F2B43);` — the navy from the certified
palette), matching this file's existing habit of holding its colors as local constants.

**The splash's visual design was deliberately left alone** — no card container was added
back, per the instruction. That remains a pending team decision.

---

## flutter analyze (post-fix)

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

No issues found! (ran in 1.6s)
```

**Clean — 0 issues.** Same result as the pre-fix baseline, which is the expected outcome:
none of the five defects were statically detectable in the first place, so the analyzer
was never going to change verdict. It is recorded here as a no-regression check — it
proves the restored imports resolve, `appTheme` is a real symbol, the renamed folder's
import path is valid, and the new `errorBuilder` closure type-checks.

The `AppColors` import in `lib/main.dart` did **not** become unused: the file still
imports `core/theme/app_theme.dart` for `appTheme` itself, so no dead-import warning.

---

## Diffs

`git diff -- lib/main.dart lib/features/admin/presentation/admin_login_screen.dart`,
full and unmodified:

```diff
warning: in the working copy of 'lib/features/admin/presentation/admin_login_screen.dart', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'lib/main.dart', LF will be replaced by CRLF the next time Git touches it
diff --git a/lib/features/admin/presentation/admin_login_screen.dart b/lib/features/admin/presentation/admin_login_screen.dart
index 7a48c1c..0c13247 100644
--- a/lib/features/admin/presentation/admin_login_screen.dart
+++ b/lib/features/admin/presentation/admin_login_screen.dart
@@ -115,7 +115,7 @@ class _AdminLoginScreenState extends State<AdminLoginScreen> {
                     borderRadius: BorderRadius.circular(AppRadius.card),
                     border: Border.all(color: AppColors.surfaceBorder),
                   ),
-                  child: Image.asset('assets/images/icon.png'),
+                  child: Image.asset('assets/icon/icon.png'),
                 ),
                 const SizedBox(height: AppSpacing.md),
                 const Text(
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

The two `LF will be replaced by CRLF` lines are Git's standard line-ending notice on
Windows, not errors. The missing trailing newline on `main.dart` (flagged in the audit)
was also fixed as a side effect of the rewrite.

---

## Confirmation checks

### `lib/core/presentation/splash_screen.dart` no longer exists

```
$ ls lib/core/presentation/splash_screen.dart
ls: cannot access 'lib/core/presentation/splash_screen.dart': No such file or directory
```

**Confirmed deleted.** The empty parent directory was removed as well.

### Zero remaining hits for `assets/images/icon.png`

```
$ grep -rn "assets/images/icon.png" lib/
0 hits - clean
```

**Confirmed.** Both references (the dead splash and the Admin login logo) are gone.

Every remaining asset string in `lib/` now resolves to a file that exists on disk **and**
is declared in `pubspec.yaml`:

```
lib/features/admin/presentation/admin_login_screen.dart:118   'assets/icon/icon.png'             -> exists, pubspec.yaml:32
lib/features/search/presentation/search_results_placeholder.dart:152  'assets/images/empty_results.png' -> exists, pubspec.yaml:31
lib/features/splash/presentation/splash_screen.dart:38        'assets/icon/icon.png'             -> exists, pubspec.yaml:32
```

### Working tree state (nothing staged, nothing committed)

```
$ git status --short
 D lib/core/presentation/splash_screen.dart
 M lib/features/admin/presentation/admin_login_screen.dart
 D lib/features/splash/prsentation/splash_screen.dart
 M lib/main.dart
?? docs/gaith-fix-context-2026-08-26.md
?? docs/gaith-fixes-2026-08-26-applied.md
?? docs/project-gap-audit.md
?? docs/task14_audit_2026-08-29.md
?? lib/features/splash/presentation/
```

All changes are unstaged (`D`/`M` in the second column, `??` for untracked). No `git add`,
`git commit`, or `git push` was run at any point. Tariq commits.

---

## Summary

**Fixed:** all 5 audit issues — `lib/main.dart` regained the `kIsWeb` route (Admin
Dashboard reachable again on `flutter run -d chrome`) and `theme: appTheme` (certified
palette, button, card, and filled-input theming restored across the app, including the
five student auth `TextField`s); `admin_login_screen.dart:118` now points at
`assets/icon/icon.png`; the dead `lib/core/presentation/splash_screen.dart` was deleted
after a grep proved nothing imports it; and the optional cleanups landed —
`prsentation/` renamed to `presentation/` with its import updated, plus an `errorBuilder`
fallback on the splash image.

**Still needs a human decision:** whether the new splash should regain the certified
v8.7 page-4 card container (deliberately untouched, per instruction) — plus, from the
audit and unchanged here, the hardcoded `'Version 1.0.0'` string at `about_page.dart:55`
that duplicates `pubspec.yaml:5`, the missing supervisor/project-number attribution on
the About page, and the still-default Flutter icons under `web/` that show as the Admin
Dashboard's browser favicon.

**`flutter analyze`: clean, 0 issues** — though as the audit established, that was already
true while all five defects were present, so it confirms no new breakage rather than
proving the fixes work; the runtime behaviour worth spot-checking is `flutter run -d chrome`
landing on the Admin login screen with its logo rendering.
