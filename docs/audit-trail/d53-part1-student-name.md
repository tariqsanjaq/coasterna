# D53 Part 1 — Student name at sign-up, shown on admin Reports table

Decision D53, part 1 of 2. Part 2 (a settings/profile page letting an
existing account set/change its name) is separate future work and was
**not** built here.

`student_signup_screen.dart` and `trip_details_screen.dart` are Gaith's
area — D48 pre-approval applies. Noted again in the suggested commit
message at the bottom.

## Changes made

1. **Sign-up form** (`student_signup_screen.dart`) — added required
   "First name" and "Last name" text fields above the existing
   email/password/confirm fields, styled identically to the existing
   fields (same `TextField` + `InputDecoration(hintText, prefixIcon)`
   pattern, `AppSpacing.md` gaps). Validation: both non-empty after
   `.trim()`, checked before the existing email/password checks — no
   name-format regex, as instructed.

   On successful account creation, the screen now:
   - calls `userCredential.user?.updateDisplayName('$firstName $lastName')`
     (trimmed, single space joining first and last),
   - then `await userCredential.user?.reload()`,
   - then proceeds to navigation / `completePendingIntent()`, which
     read the display name via `AuthRepository().currentUser` — a live
     getter on `FirebaseAuth.instance`, so it already reflects the
     reload without the widget needing to hold a second reference.

   `AuthRepository.signUp()` had to change its return type from
   `Future<void>` to `Future<UserCredential>` so the widget can reach
   the newly-created `User` to call `updateDisplayName`/`reload` on it.
   This was the method's only call site (`grep` confirmed), so the
   signature change is safe.

   `student_login_screen.dart` was **not** touched — existing accounts
   signing in stay out of scope for this part, per the task.

2. **`ReportModel`** — added `reportedByName` (`String?`), following
   the exact convention `RouteModel.pathPoints` (D51) already
   established for an optional field:
   - nullable, no `required`,
   - `toFirestore()` writes the key unconditionally (`null` when
     absent, not omitted — verified by a new test asserting
     `data.containsKey('reportedByName')` is `true` even when the
     value is `null`),
   - `fromFirestore()` parses defensively: `data['reportedByName'] is
     String ? ... as String : null` — a missing key, `null` value, or
     wrong type all resolve to `null`, never throws.

3. **Report submission** (`trip_details_screen.dart`,
   `_ReportFormSheetState._submit()`) — now also reads
   `_authRepository.currentUser?.displayName` and passes it as
   `reportedByName` on the `ReportModel` passed to
   `ReportsRepository().createReport()`. A `null` or empty
   `displayName` (pre-D53 account) is normalized to `null` before
   being passed — does not throw or block submission.

4. **Admin Reports table** (`admin_manage_screen.dart`) — added a
   `_reportedByDisplay(ReportModel report)` helper next to the existing
   `_truncateUid()`: returns `report.reportedByName` when non-null and
   non-empty, otherwise falls back to `_truncateUid(report.reportedByUid)`
   unchanged. The REPORTED BY cell now calls this helper instead of
   `_truncateUid()` directly. Column header, `flex`, and `mono` styling
   were left exactly as they were — only the value source changed.

## `firestore.rules` — deliberately not touched

Per the task's explicit instruction: the existing `reports` create rule
already trusts client-provided denormalized fields the same way it
already trusts `routeName` (both are report-time snapshots the client
supplies, not values the server can independently verify against
another collection). `reportedByName` is the same kind of field and
needs no new validation for the same reason. I read the actual rule in
`firestore.rules` before deciding this — it does not enumerate/require
specific field names on create beyond the ones tied to `request.auth`
(`reportedByUid`) and status (`status == 'OPEN'`), so adding one more
denormalized string field does not change what the rule needs to
enforce. I did not change the file. If this reasoning looks wrong on a
closer read, it should be revisited rather than taken as settled by
this report.

## Files modified

- `lib/features/auth/data/auth_repository.dart` — `signUp()` now
  returns `Future<UserCredential>` instead of `Future<void>`.
- `lib/features/auth/presentation/student_signup_screen.dart` — first/last
  name fields, validation, `updateDisplayName()` + `reload()` flow.
- `lib/core/models/report_model.dart` — `reportedByName` field,
  `fromFirestore()`/`toFirestore()` support.
- `lib/features/trip/presentation/trip_details_screen.dart` — passes
  `reportedByName` when submitting a report.
- `lib/features/admin/presentation/admin_manage_screen.dart` —
  `_reportedByDisplay()` helper, used in the REPORTED BY cell.
- `test/report_model_test.dart` — `reportedByName` added to the
  `_baseReport()` helper and the full-field round-trip test; two new
  tests added (null-by-default writes `null` with the key still
  present; carries a set value through `toFirestore()`) — same shape
  as `route_model_test.dart`'s `pathPoints` tests.

Not touched, per constraints: `student_login_screen.dart`,
`firestore.rules`, `PendingIntentHolder`/`completePendingIntent()`, the
favorites flow, the report reason list/submit button logic (beyond
threading the new field through), any new Firestore collection, any
new package, any profile/settings screen.

## flutter analyze output

```
No issues found! (ran in 1.5s)
```

Full raw output: `d53-part1-student-name-analyze.txt`.

## flutter test output

```
00:00 +72: All tests passed!
```

All 72 tests pass — the 70 that existed before this change, plus the
2 new `reportedByName` tests added to `report_model_test.dart`.

Full raw output: `d53-part1-student-name-test.txt`.

## Was `user.reload()` actually needed?

Yes — based on the Firebase Auth SDK's documented behavior, not
assumed. `updateDisplayName()` (via `updateProfile()`) sends the
change to the Firebase Auth backend, but the SDK's local `User` object
is a cached snapshot of the user's profile; that cache is not
guaranteed to reflect a profile field just written by the same client
until the profile is re-fetched. `reload()` is the documented way to
force that re-fetch and refresh the cached `User` (and the token it
holds) in place. Without it, this task's own spec description that
"Firebase Auth does not reliably reflect a just-set `displayName` on
the same `User` object without a reload" would apply: `completePendingIntent()`
running immediately after sign-up could read a stale (null)
`displayName` from `AuthRepository().currentUser`, and the very first
report a brand-new student submits (before ever restarting the app)
would fall back to the truncated-uid display instead of showing their
name — silently defeating the point of this feature for the most
common case (a student who signs up specifically to report something).
`reload()` closes that window. This could not be observed directly in
this session (no live Firebase project / real device connected — see
below), so the reasoning above is the SDK's documented contract, not a
reproduced stale value.

## What still needs manual verification

The following require a real device/emulator against the live
`coasterna-fa940` Firebase project — nothing in this session ran the
app:

1. **Sign up with a real device.** Confirm the "First name" / "Last
   name" fields render above email/password with the same visual
   styling as the existing fields (no new input style was introduced,
   but this should be eyeballed against the Primary #0F2B43 / Accent
   #AF9064 / Error #A32D2D tokens on an actual screen).
2. **Confirm the name is required and validated.** Leaving either name
   field empty (or only whitespace) should block submission with the
   "Enter your first and last name." message, before the
   email/password checks fire.
3. **Confirm a report submitted right after signup shows the real name
   in the admin table — not the truncated uid.** Sign up as a new
   student, immediately open a trip and submit a report without
   restarting the app, then check the admin Reports tab: the REPORTED
   BY cell should show the typed first/last name, not
   `<first8chars>…`. This is the specific case the `reload()` call
   above exists to make work.
4. **Confirm the 9 existing test reports still show their truncated
   uid unchanged.** Those documents have no `reportedByName` field at
   all (created before this change) — `fromFirestore()`'s defensive
   parse should read that as `null` and `_reportedByDisplay()` should
   fall back to `_truncateUid()`, exactly as before this change.

## Suggested commit message

```
feat(auth): student name at signup, shown on admin Reports table (D53 part 1)

Gaith pre-approval D48 applies (student_signup_screen.dart,
trip_details_screen.dart).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_018uH7tcwu4EAGR9cCHf9DQM
```
