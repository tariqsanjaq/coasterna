# D52, part 2 — guest-visible favorites/report buttons + pending-intent flow

Implements decision D52 part 2 of 2 on `dev`: the `FavoriteButton` and a new
"Report an issue" entry point are now shown to everyone, signed in or not.
A guest tap stores a pending intent and sends the student to sign in;
after a successful sign-in, the app completes the favorite automatically
(with a confirmation) or, for a report, tells the student to reopen the
route — it does not navigate back to a specific prior screen. Part 1
(reports backend, Security Rules, admin tab) was not re-touched:
`firestore.rules`, `ReportModel`, `ReportsRepository`'s read methods, and
the admin Reports tab are all untouched by this task.

**Note on D48 / file ownership:** `trip_details_screen.dart` and the
favorites screens (`favorite_button.dart`, `favorites_screen.dart`) are
Gaith's area. Per decision D48 (pre-granted permission for Tariq to
execute his work via Claude Code during finals), this task edited them —
flagged here and in the suggested commit message, per the standing
coordination rule.

## Changes made

### 1. Pending-intent mechanism (`lib/core/pending_intent.dart`, new)

- `PendingIntent` — a `sealed class` with exactly two subclasses,
  `PendingFavorite(routeId, routeName)` and `PendingReport(routeId,
  routeName)`. Sealed so any `switch` over it is exhaustively checked by
  the compiler; a third case added later would fail to compile until
  every switch handling one is updated.
- `PendingIntentHolder` — a static holder (`static PendingIntent?
  _pending`), no `ValueNotifier` (nothing needs to listen for a pending
  intent changing — only the sign-in/sign-up screens read it once).
  `set()` overwrites whatever was pending; `consume()` returns it and
  clears it in the same call. In-memory only, same as the task's
  suggested shape — no new package, no state management library.

### 2. Guest tap → sign-in

**`FavoriteButton`** (`lib/features/favorites/presentation/favorite_button.dart`):
- Gained a required `routeName` parameter (needed to build a
  `PendingFavorite` — the widget previously only took `routeId`).
- The doc comment's "ASSUMES the caller has already checked... signed
  in" contract is gone — the widget is now safe to show unconditionally.
- `onPressed` now goes through `_handleTap()`: if
  `AuthRepository().currentUser == null`, stores a `PendingFavorite` and
  pushes `StudentLoginScreen`; otherwise runs the existing `_toggle()`
  unchanged.

**Report entry point** — see part 3 below; same guest-tap pattern,
storing a `PendingReport` instead.

### 3. Report entry point (`trip_details_screen.dart`)

- A `TextButton.icon` "Report an issue" (flag icon, `AppColors.error`
  foreground) added below the existing "Open in Google Maps" button and
  its path-points caption, inside the same bottom `Padding`/`Column` —
  doesn't compete visually with the primary maps button.
- `_openReportForm()`: guest → same `PendingReport` + navigate-to-sign-in
  pattern as `FavoriteButton`. Signed-in → opens `_ReportFormSheet`, a
  modal bottom sheet reusing the exact shape `StopPickerSheet`
  (`home_page.dart`) already established (`AppColors.surface`
  background, top-rounded corners, `isScrollControlled: true`).
- `_ReportFormSheet`: the five `ReportReason` values as a `RadioGroup` of
  `RadioListTile`s (Flutter 3.44's `RadioGroup` ancestor — the plain
  per-tile `groupValue`/`onChanged` API is deprecated as of Flutter
  3.32, `flutter analyze` flagged it, and it was migrated rather than
  suppressed). Picking "Other" reveals a `TextField` for the free-text
  reason. Submit calls `ReportsRepository().createReport()` with the
  current route's id/name, `reportedByUid:
  AuthRepository().currentUser!.uid` (re-checked defensively — the sheet
  is only ever opened for a signed-in student, but a session could
  theoretically end while it's open), and `status: ReportStatus.open`.
  On success: `ScaffoldMessenger` SnackBar "Report submitted. Thank
  you." then `Navigator.pop()` — same snackbar-then-close order
  `RouteFormPanel._save()` already uses for its own post-save
  confirmation, matching this codebase's established convention for
  post-action feedback.
- `_reasonLabel()`: a **local, duplicated** copy of
  `ReportModel.reasonLabel`'s five strings, used only to label the radio
  options before a reason is picked. This task's constraints forbid
  touching `ReportModel` (an instance getter, not a free function, so
  there's no way to read it for all five reasons without either
  building five throwaway `ReportModel` instances or duplicating the
  strings) — documented in a comment at the duplication site so it's
  found if `reasonLabel`'s wording ever changes.

### 4. Consuming the pending intent after sign-in

**`lib/features/auth/presentation/pending_intent_completion.dart`** (new)
— a single shared `Future<void> completePendingIntent(BuildContext
context)`, called from both `student_login_screen.dart`'s `_goToHome()`
and `student_signup_screen.dart`'s success path, immediately after each
one's (unmodified) `pushAndRemoveUntil` call, via `unawaited(...)` —
matching the fire-and-forget pattern `FavoriteButton` already uses for
its own initial load.

- **Extracted as a shared function rather than duplicated in both
  screens** — this is the one deliberate structural choice beyond the
  task's literal wording ("in `_goToHome()`... check if a pending intent
  exists"). Copying the same ~20-line try/catch-plus-switch logic into
  two files is exactly the kind of duplication that drifts the moment
  one copy changes; a 2-line call site in each screen was preferred.
  Noting this explicitly since it's a judgment call, not a literal
  reading of the prompt.
- `PendingFavorite`: calls `FavoritesRepository().toggleFavorite(intent.routeId)`
  (the same repository method `FavoriteButton._toggle()` uses), wrapped
  in `try/catch` — on success, SnackBar "Added to favorites."; on any
  failure (stale/deleted route, or the write failing for another
  reason), the confirmation is skipped silently, same "don't crash on a
  bad reference" spirit as `home_page.dart`'s `_useRecentSearch`.
- `PendingReport`: **not** completed automatically. SnackBar "Signed in.
  Open the route again to finish your report." — see the trade-off note
  below.
- Both branches clear the intent via `PendingIntentHolder.consume()`
  before the switch even runs, so it can never fire twice.
- No pending intent → `consume()` returns `null` → the function returns
  immediately, nothing changes from current behavior.

**`_goToHome()`'s `pushAndRemoveUntil` call itself was not modified** —
same route, same `(route) => false` predicate, same everything. The only
change is one new line (`unawaited(completePendingIntent(context));`)
added after it, inside the same method. `student_signup_screen.dart`'s
equivalent inline `pushAndRemoveUntil` (it doesn't call a shared
`_goToHome()` — that call is duplicated inline in `_signUp()`, not
factored out) got the same one-line addition, same position.

### Trade-off, stated plainly, not hidden

`PendingReport` cannot reopen the report form automatically. Doing so
would mean navigating to one specific route's Trip Details screen from
Home — the exact "return to a specific prior screen" problem the
`pushAndRemoveUntil` fix (commit 1c64f98) was written to eliminate. So
part 2 deliberately only tells the student to go find the route again;
finishing a report after a guest sign-in always costs one extra tap by
design, not by oversight.

### `context` lifetime — a risk worth naming, not glossing over

`completePendingIntent(context)` is called with the **sign-in/sign-up
screen's own** `context`, immediately after that screen has already
navigated away via `pushAndRemoveUntil`. The `PendingFavorite` branch
then does an `await` (`toggleFavorite`, a `SharedPreferences` write)
before checking `context.mounted` and showing the SnackBar. Whether the
old screen's `BuildContext` is still considered "mounted" at that point
depends on Flutter's route-transition timing (the outgoing screen is
disposed once its transition animation finishes, not necessarily the
instant `pushAndRemoveUntil` is called) — this should hold in practice
(the default page-transition duration comfortably outlasts a local
`SharedPreferences` write), but it is not a guaranteed contract the way
a same-frame check would be. This is exactly the scenario the task's
required manual-verification item below calls out.

## Files modified

New:
- `lib/core/pending_intent.dart`
- `lib/features/auth/presentation/pending_intent_completion.dart`
- `test/pending_intent_test.dart`

Modified:
- `lib/features/favorites/presentation/favorite_button.dart`
- `lib/features/favorites/presentation/favorites_screen.dart` (call site
  updated for the new required `routeName` parameter only)
- `lib/features/search/presentation/all_routes_screen.dart` (gate
  removed; unused `_authRepository` field and its now-unused
  `auth_repository.dart` import removed)
- `lib/features/search/presentation/search_results_placeholder.dart`
  (same as above)
- `lib/features/trip/presentation/trip_details_screen.dart` (gate
  removed, report entry point + `_ReportFormSheet` added)
- `lib/features/auth/presentation/student_login_screen.dart`
  (`_goToHome()` unchanged navigation call + one new line)
- `lib/features/auth/presentation/student_signup_screen.dart` (same, on
  its inline `pushAndRemoveUntil`)

Not touched: `firestore.rules`, `lib/core/models/report_model.dart`,
`lib/features/reports/data/reports_repository.dart` (used, not edited),
`lib/features/admin/presentation/admin_manage_screen.dart` /
`admin_home_screen.dart` (the Reports admin tab), `RouteModel`,
`StopModel`, `route_repository.dart`.

## Guard removals (file:line list)

Exact locations of every `currentUser != null`/`currentUser == null`
gate removed around `FavoriteButton` (pre-edit line numbers, captured
before any change this session):

1. `lib/features/trip/presentation/trip_details_screen.dart:206-207` —
   ```dart
   if (_authRepository.currentUser != null)
     FavoriteButton(routeId: route.id),
   ```
2. `lib/features/search/presentation/search_results_placeholder.dart:253-254` —
   ```dart
   if (_authRepository.currentUser != null)
     FavoriteButton(routeId: route.id),
   ```
3. `lib/features/search/presentation/all_routes_screen.dart:269-272` —
   ```dart
   if (_authRepository.currentUser != null)
     FavoriteButton(routeId: route.id)
   else
     const SizedBox.shrink(),
   ```

All three now read simply
`FavoriteButton(routeId: route.id, routeName: route.routeName),` with no
gate.

**Not changed, and why:** `lib/features/favorites/presentation/favorites_screen.dart:270`'s
`FavoriteButton(...)` had no `currentUser` gate directly around it — that
screen is itself only reachable via `home_page.dart`'s Favorites app-bar
icon, which is gated by `if (_authRepository.currentUser == null) ... else ...
IconButton(Favorites...)` at `home_page.dart:292`. That gate is on the
**entry point to the favorites list**, not on the `FavoriteButton` widget
itself, and the task's scope was specifically "everywhere `FavoriteButton`
currently checks `currentUser != null`" plus the new report entry point —
not the separate question of whether the Favorites list screen itself
should become guest-visible. Left untouched deliberately; flagging it here
in case that's a follow-up worth deciding separately.

## flutter analyze output

Clean, no new issues. One real issue surfaced and was fixed during this
task (not suppressed): `RadioListTile`'s `groupValue`/`onChanged` are
deprecated as of Flutter 3.32 in favor of a `RadioGroup` ancestor —
`_ReportFormSheet` was migrated to use `RadioGroup<ReportReason>` instead
of an `// ignore:` comment. Raw output saved to
`docs/audit-trail/d52-part2-guest-access-analyze.txt`.

```
Analyzing coasterna_project...
No issues found! (ran in 1.4s)
```

## flutter test output

All 70 tests passed (66 pre-existing as of the D52-part-1 session
immediately before this one + 4 new `PendingIntentHolder` unit tests).
Raw output saved to `docs/audit-trail/d52-part2-guest-access-test.txt`.

```
00:00 +70: All tests passed!
```

New tests, `test/pending_intent_test.dart`:

1. `consume()` returns null when nothing is pending
2. `set()` then `consume()` returns the stored intent and clears it
   (and a second `consume()` afterward returns null)
3. `set()` overwrites an unconsumed intent — only one at a time (setting
   a `PendingFavorite` then a `PendingReport` before either is consumed
   leaves only the second one to be found)
4. `PendingFavorite` and `PendingReport` both carry `routeId`/`routeName`
   correctly

## What still needs manual verification

- **Guest tap → sign-in → auto-favorite confirmation, on a real device,
  is not exercised by `flutter analyze`/`flutter test` and needs a
  screen recording.** This is the single most important thing to verify
  by hand: tap the (now guest-visible) star on Trip Details or a search
  result as a guest, confirm it navigates to sign-in without toggling
  anything yet, sign in, and confirm (a) Home appears with no stray back
  arrow (unrelated to this task, but worth re-confirming nothing
  regressed there), (b) the route just starred is now actually in
  Favorites, and (c) the "Added to favorites." SnackBar appears. This
  exercises exactly the `context`-lifetime risk described above under
  "Trade-off... not hidden" — if the SnackBar is missing but the
  favorite still landed, that confirms the timing assumption held for
  the toggle but not quite for the confirmation UI, which would be worth
  knowing.
- **Guest tap → sign-in → report SnackBar**, same device pass: tap
  "Report an issue" as a guest, sign in, confirm the "Signed in. Open the
  route again to finish your report." SnackBar appears (and that no
  report was actually created — nothing should exist in Firestore from
  this path, since it was never submitted).
- **Signed-in submit flow**: open "Report an issue" while already signed
  in, pick each of the five reasons (confirm "Other" reveals the text
  field and every other choice hides it), submit, confirm the SnackBar
  and that the sheet closes. Then check the admin Reports tab
  (unmodified this session, but this is the first time this session's
  work would actually produce a document for it to display) shows the
  new report with the right route name, reason label, and truncated uid.
- **Guest sign-up path** (not just sign-in): tap the star as a guest,
  choose "Create an account" instead of signing in, complete signup, and
  confirm the same auto-favorite + confirmation happens — this exercises
  `student_signup_screen.dart`'s copy of the same wiring, which is
  harder to reach in a quick manual pass than the sign-in path.
- **Existing regression check**: confirm favoriting/unfavoriting for an
  already-signed-in student still behaves exactly as before (icon
  toggles instantly, no snackbar, `FavoritesScreen`'s optimistic removal
  on unfavorite still works) — the widget's internal toggle logic itself
  was not changed, only gated by a new guest branch, but this is worth
  a real-device pass regardless since `FavoriteButton` is now reached
  from more places than before.
