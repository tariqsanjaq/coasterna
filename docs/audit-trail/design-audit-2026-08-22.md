# Coasterna — Design Specification Audit

**Date:** 2026-08-22
**Spec:** `spec_v8_7.pdf` — "UI Design Specification, Version 8", 23 pages / 20 artboards
**Source audited:** `lib/**` (23 Dart files), `firestore.rules`
**Type:** Read-only audit. No source file was edited, no git command was run, the app was not built or launched.

## Method

The repository had no PDF page rasteriser available (`pdftoppm`, `mutool`, `gs`, ImageMagick all absent). PyMuPDF was installed into the session scratchpad — outside the project, no project file touched — and all 23 pages were rendered to PNG at 110 dpi and read as images. Higher-resolution crops (360–400 dpi) were rendered for pages 5, 7, 8, 11, 17, 19 and 20 to settle corner radii, chip fills and button shapes that were not decidable at page scale.

**All 23 pages were rendered and read. There is no page in this spec that could not be seen.**

### Page map

Pages 8–9 and 17–20 were given. The rest is taken from the spec's own contents page (p.2):

| Page | Screen | Page | Screen |
|---|---|---|---|
| 1 | Cover | 13 | Offline · no saved data |
| 2 | Contents | 14 | All routes |
| 3 | Design system | 15 | About |
| 4 | Splash | 16 | Admin login |
| 5 | Home | 17 | Admin — Routes list |
| 6 | Stop picker | 18 | Admin — Stops list |
| 7 | Search results · 5 status states | 19 | Admin — Add route form |
| 8 | Trip details · 14 stops | 20 | Delete confirmation |
| 9 | Trip details · return, 2 stops | 21 | App icon |
| 10 | Loading | 22 | Student login — *proposed, not committed* |
| 11 | Empty | 23 | Student sign up — *proposed, not committed* |
| 12 | Offline · showing saved data | | |

Pages 1–3 are front matter and 21 is a brand plate; they are audited as tokens and assets rather than as screens.

---

## Design tokens — `lib/core/theme/app_theme.dart`

Every colour token on spec p.3 is reproduced exactly. **No value in `AppColors` differs from the spec.**

| Token | Spec p.3 | `app_theme.dart` | |
|---|---|---|---|
| Primary | `#0F2B43` | `:12` `0xFF0F2B43` | match |
| Accent | `#AF9064` | `:13` `0xFFAF9064` | match |
| Success | `#3B6D11` | `:14` `0xFF3B6D11` | match |
| Warning | `#A66300` | `:15` `0xFFA66300` | match |
| Error | `#A32D2D` | `:16` `0xFFA32D2D` | match |
| Text primary | `#1A1A18` | `:18` `0xFF1A1A18` | match |
| Text secondary | `#5C5C55` | `:19` `0xFF5C5C55` | match |
| Text tertiary | `#6E6E67` | `:20` `0xFF6E6E67` | match |
| Background | `#F7F4EE` | `:22` `0xFF F7F4EE` | match |
| Surface | `#FFFFFF` | `:23` `0xFFFFFFFF` | match |
| Card radius | 12px | `:45` `AppRadius.card = 12` | match |
| Button/field radius | 8px | `:46` `AppRadius.button = 8` | match |
| Chip radius | 4px | `:47` `AppRadius.chip = 4` | match |
| Spacing scale | 4, 8, 12, 16, 24 | `:32-36` | match |
| Min touch target | 48×48 | `:51` `kMinTouchTarget = 48` | match |

`AppColors.surfaceBorder` (`#E4E0D6`, `:25`) is not a spec token; the file says so in a comment. Used for card and divider borders. Not a defect.

### Where the token file is correct but call sites bypass it

The theme is clean. The deviations are all at the point of use — three files re-declare token values locally instead of importing them, and two of those re-declarations are **wrong**:

| File | Local constant | Value | Spec token | |
|---|---|---|---|---|
| `route_status_badge.dart:189` | `_greenText` | `#2F6B37` | Success `#3B6D11` | **differs** |
| `route_status_badge.dart:193` | `_amberText` | `#8A6D1B` | Warning `#A66300` | **differs** |
| `route_status_badge.dart:227` | noService text | `#B03A32` | Error `#A32D2D` | **differs** |
| `admin_manage_screen.dart:10` | `_kSuccess` | `#3B6D11` | Success | value correct, duplicated |
| `admin_form_widgets.dart:17` | `_kWarning` | `#A66300` | Warning | value correct, duplicated |

`route_status_badge.dart:171-173` states the reason: *"Colours live here rather than in AppColors so this task never edits the shared theme file."* The result is that the five status pills — the most colour-carrying element in the student flow — use none of the three certified status colours. `admin_manage_screen.dart:7-9` says the tokens "may not exist in app_theme.dart yet"; they do exist, so that comment is stale.

### `chip` radius is defined but never used

`AppRadius.chip = 4` is declared and referenced nowhere in `lib/`. Every chip in the app hardcodes a different value: `6` at `route_status_badge.dart:125` and `search_results_placeholder.dart:266`, `4` written as a literal at `admin_manage_screen.dart:182`, and the Material default at `add_route_screen.dart:597`.

### Monospace usage

Spec p.3 reserves IBM Plex Mono for "prices, times, durations **only**". The rendered p.18 nonetheless sets LATITUDE and LONGITUDE in mono, so the spec is internally inconsistent on coordinates; the code follows the rendered page (`admin_manage_screen.dart:655-656`). Not treated as a defect. Mono is correctly applied and not over-applied everywhere else, with one exception noted under p.14.

---

## The three approved deviations — confirmed, no action

1. **"+ Add stop" on the Stops screen.** Confirmed still true. `admin_manage_screen.dart:610` sets `actionLabel: '+ Add stop'` on the Stops list header. Spec p.18 has no such button; p.17 has "+ Add route". As documented.
2. **STATUS and overflow columns on the Stops table.** Confirmed still true. `admin_manage_screen.dart:646-647` add `_HeadCell('Status')` and a 48px menu slot beyond the spec's NAME / AREA / LATITUDE / LONGITUDE / ROUTES. The pattern is lifted from p.17 as described. The reason is recorded in-file at `:497-500`.
3. **Stop form built to the route-form pattern, two columns.** Confirmed still true. `add_stop_screen.dart:192` and `:216` pass `columns: 2` to `AdminFormRow`; the route form uses the default 3. Reason recorded at `add_stop_screen.dart:21-22`.

---

# A. Verified from source code

## p.4 — Splash → `lib/core/presentation/splash_screen.dart`

**MATCH.**
Light background rather than a full-colour splash (`:49`), one centred surface card at 180×180 with `AppRadius.card` (`:51-57`), logo asset inside (`:58-61`). This is what p.4 shows. Auto-advance after 2s (`:29`) is behaviour the spec does not depict either way.

## p.5 — Home → `lib/features/search/presentation/home_page.dart`

**DEVIATION.** Four differences, all user-visible.

- **App bar is inverted.** Spec p.5 (confirmed at 360 dpi) shows a **cream** bar on `#F7F4EE`, the wordmark **"coasterna" lowercase** in navy, and a **navy lock icon** at top right — the entry point to admin. `home_page.dart:210-213` sets `backgroundColor: AppColors.primary` with `foregroundColor: AppColors.surface` and `title: const Text('Coasterna')` — a navy bar, white text, capital C. Visible.
- **No lock icon; a logout icon in its place.** `:216-221` renders an `Icons.logout` action, and only when a student is signed in. The spec's lock affordance is absent, so there is no on-screen route from Home to admin. Visible.
- **Field labels are inside the box, in sentence case.** Spec puts `FROM` and `TO (OPTIONAL)` as small uppercase labels **above** each field. `:259` and `:266` pass `label: 'From'` / `'To (optional)'` into `_StopField`, which renders them *inside* the bordered box above the value (`:404-408`). Visible.
- **Field corner radius.** Spec fields are 8px (p.3, and measured on the p.5 crop). `_StopField` uses `AppRadius.card` — 12px — at `:384` and `:393`. Visible but subtle.

Minor, also visible: the FROM icon is `Icons.trip_origin` (`:261`) where the spec shows a filled gold map pin; the TO placeholder reads "Select a stop" (`:410`) where the spec reads "Any destination"; a helper line "Pick a From stop to continue." (`:296`) has no counterpart on the spec page.

Correct: card at `AppRadius.card` with `surfaceBorder` (`:233-237`), "Find your bus" + "Pick where you are starting from" (`:242`, `:253`), full-width navy "Search buses" at 8px radius and 48px height (`:273-293`), outlined "Browse all routes" (`:309-320`), RECENT list with accent clock icons and `"X to Y"` joining (`:322-353`).

## p.6 — Stop picker → `lib/features/search/presentation/widgets/stop_picker_sheet.dart`

**DEVIATION.** Two differences, both user-visible.

- **Row subtitle drops the route count.** Spec rows read `Amman · 4 routes`. `:145` renders `Text(stop.area)` only — area, no count. Visible.
- **Rendered as a partial bottom sheet, not a full screen.** Spec p.6 shows a full-height screen with a back chevron and the title "Select stop". `:63-67` uses `DraggableScrollableSheet` at `initialChildSize: 0.7`, `maxChildSize: 0.9`, so it never reaches full height. Visible.

Minor: the title is `'Select ${widget.title} stop'` (`:75`) — "Select From stop" / "Select To stop" — where the spec reads plain "Select stop".

Correct: search field with "Search stops" placeholder at 8px radius (`:82-94`), accent pin per row (`:140-141`), bold name over secondary subtitle, loading / error / empty branches (`:106-151`).

## p.7 — Search results, 5 status states → `search_results_placeholder.dart`, `widgets/route_status_badge.dart`

**DEVIATION.** Structure and copy are right; the colours are not.

All five states exist with labels matching the spec word for word — "Next bus in about 12 min" (`route_status_badge.dart:196`), "First bus at 06:30" (`:203`), "Departs when full" (`:210`), "Service ended today" (`:217`), "No service today" (`:224`) — and `_resolveStatus` (`:144-168`) orders them so an unavailable route can never display as available.

- **All three badge text colours are off-token**, as tabulated above: `#2F6B37` vs Success `#3B6D11`, `#8A6D1B` vs Warning `#A66300`, `#B03A32` vs Error `#A32D2D`. Visible.
- **Chip radius is 6px, not 4px** — `route_status_badge.dart:125` and the "To AAU" direction chip at `search_results_placeholder.dart:266`. Visible, subtle.

Correct: header "Search results" with "N routes · soonest departure first" (`:96`, `:105-106`), "Board at: …" in accent (`:223-230`), price and duration in mono via `AppTextStyles.monoData` (`:233-235`), outlined navy direction chip (`:263-277`), device-side sort by `routeDepartureRank` (`:57-60`).

## p.8 — Trip details, 14 stops → `lib/features/trip/presentation/trip_details_screen.dart`

**MINOR DEVIATION.**

- **"Open in Google Maps" uses a 12px radius**; spec buttons are 8px (measured on the p.8 crop). `:206` passes `AppRadius.card` where `AppRadius.button` is meant. Visible, subtle.

Correct and closely matched: route name over operator name in the app bar (`:164-178`); STOPS card with filled endpoint dots, hollow intermediates and a connecting rule (`_StopRow`, `:331-383`); collapse to 3 + 3 when there are more than 6 stops (`:233-236`) with the "Show all N stops" link in accent, underlined, placed after the third row exactly as the spec draws it (`:268-283`); details card with Price / Duration / Operating days / First departure / Last departure, labels in secondary and values right-aligned in mono (`:303-318`, `_DetailRow` `:386-411`); `formatOperatingDays` producing "Sun to Thu" (`:44-74`); bottom-pinned full-width navy button.

## p.9 — Trip details, return, 2 stops → same file

**DEVIATION.** One difference, user-visible.

- **The "not surveyed" caption is missing.** Spec p.9 shows, under a two-stop timeline, the italic line *"Intermediate stops for this direction were not surveyed."* `_buildStopsCard` (`:225-288`) has no branch for a short stop list and renders nothing in its place, so a return route shows two stops with no explanation of the gap.

## p.10 — Loading → `search_results_placeholder.dart`

**DEVIATION.** Two differences, both user-visible.

- **Spinner instead of skeletons.** Spec p.10 shows four grey skeleton cards mimicking the loaded layout. `:121-125` renders a single centred `CircularProgressIndicator`.
- **No "Searching…" subtitle.** Spec puts "Searching…" under the header while loading. `:103` gates the subtitle on `_state == _LoadState.loaded`, so during loading the header carries no second line.

## p.11 — Empty → `search_results_placeholder.dart`

**DEVIATION.** Three differences, all user-visible.

- **Copy is merged into one line.** Spec has a bold navy heading "No buses found from this stop" plus a secondary line "Try another departure point". `:154-161` renders a single secondary-coloured sentence, `'No buses found from ${widget.fromStop.name} yet.'`
- **The "Change stop" button is absent.** Spec p.11 (confirmed at 360 dpi) shows a navy auto-width "Change stop" button under the copy. There is no button in the empty branch at all (`:145-165`), so the state is a dead end that requires the system back gesture.
- **No "0 buses" subtitle.** Spec shows it in the header; `:103` suppresses the subtitle outside the loaded state.

Correct: the illustration is present (`:152`, `assets/images/empty_results.png`).

## p.12 — Offline · showing saved data → `core/widgets/offline_banner.dart`, `search_results_placeholder.dart`

**DEVIATION.** Four differences, all user-visible.

- **Banner colour is off-token.** `offline_banner.dart:12` uses `Colors.amber.shade800` (`#FF8F00`) with white text on a saturated fill. Spec p.12 is a pale sand fill with dark Warning-coloured text — the same treatment as the p.19 notice banner, which *does* use `#A66300` correctly.
- **Banner copy differs and conflates two states.** Spec p.12 reads "Showing saved data · last updated 11 min ago". `offline_banner.dart:20` reads "You are offline. Showing cached routes." for both p.12 and p.13, so the two offline states are visually identical.
- **No "last updated" timestamp.** Nothing in the widget accepts or renders a staleness value.
- **No per-card "Schedule shown from saved data" chip.** Spec puts an amber chip on every card in this state; `_buildRouteCard` (`:194-242`) has no offline variant.

The mechanism behind the state is sound: `RepoResult.isFromCache` (`route_repository.dart:21-30`) is threaded through and used at `:65` and `:170`.

## p.13 — Offline · no saved data → `search_results_placeholder.dart`

**DEVIATION.** Four differences, all user-visible.

- **No banner in this state.** Spec keeps the amber strip at the top reading "You are offline"; the error branch (`:127-142`) renders only a centred column.
- **No "Not loaded" subtitle** under the header, for the same reason as p.10/p.11.
- **Different error presentation.** Spec shows a large pale-pink circle containing a cloud-off glyph, then "You are offline" as an Error-coloured heading, then "Check your connection and try again". Code renders a bare 32px `Icons.wifi_off` and one secondary-coloured sentence, "Could not load buses. Check your connection." (`:132-137`).
- **Retry is a text button, not a filled one.** Spec draws a filled navy "Retry"; `:139` uses `TextButton`.

The same four points apply to `all_routes_screen.dart:76-92`, which repeats this pattern.

## p.14 — All routes → `lib/features/search/presentation/all_routes_screen.dart`

**DEVIATION.** This is the weakest match in the student flow — six differences, all user-visible.

- **App bar is inverted**, as on Home: navy with white text (`:61-63`) where the spec is cream with navy text.
- **No "12 active routes" subtitle.** The spec header carries a count line; `:60-64` has a title only.
- **Terminology violation — "->" instead of "to".** `:142` renders `'${route.originStopName} -> ${route.destinationStopName}'`. Spec p.3 freezes this: *Route names use **"to"**, never a dash*. Visible on every card.
- **Price is not monospaced.** `:158-163` styles the price with a plain `TextStyle`. Spec p.3 reserves mono for prices, and p.14 draws each price as a mono value inside an outlined chip. This is the one place mono is required and missing.
- **Operator name is absent.** Spec shows the operator under each route name; the card has no such line.
- **No status badge and no frequency line.** Spec cards carry both a green/amber frequency label ("Every 20 min" / "Departs when full") and the same status pill used on p.7. The card shows a plain departure-window string instead (`:149-157`).

## p.15 — About

**DEVIATION — not implemented.** No file in `lib/` implements this screen. A search for "About", "Data source" and "Version 1.0.0" across `lib/**` returns nothing, and no navigation target exists. Spec p.15 specifies three cards (Data source / University / Team) and a mono "Version 1.0.0" footer. Visible: the screen is simply absent.

## p.16 — Admin login → `lib/features/admin/presentation/admin_login_screen.dart`

**MATCH.**
Centred surface card at 400px max width (`:84-92`), logo tile (`:96-106`), "Coasterna admin" (`:109`), "Sign in to manage routes and stops." (`:117`), email hint `admin@example.com` (`:126`), password field with an eye toggle (`:130-148`), full-width navy "Sign in" at 8px radius and 48px height (`:157-178`). Fields inherit the 8px theme decoration.

Minor: the password hint is the literal word "Password" (`:134`) where the spec shows a dot mask. Not meaningfully visible, since the mask appears once typing starts.

## p.17 — Admin Routes list → `lib/features/admin/presentation/admin_manage_screen.dart` (`RoutesManageList`, `:685-846`)

**MINOR DEVIATION.** The strongest match in the project — column set, order and cell treatment are exact.

Columns ROUTE / OPERATOR / ORIGIN / DESTINATION / PRICE / STATUS / overflow (`:811-819`) match the spec one for one. Price in mono as "0.55 JD" (`:828-832`). Status pill at radius 4 with the exact labels Active / Inactive and no third value (`_StatusPill`, `:166-196`). Overflow menu (`:202-259`). Header with "6 routes · 2 operators" shape (`:780`) and "+ Add route" (`:781`). Navy sidebar with Coasterna admin / Routes / Stops / Sign out (`admin_home_screen.dart:202-238`).

- **"+ Add route" is a full pill; the spec draws a rounded rectangle.** `:87` sets `BorderRadius.circular(999)`. The 400 dpi crop of p.17 shows a corner radius roughly a fifth of the button height — an 8px rounded rect, not a stadium. Visible.

Minor: the count line does not handle singulars, so one route reads "1 routes · 1 operators" (`:780`, and `:609` for stops).

## p.18 — Admin Stops list → same file (`StopsManageList`, `:501-671`)

**MATCH**, given approved deviations 1 and 2.

NAME / AREA / LATITUDE / LONGITUDE / ROUTES present and in order (`:640-645`), coordinates in mono at four decimals matching the spec's `32.0090` / `35.8560` formatting (`:655-656`), route counts computed on-device without an extra query (`:538-549`). STATUS, the overflow column and "+ Add stop" are the approved additions.

## p.19 — Admin Add route form → `add_route_screen.dart`, `admin_form_widgets.dart`

**DEVIATION.** The grid is right; the controls inside it are not.

Field order matches the spec exactly, row for row: Operator name / Route name / Direction, then Origin stop / Destination stop / Departure type, then Price in JD / Duration in minutes / First departure, then Last departure / Collected by / Collected on (`:406-570`). Title "Add Route" with the italic sub-line "All values come from field-collected survey sheets." (`:391-394`). The notice banner reproduces the spec sentence verbatim — "Check for an existing route with the same origin and destination before saving — duplicates confuse student search results." (`:401-403`) — and correctly uses Warning `#A66300` (`admin_form_widgets.dart:17`). Labels are uppercase above their fields at 8px radius (`admin_form_widgets.dart:92-149`). Cancel + "Save Route" bottom-right at 8px (`:206-277`).

- **Operating-days chips use Material defaults, not the spec's navy pills.** The 400 dpi crop shows selected days as **navy-filled with white bold text** and unselected as white with a grey outline. `:597` constructs a bare `ChoiceChip` with no `shape`, `selectedColor` or `labelStyle`, so selection renders as Material 3's pale `secondaryContainer` tint with dark text and a leading checkmark. Visible, and it is the most conspicuous difference on the page.
- **The stops list is structurally different.** Spec shows each stop as a white filled rounded field with a single red `×` at the right, and a gold "+ Add stop" text link beneath. Code renders plain text lines carrying **three** icon buttons each — up, down and remove (`_StopLine`, `:716-773`) — plus an inline "Add a waypoint" text input and a `TextButton` in default primary rather than an accent link (`:660-680`). The up/down reordering is a real feature, but it is not on the approved-deviation list and is not on p.19.
- **The Active toggle thumb is gold.** `:698` sets `activeThumbColor: AppColors.accent`. The crop shows a navy track with a plain white thumb. Visible.
- **An extra "Frequency in minutes" field appears when SCHEDULED is selected** (`:572-589`). No such field exists on p.19.
- **Departure type defaults to WHEN_FULL** (`:69`); the spec form opens showing SCHEDULED. Visible on first load of a new form.

Minor: two helper lines with no spec counterpart — "Leave every day unselected if the route runs all week." (`:613-619`) and "Waypoints are saved in the order shown…" (`:623-630`).

## p.20 — Delete confirmation → `admin_manage_screen.dart` (`_confirmDestructive`, `:264-353`)

**MINOR DEVIATION.**

Structure matches: centred dialog at `AppRadius.card` and 400px max width (`:272-278`), Error-coloured trash glyph on top (`:284-288`), centred bold title "Delete this route?" (`:290-298`), centred secondary body, plain Cancel beside a filled Error-red confirm labelled "Delete route" (`:313-343`).

- **Body copy differs by one clause.** Spec: *"This action can't be undone unless the route is re-entered."* Code (`:739-741`): *"This cannot be undone unless the route is re-entered."* Visible.
- **The confirm button is a full pill.** `:333` uses `BorderRadius.circular(999)`; the 400 dpi crop shows a rounded rectangle. Visible, subtle.

## p.21 — App icon

**DEVIATION.** `android/app/src/main/res/mipmap-*/ic_launcher.png` is still the **stock Flutter logo** — verified by opening `mipmap-xxxhdpi/ic_launcher.png` directly. Spec p.21 specifies the Coasterna bus-and-pin mark on a cream tile. The correct artwork exists in the project at `assets/images/coasterna_logo.png` and is used in-app, but was never installed as the launcher icon. Visible on the device home screen.

## pp.22–23 — Student login / sign up

**DEVIATION — committed scope exceeded.** Both pages are headed, in the spec's own words, **"PROPOSED · STRETCH GOAL, NOT COMMITTED SCOPE"**, and the contents page files them under "PROPOSED · NOT COMMITTED SCOPE".

Both are nonetheless implemented — `student_login_screen.dart` (170 lines), `student_signup_screen.dart` (156 lines), `auth/data/auth_repository.dart` (80 lines) — and **wired in as the app's default landing screen**: `main.dart:36-42` sends every unauthenticated non-web launch to `StudentLoginScreen`. A student opening the app meets a sign-in wall before search, and search is what the committed flow (pp.4–14) is built around.

This also contradicts the frozen architecture note in `CLAUDE.md` ("Admin-only. There are no student accounts. Do not add student sign-up, sign-in… unless explicitly told the team approved it").

The implementation does not follow pp.22–23 either — "Sign in" rather than "Welcome back", a generic "Email" hint rather than `yourname@aau.edu.jo`, "Create an account" rather than "Don't have an account? Sign up", plus a "Continue without signing in" escape (`student_login_screen.dart:159-162`) that appears nowhere in the spec, and no FULL NAME or STUDENT ID fields from p.23. Those string-level gaps are secondary; the finding is that the screens exist and gate the app at all.

---

# B. Requires a running app to confirm

Static reading cannot settle these. Steps are written so one person can work through them in order.

1. **IBM Plex Mono actually rendering.** `AppTextStyles.monoData` (`app_theme.dart:54-66`) pulls the face through `google_fonts`, which fetches over the network on first use; `pubspec.yaml` bundles no font files. Launch on a **fresh install with networking disabled**, run a search, and check that prices and times on the results and trip-details screens are monospaced rather than falling back to Roboto. This bears directly on the p.12/p.13 offline states, where mono values are on screen precisely when there is no connection.
2. **Material 3 chip rendering on p.19.** Open Admin → Routes → "+ Add route" and photograph the OPERATING DAYS row. Confirm the selected-chip fill and label colour against the navy/white in the spec, and measure the corner radius. The code sets no shape, so the result depends on the Material 3 defaults for the installed Flutter version.
3. **`ChoiceChip` and `Switch` colours against the seeded scheme.** `ColorScheme.fromSeed` (`app_theme.dart:32-37`) derives container and outline colours from the navy seed; those derived values are not readable from source. Screenshot the Add route form and compare the chip fill, the Switch track and the gold thumb (`add_route_screen.dart:698`) with p.19.
4. **The five status badges, one at a time.** Each depends on wall-clock time against `firstDeparture` / `lastDeparture` / `frequencyMinutes` / `operatingDays`. Seed five routes to force one of each state, screenshot the results screen, and compare the badge text colours to p.7 — this is where the three off-token colours become visible side by side.
5. **Both offline states.** With data already cached, enable airplane mode and search: expect p.12 (banner plus per-card chips). Clear app storage, enable airplane mode, search again: expect p.13 (banner, illustration, filled Retry). Confirm the current build renders the same banner for both.
6. **Loading state timing.** The skeleton/spinner difference on p.10 is only observable while a query is in flight. Throttle the connection or seed a large route set, then screenshot mid-load.
7. **Admin table behaviour below 940px.** `_kTableMinWidth` (`admin_manage_screen.dart:16`) switches to horizontal scrolling under that width. Resize the browser window across the threshold and confirm columns never crush — the spec draws only the wide state.
8. **Actual corner radii on device.** The 999px pills at `admin_manage_screen.dart:87` and `:333`, and the 12px "Open in Google Maps" at `trip_details_screen.dart:206`, were compared against high-DPI crops. Confirm on a real screenshot at device scale.
9. **Where the Maps deep link lands.** Tap "Open in Google Maps" on a trip with and without an origin `StopModel`, and see whether Google Maps opens directions or a dropped pin (see the appendix note).
10. **The launcher icon.** Install the APK and look at the home screen to confirm the stock Flutter logo finding.

---

# Appendix — deviations from frozen decisions, not from the PDF

These are outside the design spec but were found while reading the same files, and each contradicts a decision recorded as frozen in `CLAUDE.md`. Listed separately so they are not confused with the page-by-page audit above.

1. **Search does not match intermediate stops.** Frozen: *"Search matches any stop in the route's `stops` array, not just the origin."* `route_repository.dart:70-77` filters on `originStopId` and `isActive` only; the `stops` array is never queried. A student boarding at a mid-route stop gets no results. Compounding it, `add_route_screen.dart:280` writes waypoints with synthetic ids (`'wp-1'`, `'wp-2'`, …) instead of real stop document ids, so even a corrected query could not match them.
2. **Direction is a manual flag.** Frozen: *"Direction is validated by comparing `sequence` numbers, not a manual flag."* Direction comes from a dropdown (`add_route_screen.dart:430-445`) and is stored verbatim; no sequence comparison occurs anywhere.
3. **Maps URL format.** Frozen: `https://www.google.com/maps/search/?api=1&query=LAT,LON`. `trip_details_screen.dart:128-132` builds `https://www.google.com/maps/dir/?api=1&origin=…&destination=…`, and falls back to passing a **stop name string** rather than coordinates when `originStop` is null (`:120-125`).
4. **No `admins/{uid}` check.** Frozen: *"Admin identity is checked via an `admins/{uid}` Firestore collection (existence = permission)."* The string `admins` appears nowhere in `lib/`. `admin_login_screen.dart:38` accepts **any** Firebase Auth credential and routes straight to `AdminHomeScreen` (`:44-46`). `firestore.rules` blocks the writes, so no data can be corrupted — but any account, including one created through the student sign-up screen, can open the admin dashboard and see every route and stop. Note that `firestore.rules:38` sets `allow read: if false` on `admins`, so the intended existence check cannot be performed from the client as specified.
5. **Presentation layer calls Firebase directly.** Frozen: *"zero direct Firebase calls outside `lib/features/*/data/` folders — widgets never import `cloud_firestore` or `firebase_auth` directly."* `admin_login_screen.dart:2` and `admin_home_screen.dart:2` both import `firebase_auth` and call `FirebaseAuth.instance` at `:38` and `:109` respectively, bypassing the `AuthRepository` that already exists.
6. **Firestore field names diverge from the frozen schema.** `routes`: `routeName` and `priceJD` where the schema says `nameEn` and `price`; `RouteStop` uses `stopName` / `order` where it says `nameEn` / `sequence`. `stops`: `name` where it says `nameEn`, plus `isActive` added and `nameAr`, `landmark`, `collectedBy`, `collectedOn` absent from both `StopModel` (`core/models/stop_model.dart:5-20`) and the stop form. Internal, but it is the contract the report's Ch.4.2.4 documents.
7. **`firestore.rules` is correct** and needs no change: `isAdmin()` via `exists()` on `admins/{uid}`, public read on `routes` and `stops`, admin-only write, `admins` sealed in both directions, and a catch-all `if false` for any future collection.
8. **Untranslated comments.** `trip_details_screen.dart:85, 89, 119, 124, 127` carry Arabic comments where the rest of the codebase is in English. Cosmetic, but it is a submitted artefact.

---

## Summary

| Verdict | Pages |
|---|---|
| MATCH | 4, 16, 17 (minor), 18 |
| MINOR DEVIATION | 8, 20 |
| DEVIATION | 5, 6, 7, 9, 10, 11, 12, 13, 14, 19, 21, 22–23 |
| NOT IMPLEMENTED | 15 |
| CANNOT VERIFY STATICALLY | none at page level; see section B for the ten runtime checks |

The admin dashboard (pp.16–20) is the closest to spec — column sets, copy and layout are near-exact, with the remaining gaps being button shape and the Material-default chips on p.19. The student flow diverges most: two inverted app bars, three off-token status colours, a missing screen (p.15), a missing empty-state action (p.11), two offline states rendered identically (pp.12–13), a frozen-terminology violation on p.14, and an uncommitted sign-in wall in front of the whole flow (pp.22–23).

Nothing in this document has been fixed or changed. Report only.
