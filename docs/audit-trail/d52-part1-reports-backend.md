# D52, part 1 — Reports data layer, Security Rules, admin review screen

Implements decision D52 part 1 of 2 on `dev`: a new `reports` Firestore
collection so a signed-in student can flag a data error on a route. This
part is the data layer, the Security Rules, and the admin-side review
table only. **No student-facing "submit a report" UI exists yet** — that
is part 2, a separate task, per the prompt's explicit scope split. Guest-
access buttons and the favorites flow were not touched.

## Changes made

### 1. `ReportModel` (`lib/core/models/report_model.dart`, new file)

- `ReportReason` enum: `priceIncorrect`, `scheduleIncorrect`,
  `routeNotOperating`, `stopInfoIncorrect`, `other`. `fromFirestore`/
  `toFirestore` map to `PRICE_INCORRECT` / `SCHEDULE_INCORRECT` /
  `ROUTE_NOT_OPERATING` / `STOP_INFO_INCORRECT` / `OTHER` —
  SCREAMING_SNAKE_CASE, the exact pattern `DepartureType` and
  `RouteDirection` already use (switch-based, throws `ArgumentError` on
  an unknown value).
- `ReportStatus` enum: `open`/`resolved` ↔ `OPEN`/`RESOLVED`, same
  pattern.
- `ReportModel` fields: `id` (document id, not written into the body —
  same convention as `RouteModel`/`StopModel`), `routeId`, `routeName`
  (denormalized snapshot, same pattern as `originStopName`/
  `destinationStopName` on `RouteModel`), `reason`, `otherText`
  (nullable, only meaningful when `reason == other`), `reportedByUid`,
  `status`, `createdAt` (`DateTime` in the model, `Timestamp` on the
  wire via `Timestamp.fromDate()`/`.toDate()` — same convention
  `RouteModel` uses for `collectedOn`).
- `reasonLabel` getter returns the exact five display strings given in
  the task prompt.
- `fromFirestore`/`toFirestore` naming kept exactly as-is, matching
  every other model in this codebase — not renamed.

### 2. `ReportsRepository` (`lib/features/reports/data/reports_repository.dart`, new file)

- Same repository-pattern style as `RouteRepository`/`AuthRepository`:
  constructor takes an optional `FirebaseFirestore`, no singleton.
- `createReport(ReportModel report)` — `.add()`s to `reports`. `report.id`
  is ignored, same convention as `createRoute()`/`createStop()`.
  `reportedByUid`/`status` correctness is enforced by Security Rules,
  not by this method.
- `getAllReports()` — returns `RepoResult<List<ReportModel>>`, ordered by
  `createdAt` descending. Reuses `RepoResult` from `route_repository.dart`
  (`import '../../search/data/route_repository.dart' show RepoResult;`)
  rather than defining a second copy of the same `isFromCache` wrapper.
- `resolveReport(String reportId)` — `.update({'status': 'RESOLVED'})`.

Nothing in `route_repository.dart` itself was touched — the `show
RepoResult` import only reads a class it already exports, so Abdallah's
file needed no edit and D48's pre-granted permission was not exercised.

### 3. Firestore Security Rules (`firestore.rules`)

Added a `reports` match block, placed after `admins` and before the
default-deny catch-all:

```
match /reports/{reportId} {
  allow create: if request.auth != null &&
    request.resource.data.reportedByUid == request.auth.uid &&
    request.resource.data.status == 'OPEN';
  allow read, update: if isAdmin();
  allow delete: if false;
}
```

- `create`: signed-in only, `reportedByUid` must equal the caller's own
  `request.auth.uid`, and the written `status` must be exactly `'OPEN'`.
- `read`/`update`: reuse the existing `isAdmin()` helper unchanged — no
  duplicated admin-check logic.
- `delete`: unconditionally denied (`if false`), for every caller
  including admins — reports are an audit trail, not a queue items get
  removed from.

`docs/data-model.md`'s own embedded copy of `firestore.rules` was
**not** updated to add `reports` — that copy is already stale for an
unrelated reason (it still shows the pre-2026-08-23 `admins` rule, not
the self-read version actually in `firestore.rules` today), and syncing
that file wasn't one of the task's five scope items. Flagging it here
rather than fixing it silently, per CLAUDE.md's "don't silently pick a
resolution" guidance for pre-existing discrepancies.

### 4. Admin Reports tab

**`lib/features/admin/presentation/admin_manage_screen.dart`** — added a
new `ReportsManageList` widget plus its supporting pieces
(`_ReportStatusPill`, `_ReportRowMenu`, `_truncateUid`,
`_formatReportDate`), reusing this file's existing `_TableCard`,
`_TableRow`, `_HeadCell`, `_Cell`, `_ListHeader`, and `_StateMessage`
building blocks — the same pattern `StopsManageList`/`RoutesManageList`
already use.

- Columns: ROUTE · REASON · REPORTED BY · DATE · STATUS · `···`.
- REPORTED BY shows `_truncateUid()` — first 8 characters of the raw uid
  plus `…`. No user-lookup mechanism was built, per the constraint.
- DATE uses `AppTextStyles.monoData` (via `_Cell(..., mono: true)`),
  formatted `"YYYY-MM-DD HH:mm"` — date-and-time, not date-only like the
  admin forms' `collectedOn` field, since more than one report can land
  on the same day and the admin needs to tell them apart.
- STATUS: a new `_ReportStatusPill` (Open in `AppColors.accent` gold on
  a derived light tint `_kOpenBg`, Resolved in the existing
  `_kSuccess`/`_kSuccessBg` green already used for the Active pill) —
  intentionally a separate small widget from the existing `_StatusPill`
  rather than overloading it, since `_StatusPill`'s Active/Inactive
  semantics and colors don't match Open/Resolved's.
- `···` menu: a new `_ReportRowMenu` with exactly one action, "Mark
  resolved" — a separate widget from the existing `_RowMenu`, since that
  widget's Edit/Deactivate/Delete set doesn't apply here. Disabled
  (greyed out, `PopupMenuButton.enabled: false`) once a report is
  already resolved, since there is no "reopen" action.
- No add/edit button in the `_ListHeader` — `actionLabel`/`onAction` are
  left null, which the existing header widget already renders as "no
  button" — matching the constraint that this part adds no submit-report
  UI anywhere.
- `RepoResult.isFromCache` is honored: an `OfflineBanner` (the same
  widget `AllRoutesScreen` already uses) shows above the table when the
  loaded data came from the local cache rather than the server.

**`lib/features/admin/presentation/admin_home_screen.dart`**:

- `_AdminSection` gained a third value, `reports`. **`_AdminView` was
  deliberately left unchanged** — the task prompt says "add `reports` to
  the `_AdminView` enum," but `_AdminView` specifically distinguishes
  "showing the list" from "a form panel is open" (`stopForm`/
  `routeForm`), and Reports has no add/edit form in this part (no
  submit-report UI, "Mark resolved" is a row action, not a form). Adding
  it to `_AdminSection` — the enum that actually drives the sidebar
  selection — is the change that produces the described behavior (a
  fourth sidebar tab with its own table) without inventing an unused
  `_AdminView.reports` case that would need special-casing to avoid
  ever reaching a nonexistent form. Noting this as a deliberate
  implementation-accuracy deviation from the literal wording, not an
  oversight.
- Sidebar gets a fourth `_SidebarItem`, "Reports" (or "Reports (N)" once
  a count is known), positioned below Stops, same text-only style as
  Routes/Stops/Sign out.
- New `int? _openReportCount` state, null until the Reports tab has been
  opened at least once this session. `_buildContent()`'s list branch now
  switches on `_section` (routes/stops/reports) and, for `reports`,
  returns `ReportsManageList(onOpenCountChanged: ...)` — the callback
  is how the sidebar count is kept in sync with **zero extra queries**:
  `ReportsManageList` already calls `getAllReports()` once to populate
  its own table, and just relays the resulting open-count upward instead
  of `AdminHomeScreen` issuing a second, redundant fetch.
  - **Trade-off, documented not hidden**: because the count is only
    known once `ReportsManageList` has loaded (and it unmounts when you
    navigate to a different sidebar section, the same way
    `RoutesManageList`/`StopsManageList` already do), the sidebar shows
    plain `"Reports"` (no count) until Reports has been opened at least
    once in the session, and afterward shows the count as of that last
    visit rather than live-updating while looking at a different tab.
    This was the correct reading of the constraint "no extra query
    beyond the one `getAllReports()` call this view already needs" —
    a background poll just to keep the sidebar fresh would violate that
    constraint.

### 5. Rules Playground test documentation

See **Manual Rules Playground steps required** below. The existing
SR-numbered cases live in `docs/audit-trail/security-rules-verification.md`
("Owner: Abdallah Abufara · Task #9"), **not** `docs/data-model.md` (that
file documents the rules but does not carry SR case numbers). The
highest existing case is **SR-16** (Round 2, 2026-08-23). New cases
below continue from **SR-17**.

These are **drafted, not executed** — this task has no Firebase Console
access, and `security-rules-verification.md` is explicitly Abdallah's
file (Task #9 ownership header), which this task's constraints did not
grant permission to edit (unlike `route_repository.dart`, which the
constraints explicitly pre-cleared). So the case definitions are
documented here only, with **Expected** filled in from reading
`firestore.rules`, and no **Actual**/**Result** — those columns can only
be filled in by whoever actually runs them in the Console, matching that
file's own stated methodology ("expected outcome derived from reading
the rule source... outcome actually observed"). Once run, these rows are
ready to paste into a new "Round 3" section of
`security-rules-verification.md` in the same format as its existing
"Round 2" section.

## Files modified

New:
- `lib/core/models/report_model.dart`
- `lib/features/reports/data/reports_repository.dart`
- `test/report_model_test.dart`

Modified:
- `firestore.rules`
- `lib/features/admin/presentation/admin_home_screen.dart`
- `lib/features/admin/presentation/admin_manage_screen.dart`

Not touched: `favorites_repository.dart`, `FavoriteButton`, any
signed-in-only UI visibility logic, `route_repository.dart`, `StopModel`,
the `stops`/`routes`/`admins` collections' existing rules (only appended
to, not edited), and no submit-report button/form anywhere.

```
 firestore.rules                                    |  17 ++
 lib/features/admin/presentation/admin_home_screen.dart   |  57 ++++-
 lib/features/admin/presentation/admin_manage_screen.dart | 260 +++++++++++++++++++++
 3 files changed, 322 insertions(+), 12 deletions(-)
```
(plus the three new files above, not shown in a diffstat)

## flutter analyze output

Clean, no new issues. Raw output saved to
`docs/audit-trail/d52-part1-reports-backend-analyze.txt`.

```
Analyzing coasterna_project...
No issues found! (ran in 32.4s)
```

## flutter test output

All 66 tests passed (53 pre-existing as of the D51 session immediately
before this one + 13 new `ReportModel` unit tests). Raw output saved to
`docs/audit-trail/d52-part1-reports-backend-test.txt`.

```
00:00 +66: All tests passed!
```

New tests, `test/report_model_test.dart`:

1. `ReportReason.fromFirestore` maps every SCREAMING_SNAKE_CASE value
2. `ReportReason.toFirestore` is the exact inverse of `fromFirestore`
3. `ReportReason.fromFirestore` throws `ArgumentError` on an unknown value
4. `ReportStatus.fromFirestore` maps `OPEN`/`RESOLVED` correctly
5. `ReportStatus.toFirestore` is the exact inverse of `fromFirestore`
6. `ReportStatus.fromFirestore` throws `ArgumentError` on an unknown value
7. `reasonLabel` returns the exact display string for every enum value
8. `otherText` is null when reason isn't `other` and none was given
9. `otherText` carries the free-text reason through `toFirestore()` when set
10. `toFirestore()` does not write `id` into the document body
11. `toFirestore()` writes `createdAt` as a `Timestamp`, not a `DateTime`
12. `toFirestore()` writes `reason`/`status` as their Firestore strings
13. Every field round-trips through the Firestore string/enum conversions

Same scope note as the D51 session: `ReportModel.fromFirestore()` is not
called directly against a real `DocumentSnapshot` — this project has no
Firestore-faking package and adding one would violate the "no new
package" constraint. Test 13 instead exercises `fromFirestore()`'s actual
per-field parsing (`ReportReason.fromFirestore`, `ReportStatus.fromFirestore`,
`Timestamp.toDate()`) against `toFirestore()`'s real output, which is the
same testing approach already established for `RouteModel.pathPoints` in
the prior session.

## Manual Rules Playground steps required

Firebase Console → `coasterna-fa940` → Firestore Database → Rules → Rules
Playground. Use the same identity labels `security-rules-verification.md`
already defines: **ANON** (Authenticated toggle off), **STUDENT** (a
signed-in uid with no `admins` document — the doc reuses
`SMBtoHsQG9fL1E5kSV8maNFujP63`), **ADMIN** (a signed-in uid that exists
in `admins` — the doc reuses `fx53osBbW7g4gAHN4TICcwWPwS62`). Run these
in order; record each **Actual** outcome and **Pass**/**Fail** as you go.

1. **SR-17** — student create, own uid, status OPEN.
   Identity: STUDENT. Operation: `create`. Location:
   `/reports/testReport1`. Document data:
   `{ routeId: "route1", routeName: "Sweileh to AAU Main Gate", reason: "PRICE_INCORRECT", otherText: null, reportedByUid: "SMBtoHsQG9fL1E5kSV8maNFujP63", status: "OPEN", createdAt: <any timestamp> }`.
   **Expected: Allowed** — `request.auth != null`, `reportedByUid ==
   request.auth.uid`, `status == 'OPEN'` all hold.

2. **SR-18** — student create, someone else's uid.
   Identity: STUDENT. Operation: `create`. Location:
   `/reports/testReport2`. Same document data as SR-17, except
   `reportedByUid: "fx53osBbW7g4gAHN4TICcwWPwS62"` (a different uid —
   the ADMIN uid works fine as "someone else's" for this purpose).
   **Expected: Denied** — `reportedByUid == request.auth.uid` fails.

3. **SR-18b** — student create, own uid, but pre-resolved (extra case
   worth running alongside SR-18 since it exercises the rule's second
   condition; not one of the five bullets in the task list but covers
   the same `create` rule completely). Identity: STUDENT. Operation:
   `create`. Location: `/reports/testReport2b`. Same as SR-17 except
   `status: "RESOLVED"`. **Expected: Denied** —
   `status == 'OPEN'` fails.

4. **SR-19** — student cannot read the collection.
   Identity: STUDENT. Operation: `get` (or `list`). Location:
   `/reports/testReport1` (or the `reports` collection for `list`).
   **Expected: Denied** — `isAdmin()` is false for STUDENT.

5. **SR-20** — admin can read reports.
   Identity: ADMIN. Operation: `get`. Location: `/reports/testReport1`.
   **Expected: Allowed** — `isAdmin()` is true for ADMIN.

6. **SR-21** — admin can update (resolve) a report.
   Identity: ADMIN. Operation: `update`. Location:
   `/reports/testReport1`. Update data: `{ status: "RESOLVED" }`.
   **Expected: Allowed** — same `isAdmin()` branch as SR-20.

7. **SR-22** — unauthenticated request cannot create a report.
   Identity: ANON. Operation: `create`. Location: `/reports/testReport3`.
   Same document data as SR-17. **Expected: Denied** —
   `request.auth != null` fails before the rest of the `create` rule is
   even evaluated.

8. **SR-23** (bonus, matching SR-06's "write covers delete" pattern from
   Round 1 — worth confirming since `delete` is a separate branch here,
   not implied by a blanket `write`) — no one can delete a report, not
   even an admin. Identity: ADMIN. Operation: `delete`. Location:
   `/reports/testReport1`. **Expected: Denied** — `allow delete: if
   false` unconditionally.

Once run, these are ready to append to
`docs/audit-trail/security-rules-verification.md` as a new "Round 3 —
Reports collection (D52)" section, in the same table format as its
existing "Round 2" section — that edit was left for Abdallah/Tariq to
make, not done as part of this task.

## What still needs manual verification

- **The eight Rules Playground cases above** — not run in this session,
  no Console access available to this task.
- **Firestore composite index.** `getAllReports()` uses `orderBy(
  'createdAt', descending: true)` with no other filter — a single-field
  index, which Firestore maintains automatically, so no composite index
  should be needed. Worth confirming on first real run against the live
  project regardless, the way `searchRoutesByOrigin()`'s composite-index
  note in `route_repository.dart` flags the same category of surprise.
- **Live admin UI.** Not run in a browser this session. Once at least
  one real report document exists (which requires part 2's submit form,
  or a document added by hand through the Console for testing), check
  in the running Admin Dashboard: the Reports tab loads the table, REPORTED
  BY truncates correctly, the Open/Resolved pill colors match the design
  tokens, "Mark resolved" updates the row and greys out the menu, the
  sidebar count updates after visiting the tab, and the empty state
  ("No reports yet.") renders correctly with zero documents.
- **Offline banner path.** `RepoResult.isFromCache` and the new
  `OfflineBanner` usage in `ReportsManageList` were not exercised against
  a real offline device/emulator this session — only the widget wiring
  was verified via `flutter analyze`.
- **`docs/data-model.md`.** Its `Collections` table and embedded rules
  copy do not yet mention `reports` — flagged above as intentionally out
  of this task's five scope items, not fixed silently. Worth a follow-up
  if Tariq wants the durable schema doc kept current.
- **Part 2 dependency.** Nothing in this part creates a report through
  the running app — `createReport()` is callable but unused until part 2
  builds the student-facing submit form. The five verification bullets
  above are the only way to exercise the `create` rule until then.
