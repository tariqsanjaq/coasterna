# D52 part 2 — `_ReportFormSheet` keyboard overflow fix

Fixes a real, manually-reproduced layout bug in `_ReportFormSheet` (the
"Report an issue" bottom sheet on `trip_details_screen.dart`, added in the
D52 part 2 session): "A RenderFlex overflowed by 2.4 pixels on the
bottom," reproduced on a real device with "Other" selected and the
keyboard open, screen-recorded by Tariq.

**D48 / file ownership:** `trip_details_screen.dart` is Gaith's area. Per
decision D48 (pre-granted permission for Tariq to execute his work via
Claude Code during finals), this task edited it — flagged here and in the
suggested commit message, per the standing coordination rule.

## Root cause

**Not** the two hypotheses the bug report suggested checking first — both
were already correct before this fix:

- `showModalBottomSheet(...)` at the call site (`_openReportForm()`)
  already had `isScrollControlled: true`.
- The sheet's outer `Padding` already added
  `bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg`, so
  the sheet does correctly shift itself up above the keyboard.

**The actual cause**, confirmed by reading `_ReportFormSheetState.build()`
before making any change: the sheet's content was a plain `Column`
(`mainAxisSize: MainAxisSize.min`) sitting directly inside that `Padding`
— with **no scrolling ancestor anywhere in the tree**. `isScrollControlled:
true` only removes the modal route's default ~half-screen height cap so
the sheet is *allowed* to grow taller; it does not make the content
itself scrollable, and nothing else in this widget tree did either. (For
comparison: this file's own doc comment claimed `_ReportFormSheet` copied
"the same shape `StopPickerSheet` already establishes," but
`stop_picker_sheet.dart` actually uses a `DraggableScrollableSheet` with
an internal `ListView` bound to a `scrollController` — a real scrolling
mechanism that `_ReportFormSheet` never actually copied, only the
surface-color/rounded-corner/`isScrollControlled` styling.)

With "Other" selected, the sheet's content grows by a 3-line `TextField`
plus its spacing. With the keyboard open, `viewInsets.bottom` grows large,
which (a) adds to the `Padding`'s own bottom inset, increasing how tall
the content needs to be to fit its natural size, and (b) simultaneously
shrinks the actual visible height the modal route has available to give
the sheet. Once the `Column`'s combined intrinsic height (title +
subtitle + 5 radio rows + spacing + the "Other" `TextField` + spacing +
submit button + that bottom inset) exceeds the bounded max-height the
modal route is passing down, `RenderFlex` — which cannot shrink below
its children's needs and has nothing here to scroll — reports the
overflow. This matches every observed detail: it only happens with
"Other" selected (extra content height) and only with the keyboard open
(both more required height and less available height at once), and the
overflow amount is small (a few pixels), consistent with content that
just barely doesn't fit rather than being wildly too large.

## Fix applied

Wrapped the existing `Column` in a `SingleChildScrollView`, inside the
same `Padding` — nothing else in the tree changed:

```dart
child: SingleChildScrollView(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [ /* unchanged */ ],
  ),
),
```

**Why this actually fixes it, reasoned from the widget tree, not just
"padding that hides the symptom":** the modal route gives the sheet's
content *loose* (`minHeight: 0`) but *bounded* (`maxHeight: <available
space>`) constraints — bounded is exactly why the overflow error could
happen at all; if it were unbounded, `RenderFlex` would never report an
overflow. `SingleChildScrollView`'s render object gives its **child**
unbounded height (`maxHeight: double.infinity`) regardless of its own
incoming constraint — this is what lets the `Column` be taller than the
visible area without being force-fit into it. The scroll view's own size
is then `constraints.constrain(child.size)`: since the incoming
`minHeight` is `0`, when the `Column`'s natural height is **shorter**
than the available max (keyboard closed, or "Other" not selected), the
scroll view shrinks to exactly that height — pixel-identical to the
unwrapped `Column`'s previous behavior, with no scrollbar or visible
affordance because there is nothing to scroll. Only when the `Column`'s
natural height **exceeds** the available max (keyboard open AND "Other"
selected) does the scroll view clamp itself to that max and let the
`Column` scroll inside it — content becomes reachable by scrolling
instead of clipped or overflowing, and the `RenderFlex` never sees a
constraint smaller than what it asked for, so it never reports overflow.

This satisfies every fix requirement: zero overflow pixels regardless of
which reason is selected or whether the keyboard is open; the field and
submit button stay reachable (via scroll, only when needed); the
keyboard-closed appearance is unchanged (verified by the shrink-wrap
reasoning above, not just visually assumed); the five-reason list, the
"Other" reveal `if` block, the submit button, and
`ReportsRepository`/`ReportModel` were not touched — only the two
wrapping lines (`SingleChildScrollView(` / matching `)`) were added
around the pre-existing `Column`; no new package (`SingleChildScrollView`
is core Flutter, `package:flutter/material.dart`, already imported).

`dart format` was run on `trip_details_screen.dart` after applying the
fix, to fix indentation for the now-one-level-deeper `Column` and its
children. This reformatted some unrelated pre-existing lines in the same
file for whitespace/line-wrap only (confirmed via `git diff -w`, which
shows the same file with whitespace changes ignored — the "real" content
diff barely shrinks, meaning the bulk of this file's current diff is the
D51/D52-part-1/part-2 work from prior sessions, not new noise from this
fix; `dart format`'s own incidental reformatting here is on the order of
~30 lines). Flagging this rather than leaving it undisclosed: it's a
side effect of running the formatter on a file with prior
not-quite-canonical manual formatting, not a deliberate additional
change, and `flutter analyze`/`flutter test` (below) confirm it changed
no behavior.

## Files modified

- `lib/features/trip/presentation/trip_details_screen.dart` — only
  `_ReportFormSheetState.build()` changed structurally (the
  `SingleChildScrollView` wrapper); the rest of this session's diff on
  this file is `dart format`'s whitespace-only pass, as noted above.

No other file was touched by this task.

## flutter analyze output

Clean, no new issues. Raw output saved to
`docs/audit-trail/d52-part2-overflow-fix-analyze.txt`.

```
Analyzing coasterna_project...
No issues found! (ran in 1.5s)
```

## flutter test output

All 70 tests passed — unchanged from before this fix (no new tests
added; see below). Raw output saved to
`docs/audit-trail/d52-part2-overflow-fix-test.txt`.

```
00:00 +70: All tests passed!
```

**No new automated test was added for this bug, deliberately, not by
oversight.** This is a layout/rendering overflow that only manifests
under a real keyboard's `viewInsets` and a real modal route's bounded
height constraints — `flutter test`'s default headless widget-test
environment does not simulate an on-screen keyboard opening (there is no
real IME/`viewInsets` change to trigger), so no unit or widget test in
this suite can actually exercise the failure this fix addresses. Writing
one that merely asserts "no `RenderFlex` overflow error is thrown" while
never actually reproducing the keyboard-open + bounded-height conditions
would be a test that passes regardless of whether the fix is correct —
worse than no test, since it would look like coverage without providing
any. The real verification for this class of bug is the manual,
real-device, screen-recorded pass below.

## What still needs manual verification

- **Re-test "Other" with the keyboard open on a real device, screen
  recording, confirm zero overflow pixels and the field/submit button
  are still reachable.** This is the only verification that actually
  exercises this fix — repeat exactly the repro steps that surfaced the
  original bug (open "Report an issue," select "Other," tap the text
  field to bring up the keyboard) and confirm: no red/yellow
  overflow-banner stripes appear anywhere in the sheet, the "Describe the
  issue" text field is visible and typable, and the "Submit report"
  button can be scrolled to and tapped without dismissing the keyboard
  first.
- While doing that pass, also confirm the **keyboard-closed** appearance
  is unchanged from before this fix — open the sheet, do not select
  "Other," confirm there is no visible scrollbar, no extra blank space
  below the submit button, and the sheet's height/position looks
  identical to the pre-fix screen recording for that same state.
- Not otherwise re-verified this session: the actual submit flow, the
  five reason options, and the guest-tap → sign-in → "Signed in. Open the
  route again..." path from the D52 part 2 session — none of that logic
  was touched here, so it isn't expected to have changed, but it wasn't
  re-run either since this task's scope was the overflow fix only.

## Suggested commit message

```
fix(trip): stop _ReportFormSheet overflowing when the keyboard opens on "Other"

Root cause: the sheet's Column had no scrolling ancestor at all —
isScrollControlled:true only lifts the sheet's height cap, it doesn't
make content scrollable, and the bottom padding for viewInsets.bottom
was already correct. Once "Other"'s TextField added height and the
keyboard shrank available space, the Column's intrinsic height could
exceed the modal route's bounded max, and RenderFlex reported the
overflow. Wraps the Column in a SingleChildScrollView: it shrink-wraps
to the same size as before when content fits (verified from
_RenderSingleChildViewport's constraints.constrain(child.size) sizing
under the loose maxHeight the modal route provides), so nothing
changes with the keyboard closed, and only clamps-and-scrolls once
content is genuinely too tall for the available space.

Reproduced on a real device (screen-recorded) before this fix; the
underlying issue can't be exercised by flutter test's headless
environment (no real keyboard/viewInsets), so no new automated test
accompanies this change — verified manually instead.

Touches Gaith Swaidan's trip_details_screen.dart under decision D48
(Tariq's pre-granted permission to execute his own work via Claude
Code during finals).
```
