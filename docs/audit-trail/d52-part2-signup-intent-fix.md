# D52 part 2 — signup pending-intent bug: investigation result

**D48 / file ownership:** `student_login_screen.dart` and
`student_signup_screen.dart` are Gaith's area. Per decision D48
(pre-granted permission for Tariq to execute his work via Claude Code
during finals), this task read and would have edited them under that
permission — see "Fix applied" below for why no edit was ultimately made.

## Root cause

**No code-level divergence was found between the two screens.** This is
the actual finding from a careful, line-by-line comparison — not an
assumption, and not the "written twice, only one copy correct" pattern
the task described as the likely shape of the bug.

Both `_goToHome()` (`student_login_screen.dart:65-77`) and `_signUp()`'s
success path (`student_signup_screen.dart:59-69`) already call the exact
same shared function, `completePendingIntent(context)` from
`pending_intent_completion.dart`, at the exact same point — immediately
after their respective (unmodified) `pushAndRemoveUntil` call, via
`unawaited(...)`:

```dart
// student_login_screen.dart, _goToHome()
Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (context) => const HomePage()),
  (route) => false,
);
unawaited(completePendingIntent(context));

// student_signup_screen.dart, _signUp() success path
Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (context) => const HomePage()),
  (route) => false,
);
unawaited(completePendingIntent(context));
```

`completePendingIntent()` itself (`pending_intent_completion.dart:35-64`)
is a single implementation, not duplicated anywhere — confirmed with
`grep -rn "Added to favorites\|Signed in. Open the route again" lib/`,
which returns exactly one match for each string, both inside
`pending_intent_completion.dart`. It correctly switches on the sealed
`PendingIntent` type (`PendingFavorite` → toggle + "Added to
favorites."; `PendingReport` → the "Open the route again" message), and
nothing else in the codebase calls `PendingIntentHolder.consume()` —
confirmed with `grep -rn "PendingIntentHolder.consume"`, one call site,
inside `completePendingIntent()`.

The only two places that call `PendingIntentHolder.set(...)` are
`FavoriteButton._handleTap()` (sets `PendingFavorite`) and
`TripDetailsScreen._openReportForm()` (sets `PendingReport`) — neither is
reachable from `StudentLoginScreen` or `StudentSignUpScreen`, so nothing
in the sign-in/sign-up flow itself could overwrite a `PendingFavorite`
with a `PendingReport`. "Create an account" is a plain
`Navigator.of(context).push(...)` to `StudentSignUpScreen` — it does not
touch `PendingIntentHolder` at all.

**Conclusion:** given identical shared code, identical call-site
structure, and no other code path capable of substituting one intent
type for the other, the currently-checked-out source does not reproduce
the described divergence. The most likely explanation, consistent with
this same investigation's prior finding on the `_ReportFormSheet`
overflow bug (also already fixed in the current source when that bug
report arrived), is that the screen recording was captured against an
earlier build — most plausibly from before `pending_intent_completion.dart`
was extracted as a shared helper, when each screen may have carried its
own separately-written (and, per the report, divergent) inline
consumption logic. That earlier state is not visible in the current
working tree to compare against directly.

## Fix applied

**None.** Making a speculative change to code that is already correct
and already shared between both screens would risk introducing a
regression into a path that passed its own verification (the sign-in
side's real-device video) and is covered, however indirectly, by
`pending_intent_test.dart`. Per the task's own standard ("investigate,
don't assume... report it precisely before fixing"), the correct action
once no divergence is found is to report that finding rather than
invent a change to justify. If a fresh real-device pass against this
exact source (see below) reproduces the bug again, that would mean the
divergence is either a genuine runtime/timing issue this static
comparison cannot see (for example, something specific to how the OS
transitions between the two screens on that device) rather than a
logic bug in these three files, and would need its own targeted
investigation with that evidence in hand — not a guess made now.

## Files modified

None. `student_login_screen.dart`, `student_signup_screen.dart`,
`pending_intent_completion.dart`, and `PendingIntentHolder` were read
but not edited.

## flutter analyze output

Clean — unchanged from before this task, since no file was edited. Raw
output saved to `docs/audit-trail/d52-part2-signup-intent-fix-analyze.txt`.

```
Analyzing coasterna_project...
No issues found! (ran in 1.8s)
```

## flutter test output

All 70 tests passed — unchanged from before this task. No new test was
added: no code change was made, so there is no new pure logic to cover,
and (per the earlier overflow-bug session's same reasoning) a keyboard-
or navigation-timing-dependent scenario like this one is not something
`flutter test`'s headless environment can exercise regardless. Raw
output saved to `docs/audit-trail/d52-part2-signup-intent-fix-test.txt`.

```
00:00 +70: All tests passed!
```

## What still needs manual verification

- **Re-test guest favorite-tap → CREATE ACCOUNT → correct "Added to
  favorites." SnackBar + route actually favorited, on a real device with
  screen recording**, against the current source (this exact working
  tree, not the build the original video was captured from). Since this
  task made no change, this pass is the only way to confirm whether the
  bug still exists in the current code or was already resolved by the
  earlier `pending_intent_completion.dart` extraction.
- **The same for a guest report-tap → CREATE ACCOUNT → correct "Signed
  in. Open the route again..." message**, since a fix (if one turns out
  to still be needed) would touch both intent types through the same
  shared function.
- If either re-test still shows the wrong SnackBar or a route that
  isn't actually favorited, capture the exact device/OS and, if
  possible, add a debug print or breakpoint in `completePendingIntent()`
  to log which branch of the `switch` actually runs and what
  `PendingIntentHolder.consume()` actually returned — that would turn
  this from a static-analysis question into a runtime one this
  investigation could not observe.
