# D52 part 2 — two real bugs investigated: neither reproduces against current source

Investigates two bugs found during real-device manual testing of D52 part
2 (guest-visible favorites/report buttons + pending-intent sign-in flow),
both screen-recorded by Tariq. After reading the actual code for each
(not assuming the stated "likely cause"), **neither reproduces against
the code currently on `dev`** — both were already fixed by earlier work
in this same line of sessions, before this task started. No `.dart` file
was changed by this task. This is stated plainly rather than fabricating
a change to justify the task, per the task's own "investigate, don't
assume" standard.

**D48 / file ownership:** `student_login_screen.dart`,
`student_signup_screen.dart`, and `trip_details_screen.dart` are Gaith's
area. Per decision D48 (pre-granted permission for Tariq to execute his
work via Claude Code during finals), this task read — and was prepared
to edit — all three under that permission; see each bug's "fix" section
below for why no edit was ultimately needed.

## Bug 1 root cause

**No code-level divergence exists between the two screens.** This is the
actual finding from a careful, line-by-line comparison — not the "written
twice, only one copy correct" shape the task described as the likely
pattern (the same shape as the earlier `_goToHome()` nav-stack bug, commit
1c64f98).

Both screens already delegate to the exact same shared function,
`completePendingIntent(context)` (`pending_intent_completion.dart:35`),
at the exact same point — immediately after their own unmodified
`pushAndRemoveUntil` call, fired via `unawaited(...)`:

- `student_login_screen.dart`, `_goToHome()` (lines 65–77)
- `student_signup_screen.dart`, `_signUp()`'s success path (lines 59–69)

Both call sites are textually identical in structure:
```dart
Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (context) => const HomePage()),
  (route) => false,
);
unawaited(completePendingIntent(context));
```

Confirmed there is only **one** implementation to diverge from in the
first place: `grep -rn "completePendingIntent\|PendingIntentHolder.consume"
lib/` returns exactly one function definition and exactly one
`.consume()` call site, both in `pending_intent_completion.dart`. The two
only `.set(...)` call sites in the whole app are `FavoriteButton._handleTap()`
(sets `PendingFavorite`) and `TripDetailsScreen._openReportForm()` (sets
`PendingReport`) — neither is reachable from either auth screen. "Create
an account" (`student_login_screen.dart`'s button) is a plain
`Navigator.of(context).push(...)` to `StudentSignUpScreen` — it does not
touch `PendingIntentHolder` at all, so nothing in the sign-in → sign-up
hop itself could substitute one intent type for the other.

**Given identical shared code, identical call-site structure, and no
other code path capable of swapping one intent type for the other, the
described divergence (wrong SnackBar, favorite not applied) cannot be
explained by anything currently in these files.** The most likely
explanation: the screen recording was captured against an earlier build
— most plausibly from before `pending_intent_completion.dart` was
extracted as a shared helper, when each auth screen may have carried its
own separately hand-written consumption logic (mirroring exactly how
`_goToHome()`'s original nav-stack bug — the hint this task pointed to —
really did exist as two independently-written, diverging copies before
commit 1c64f98 unified them). That earlier state isn't visible in the
current working tree to compare against directly, since `pending_intent_completion.dart`
was written as a single shared function from the point this feature was
first built, not refactored from two copies afterward.

## Bug 1 fix

**None applied.** Making a speculative edit to code that is already
correct and already shared between both screens would risk introducing a
regression into a path independently verified working (the sign-in
side's real-device video) and already covered by `pending_intent_test.dart`'s
unit tests for `PendingIntentHolder` itself. Per the task's own
instruction to report the divergence precisely before fixing: once no
divergence is found, the correct action is to report that, not invent a
change to have something to point at.

No new package, and `PendingIntentHolder`, `ReportsRepository`, and
`ReportModel` were correctly left untouched, as required — none of them
needed to be read further once the two screens' wiring was confirmed
identical.

## Bug 2 root cause

**Already fixed** — this is the identical overflow bug reported and
fixed in the immediately preceding audit-trail session
(`docs/audit-trail/d52-part2-overflow-fix.md`), and that fix is present
and intact in the current source. Re-verified by re-reading
`_ReportFormSheetState.build()` (`trip_details_screen.dart:592–693`)
fresh for this task rather than trusting the earlier report's claim:

- The `showModalBottomSheet` call (`_openReportForm()`, line 186) already
  has `isScrollControlled: true`.
- The sheet's outer `Padding` already adds
  `bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg`
  (line 598) — the sheet does correctly shift above the keyboard.
- The actual root cause (confirmed, same as the prior session): the
  content `Column` is wrapped in a `SingleChildScrollView` (line 617),
  giving it somewhere to go besides overflowing once "Other"'s extra
  `TextField` plus the keyboard's `viewInsets.bottom` push its intrinsic
  height past the modal route's bounded max-height.

This confirms the same conclusion as Bug 1: the two "likely cause"
hypotheses in this task's prompt (missing `isScrollControlled`, or the
content not accounting for `viewInsets.bottom`) are, once again, **not**
present — both were already correctly handled even before the earlier
session's fix. The real fix (the `SingleChildScrollView` wrapper) is
already in place. The screen recording for this bug almost certainly
predates that fix landing.

## Bug 2 fix

**None applied — already fixed.** No change was needed or made this
session; the `SingleChildScrollView` wrapper from the prior session
remains untouched.

## Files modified

**None.** `student_login_screen.dart`, `student_signup_screen.dart`,
`pending_intent_completion.dart`, `PendingIntentHolder`
(`lib/core/pending_intent.dart`), `favorite_button.dart`, and
`trip_details_screen.dart` were all read but not edited by this task.

## flutter analyze output

Clean — unchanged from before this task, since no file was edited. Raw
output saved to `docs/audit-trail/d52-part2-bugfixes-analyze.txt`.

```
Analyzing coasterna_project...
No issues found! (ran in 1.4s)
```

## flutter test output

All 70 tests passed — unchanged from before this task. **No new test was
added, deliberately, not by oversight**: no code was changed, so there is
no new pure logic to cover. Bug 1's fix (had one been needed) would have
been in widget-lifecycle-dependent glue code (which screen's `context`
fires a shared function after which navigation call) rather than a new
pure function — nothing there would be meaningfully unit-testable beyond
what `pending_intent_test.dart` already covers for `PendingIntentHolder`
itself (store/consume/overwrite semantics, already tested). Bug 2 is a
keyboard/layout-timing issue that `flutter test`'s headless environment
cannot exercise regardless, same reasoning as the prior overflow-fix
session. Raw output saved to `docs/audit-trail/d52-part2-bugfixes-test.txt`.

```
00:00 +70: All tests passed!
```

## What still needs manual verification

- **Re-test guest favorite-tap → sign-in → tap "Create an account" →
  complete signup → correct "Added to favorites." SnackBar + the route
  actually favorited, on a real device with screen recording** — against
  this exact current source, not the build the original video was
  captured from. Since this task made no code change, this is the only
  way to confirm whether the bug is truly gone or whether it's a
  runtime/timing issue (e.g. something specific to how a particular
  device transitions between the two screens) that this static
  investigation couldn't observe. If it still reproduces, capture which
  branch of `completePendingIntent()`'s `switch` actually ran (a debug
  print naming the consumed intent's runtime type would settle it in one
  run) — that turns this from a code-reading question into a runtime one.
- **Re-test "Other" with the keyboard open, on a real device with screen
  recording, confirm zero overflow pixels and that the field and submit
  button stay reachable** — same reasoning: confirm against current
  source, since the `SingleChildScrollView` fix already landed in the
  previous session and this task found nothing further to change.
- If either re-test still fails, that's new evidence this investigation
  didn't have — worth a fresh, separate task with that evidence attached
  rather than another guess made without it.
