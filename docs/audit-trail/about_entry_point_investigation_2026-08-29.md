# "About" entry point / floating pencil button — investigation (2026-08-29)

**Investigation only. No code was changed.**

## Headline finding

**The described button does not exist in the codebase.** There is no floating
circular button, no grey circle, and no pencil icon on the "All routes" screen
— or on any other screen in `lib/`. It is therefore not scoped to one screen,
not added by a shared wrapper, and not in `main.dart`. There is nothing to
notify Abdallah about, because there is no such widget to change.

The team's premise that it "links to the About page" cannot be true of any
code in this repository: the **only** navigation to `AboutPage` anywhere in
`lib/` is an ordinary AppBar `IconButton` on **Home**, using
`Icons.info_outline` — not a pencil, not floating, not on All routes.

## Evidence — what was searched and what came back

All searches were run over the whole of `lib/` (and `test/` where noted).

### 1. Any reference to the About page

```
grep -rn "about_page\|AboutPage" lib/ --include=*.dart
```

```
lib/features/about/presentation/about_page.dart:4:class AboutPage extends StatelessWidget {
lib/features/about/presentation/about_page.dart:5:  const AboutPage({super.key});
lib/features/search/presentation/home_page.dart:6:import '../../about/presentation/about_page.dart';
lib/features/search/presentation/home_page.dart:223:                MaterialPageRoute(builder: (_) => const AboutPage()),
```

Four hits: two are the class's own declaration, and the other two are the
single Home-page import and its single navigation call. **`AboutPage` is
imported by exactly one file — `home_page.dart` — and pushed from exactly one
place.**

### 2. Pencil / edit icons, floating buttons, and overlay positioning

```
grep -rn "Icons.edit\|FloatingActionButton\|Positioned(\|Stack(" lib/ --include=*.dart
```

**Zero hits.** There is no `Icons.edit`, no `Icons.edit_outlined`, no
`FloatingActionButton` (and so no `floatingActionButton:` on any Scaffold), no
`Stack`, and no `Positioned` anywhere in the app's Dart source. A floating
button overlapping a card would need at least one of these.

### 3. Every icon constant used in the entire app

```
grep -rn "Icons\." lib/ --include=*.dart
```

The complete list, for the record:

| File | Line | Icon |
|---|---|---|
| `admin/presentation/add_route_screen.dart` | 752 | `Icons.arrow_upward` |
| `admin/presentation/add_route_screen.dart` | 758 | `Icons.arrow_downward` |
| `admin/presentation/add_route_screen.dart` | 764 | `Icons.close` |
| `admin/presentation/admin_login_screen.dart` | 151-152 | `Icons.visibility_outlined` / `Icons.visibility_off_outlined` |
| `admin/presentation/admin_manage_screen.dart` | 223 | `Icons.more_horiz` |
| `admin/presentation/admin_manage_screen.dart` | 285 | `Icons.delete_outline` |
| `auth/presentation/student_login_screen.dart` | 107, 116, 119-120 | `Icons.mail_outline`, `Icons.lock_outline`, visibility pair |
| `auth/presentation/student_signup_screen.dart` | 101, 110, 113-114, 126 | same set |
| `search/presentation/home_page.dart` | **218** | **`Icons.info_outline` — the About button** |
| `search/presentation/home_page.dart` | 229, 240 | `Icons.lock_outline`, `Icons.logout` |
| `search/presentation/home_page.dart` | 283, 290 | `Icons.trip_origin`, `Icons.place_outlined` |
| `search/presentation/home_page.dart` | 333, 364 | `Icons.list_alt_outlined`, `Icons.history` |
| `search/presentation/home_page.dart` | 446, 451 | `Icons.clear`, `Icons.chevron_right` |
| `search/presentation/widgets/stop_picker_sheet.dart` | 86, 115, 141 | `Icons.search`, `Icons.error_outline`, `Icons.location_on_outlined` |
| `search/presentation/all_routes_screen.dart` | **135** | `Icons.wifi_off` — **the only icon on the All routes screen**, and it renders only in the error state |
| `core/widgets/offline_banner.dart` | 16 | `Icons.wifi_off_rounded` |
| `splash/presentation/splash_screen.dart` | 45 | `Icons.directions_bus` |

**No pencil/edit icon appears anywhere in the app.**

### 4. `all_routes_screen.dart` specifically

```
grep -rn "Stack(\|IconButton(\|CircleAvatar\|Icons\." lib/features/search/presentation/all_routes_screen.dart
```

```
135:            const Icon(Icons.wifi_off, color: AppColors.error, size: 32),
```

One hit only. The screen's `Scaffold` has exactly two arguments —
`backgroundColor` and `appBar` — plus `body`. There is no
`floatingActionButton:`, no `Stack`, no `Positioned`, and no `IconButton`.

### 5. `main.dart` — no global wrapper (checked per instruction 3)

`lib/main.dart` is 31 lines. `CoasternaApp.build` returns a `MaterialApp` with
`title`, `debugShowCheckedModeBanner: false`, `theme: appTheme`, and
`home: kIsWeb ? const AdminLoginScreen() : const SplashScreen()`.

There is **no `builder:` callback**, no `Overlay`, no global `Stack`, and no
shared Scaffold wrapper. `main.dart` cannot be injecting a floating button
onto any screen. `main.dart` was opened read-only and not edited.

### 6. No shared wrapper widget exists

`lib/core/widgets/` contains exactly one file, `offline_banner.dart`. It is a
full-width amber `Container` with `Icons.wifi_off_rounded` and the text
"You are offline. Showing cached routes." — not circular, not grey, not a
pencil, not floating, and it renders only when `_isOffline` is true.

## Answers to the four questions asked

- **Which file and line(s) define it** — none. The widget does not exist in
  `lib/`.
- **Scoped to one screen, or a shared wrapper?** — neither; there is no such
  widget and no shared wrapper capable of adding one.
- **What icon constant** — none. `Icons.edit` / `Icons.edit_outlined` appear
  nowhere in the repository.
- **What triggers navigation to AboutPage** — the only trigger in the whole
  app is `home_page.dart:216-226`, an `IconButton` in the **Home** AppBar's
  `actions:` list:

```dart
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutPage()),
              );
            },
          ),
```

- **Positioning logic** — none of the `Stack`/`Positioned`/FAB kind. The About
  button is laid out by `AppBar.actions`, which places it at the trailing edge
  of the **Home** app bar. It is not present on All routes at all.

## What is most likely actually on screen

I could not reproduce or inspect the visual — I have not looked at a
screenshot, and the `flutter run` process from the previous round has since
exited, so the app is not currently open. Given the code is unambiguous, the
grey circle with the white pencil is almost certainly not rendered by
Coasterna. Worth ruling out, in rough order of likelihood:

1. **An OS or tool overlay on top of the app window** — a screenshot/annotation
   tool, a Windows 11 snipping or markup affordance, or an accessibility
   overlay. A round grey button with a white pencil is a very common
   "annotate/edit" affordance in screenshot utilities.
2. **The screenshot being of the spec artwork rather than the running app** —
   the spec is a ZIP of JPEGs; a design-tool comment or annotation pin sitting
   over the first card would look exactly like this.
3. **A different screen than the one assumed** — Home is the screen that
   actually carries the About action, and the Admin "manage" screen carries an
   edit affordance (`Icons.more_horiz` popup with an `'edit'` value,
   `admin_manage_screen.dart:223-241`), though that is web/admin-only, is a
   three-dot menu rather than a pencil, and does not navigate to About.

To settle it, the useful next step would be the actual screenshot, or a run
with the Flutter widget inspector pointed at that button.

## Files read (none modified)

- `lib/main.dart` (read-only)
- `lib/features/search/presentation/all_routes_screen.dart`
- `lib/features/search/presentation/home_page.dart`
- `lib/features/about/presentation/about_page.dart`
- `lib/core/widgets/offline_banner.dart`
- plus repo-wide greps over `lib/` and `test/`

**No file was edited in this investigation.** No git commands were run.
