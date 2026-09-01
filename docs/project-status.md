# Project Status — Coasterna

_Last updated: 2026-08-31 (session: full code audit + CLAUDE.md restructure)_

This file holds **current, time-sensitive** project state: test results, open
findings, pending decisions. `CLAUDE.md` holds the stable architectural rules and
does not change often. **Refresh this file every session that changes project
state — do not let CLAUDE.md accumulate status content again.**

---

## Testing status — verify before trusting this section

**Still unverified.** The last confirmed state of `test/widget_test.dart` was the
default Flutter counter-app smoke test (looking for a `+` icon), which does not
match real app content and would fail `flutter test`. This has **not** been
re-checked since the app moved past scaffold state, and the 2026-08-31 code audit
did not run `flutter test` or report on this file specifically (it only confirmed
`flutter analyze` returns "No issues found!" and reviewed `test/route_status_test.dart`
for dead code). **Run `flutter test` and report the actual output before touching
test files or trusting this section further.**

---

## Latest audit

`docs/audit-trail/full-code-audit-2026-08-31.md` — 14-point full code audit,
requested by Tariq, executed by Claude Code, reviewed with Claude (chat) same day.
Result: 9 of 14 items clean with no violations. 5 items produced the findings below.

## Open findings needing a decision (from the 2026-08-31 audit)

| Finding | Where | Decision needed |
|---|---|---|
| **Model serialization mismatch** — `RouteModel`/`StopModel` implement `fromFirestore`/`toFirestore` (Firestore-typed: `DocumentSnapshot`, `Timestamp`), not `fromJson`/`toJson` as CLAUDE.md's rule states. Not unit-testable without a real Firestore object. | `route_model.dart:137,178`; `stop_model.dart:23,43` | Fix the models to add real `fromJson`/`toJson`, **or** update the CLAUDE.md rule to document `fromFirestore`/`toFirestore` as the accepted pattern. **Not decided.** |
| **Git authorship** — 3 of 61 commits attributed to non-real names (`unknown` ×2, `zOx_k` ×1), though the emails match real teammates (Abdallah, Tariq). Will distort a `git shortlog -sn --all`-based Division of Work count. | commits `0a8016a`, `f18174d`, `37eab2c` | Confirm the real owner for the report's contribution table. Decide whether to amend commit metadata (risky — another history rewrite) or hand-correct the report table instead. **Not decided.** |
| **Empty `domain/` folders** exist (`.gitkeep` only, no code) in 4 features, contradicting CLAUDE.md's "no domain layer" line. Harmless — not real code, doesn't affect the app. | `admin/`, `auth/`, `search/`, `trip/` `domain/` dirs | Low priority — delete the stray folders for cleanliness, or leave them. **Not decided, not urgent.** |
| `home_page.dart` "recent searches" load has no loading indicator, no error handling for malformed stored JSON, and no explicit empty-state message. | `home_page.dart:48-57` | Minor code-quality gap. Decide whether to fix before submission or accept as low-risk (local `SharedPreferences` read only). |
| `auth_repository.dart` doc comment claims its `catch` handles "offline" — inconsistent with the project's own documented Firestore behavior (`get()` never throws when offline; it returns cached/empty data instead). Not a functional bug — the method fails closed either way. | `auth_repository.dart:76-89` | Cosmetic doc-comment fix only. Low priority. |

**Note:** the audit's 14 items did not re-test the Search-behavior gap or the
Maps gap documented in CLAUDE.md — those remain exactly as last verified in the
Task #11 audit, not re-confirmed on 2026-08-31.

---

## Pending scope decisions

- **Student sign-in feature unlock** (supervisor request) — still pending, no
  go-ahead given. Candidate: favorites (needs a 4th Firestore collection,
  reopens the closed 3-collection decision) vs. a device-local version (works
  per-device only). See CLAUDE.md → Auth section for the standing "do not build
  without go-ahead" rule.

---

## Next steps

1. Get the 5 audit findings above turned into team decisions and logged with the
   next sequential D-number in the decision log (last known: past D36 — confirm
   the current number before assigning).
2. Run `flutter test`, paste the actual output, update the Testing status
   section above.
3. Continue the finalization checklist tracked separately (report items,
   TOC update, etc. — not duplicated here).
