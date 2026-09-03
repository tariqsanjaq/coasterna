# Coasterna — Security Rules Verification

**Owner:** Abdallah Abufara · **Task #9** · **Location in repository:** `docs/security-rules-verification.md`

This file records the verification of the Firestore Security Rules using the Firebase
Console Rules Playground. Each case states the rule being exercised, the expected
outcome derived from reading the rule source, and the outcome actually observed.

The rules under test are the ones published in `firestore.rules` and reproduced in
`docs/data-model.md`.

**Report mapping**
- Chapter 6.2 — White-Box Testing: security rules verification
- Chapter 3.3 — NFR-05 (Security)
- Chapter 4.2.4 — NoSQL Data Model: security rules section

---

## Method

The Rules Playground evaluates a simulated request against the currently published
rules and reports whether the rules engine allows or denies it. It does not read or
write real data, so running these cases changes nothing in the database.

This is white-box testing: each case was designed after reading the rule source, to
exercise a specific branch of that source, rather than by guessing at behaviour from
outside.

**Identities used**

| Label | Meaning | Value used |
|---|---|---|
| ANON | No authentication | Authenticated toggle off |
| STUDENT | A signed-in student with no document in `admins` | uid: `SMBtoHsQG9fL1E5kSV8maNFujP63` |
| ADMIN | A signed-in administrator whose uid exists in `admins` | uid: `fx53osBbW7g4gAHN4TICcwWPwS62` |

---

## Test matrix

| ID | Rule branch exercised | Identity | Operation | Path | Expected | Actual | Result |
|---|---|---|---|---|---|---|---|
| SR-01 | `match /stops` allow read: if true | ANON | get | /stops/WooBhsKHE98E7npzXhya | Allowed | Allowed | Pass |
| SR-02 | `match /routes` allow read: if true | ANON | get | /routes/hmsUk723tjqyJEciyD3F | Allowed | Allowed | Pass |
| SR-03 | `match /routes` allow write: if isAdmin() | ANON | create | /routes/testDoc | Denied | Denied | Pass |
| SR-04 | `isAdmin()` returns false, no `admins` document | STUDENT | create | /routes/testDoc | Denied | Denied | Pass |
| SR-05 | `match /stops` allow write: if isAdmin() | STUDENT | update | /stops/WooBhsKHE98E7npzXhya | Denied | Denied | Pass |
| SR-06 | write covers delete | STUDENT | delete | /routes/hmsUk723tjqyJEciyD3F | Denied | Denied | Pass |
| SR-07 | `isAdmin()` returns true | ADMIN | create | /routes/testDoc | Allowed | Allowed | Pass |
| SR-08 | `isAdmin()` true, isActive toggle path | ADMIN | update | /routes/hmsUk723tjqyJEciyD3F | Allowed | Allowed | Pass |
| SR-09 | `match /admins` allow read: if false | ANON | get | /admins/fx53osBbW7g4gAHN4TICcwWPwS62 | Denied | Denied | Pass |
| SR-10 | `match /admins` denies even the owner | ADMIN | get | /admins/fx53osBbW7g4gAHN4TICcwWPwS62 | Denied | Denied | Pass |
| SR-11 | default-deny catch-all | ADMIN | create | /feedback/testDoc | Denied | Denied | Pass |
| SR-12 | `match /stops` allow write: if isAdmin() — update branch opened by the FR-07 Edit Stop form (added 2026-08-16) | ADMIN | update | /stops/WooBhsKHE98E7npzXhya | Allowed | Allowed | Pass |

---

## Notes on individual cases

**SR-03 and SR-04** are the two cases that matter most. They demonstrate that write
protection does not depend on the Flutter code hiding a button. A request arriving
from outside the application, with no administrator identity, is rejected by the
server itself.

**SR-10** is deliberate and may look surprising. An administrator cannot read their
own document in `admins`. The rules engine still evaluates `exists()` on that path
internally when resolving `isAdmin()`, because `exists()` is executed by the engine
rather than by the client, so admin checks continue to work while the collection stays
unreadable from any client. This is why SR-07 can succeed while SR-10 is denied.

**SR-11** proves the catch-all. Any collection added later is closed until rules are
written for it deliberately.

**SR-12** was added on 2026-08-16, one day after the initial verification pass.
The ADMIN update path on /stops did not exist in the application when SR-01
through SR-11 were tested: the Edit Stop form and its corresponding
updateStop() function in route_repository.dart were introduced afterward as
part of FR-07. The rule allow write: if isAdmin(); on /stops covers create,
update, and delete as a single branch, so the update path was already
protected by rules already verified through SR-05 (write denial for
STUDENT); SR-12 exercises that same branch directly for ADMIN once the
application actually started issuing update requests.

---

## Issues found

Record here any case whose actual outcome differed from the expected outcome. Do not
edit `firestore.rules` to make a case pass. Report the difference and leave the rules
untouched.

| ID | Expected | Actual | Reported to |
|---|---|---|---|
| — | — | — | No discrepancies found. All 12 cases matched their expected outcome. |

---

## Round 2 — Admin Dashboard Access Gate (2026-08-23)

**Context:** the Admin Dashboard had no check confirming a signed-in account was
actually an administrator — any valid Firebase Auth account (student or admin)
could sign in and reach the dashboard. Fixing this required the app itself to be
able to ask "is this uid in `admins`?", which the original rule (`allow read: if
false`) made impossible. The `admins` read rule was deliberately changed to allow
a signed-in user to read **only their own** admin document.

**⚠️ This intentionally changes the outcome of SR-10, above.** SR-10 recorded that
an ADMIN could not read their own `/admins` document — true under the rules
published on 2026-08-15. As of 2026-08-23, that same read is now Allowed by
design (see SR-13 below). SR-10 is retained unmodified as a historical record of
the previous ruleset and must not be read as describing current behaviour.

**Identity used in this round**

| Label | Meaning | Value used |
|---|---|---|
| OTHER | Any authenticated uid other than the document owner's — not a real registered account | `test123456789` |

| ID | Rule branch exercised | Identity | Operation | Path | Expected | Actual | Result |
|---|---|---|---|---|---|---|---|
| SR-13 | `match /admins` allow read: if request.auth.uid == adminId (self-read, added 2026-08-23) | ADMIN | get | /admins/fx53osBbW7g4gAHN4TICcwWPwS62 | Allowed | Allowed | Pass |
| SR-14 | self-read rule denies a non-matching uid | OTHER | get | /admins/fx53osBbW7g4gAHN4TICcwWPwS62 | Denied | Denied | Pass |
| SR-15 | self-read rule denies an unauthenticated request | ANON | get | /admins/fx53osBbW7g4gAHN4TICcwWPwS62 | Denied | Denied | Pass |
| SR-16 | `match /admins` allow write: if false — unchanged, still denies even the owner | ADMIN | create | /admins/fx53osBbW7g4gAHN4TICcwWPwS62 | Denied | Denied | Pass |

**Notes:** SR-14 was tested against an arbitrary non-owner uid rather than the
STUDENT identity defined in Round 1 — the rule's `==` comparison treats any
non-matching uid identically, so the result generalizes to STUDENT or any other
account. SR-16 confirms the deliberate self-read change did not weaken the
write protection on `admins` verified in SR-10's original context.

### Round 2 sign-off

| Item | Value |
|---|---|
| Verification performed by | Abdallah Abufara |
| Rule design & documentation | Abdallah Abufara |
| Date | 2026-08-23 |
| Rules version tested | published rules as of 2026-08-23 (admins self-read change) |
| Cases passed | 4 / 4 |
| Cases failed | 0 / 4 |

---

## Sign-off

| Item | Value                            |
|---|----------------------------------|
| Verification performed by | Abdallah Abufara                 |
| Date | 2026-08-18                       |
| Rules version tested | published rules as of 2026-08-15 |
| Cases passed | 12 / 12 |                         |
| Cases failed | 0 / 12 |                    |

---

## Round 3 — Reports collection (D52)

**Context:** D52 part 1 added a new `reports` collection with a Security
Rule requiring a signed-in student to create a report only under their
own uid and only with status `OPEN`, admin-only read and update via the
existing `isAdmin()`, and delete denied unconditionally. The eight cases
below (SR-17 through SR-23, plus SR-18b) were run manually via the
Firebase Console Rules Playground against the live `coasterna-fa940`
project, on 2026-09-03, after the rules were published — evidenced by
screenshots reviewed in chat, not attached as files in this repository.
All 8/8 passed; 0 rule changes were needed.

| Case | Identity | Operation | Location | Expected | Actual | Result |
|------|----------|-----------|----------|----------|--------|--------|
| SR-17 | STUDENT | create (own uid, status OPEN) | /reports/testReport1 | Allowed | Allowed | Pass |
| SR-18 | STUDENT | create (another uid) | /reports/testReport2 | Denied | Denied | Pass |
| SR-18b | STUDENT | create (own uid, status RESOLVED) | /reports/testReport2b | Denied | Denied | Pass |
| SR-19 | STUDENT | get (reports collection) | /reports/testReport1 | Denied | Denied | Pass |
| SR-20 | ADMIN | get | /reports/testReport1 | Allowed | Allowed | Pass |
| SR-21 | ADMIN | update (status → RESOLVED) | /reports/testReport1 | Allowed | Allowed | Pass |
| SR-22 | ANON | create | /reports/testReport3 | Denied | Denied | Pass |
| SR-23 | ADMIN | delete | /reports/testReport1 | Denied | Denied | Pass |

**Notes:** The full case definitions — document/update payloads, and the
rule branch each case targets — are recorded in
`docs/audit-trail/d52-part1-reports-backend.md` ("Manual Rules
Playground steps required"), written when the `reports` collection and
its rule were implemented; this table records only the verified
outcome, not a re-derivation of the cases. SR-18b is an extra case
beyond the six scenarios originally requested for D52 — it isolates the
`create` rule's second condition (`status == 'OPEN'`) from its first
(`reportedByUid == request.auth.uid`, already isolated by SR-18),
matching the SR-numbering the case definitions already used.

### Round 3 sign-off

| Item | Value |
|---|---|
| Verification performed by | Tariq Sanjaq |
| Rule design & documentation | Claude Code (D52 part 1) |
| Date | 2026-09-03 |
| Rules version tested | published rules as of 2026-09-03 (reports collection, D52) |
| Cases passed | 8 / 8 |
| Cases failed | 0 / 8 |
