# Coasterna (كوسترنا)

**A mobile application that digitizes the private coaster-bus network serving Al-Ahliyya Amman University.**

The private coaster buses that carry most AAU students to and from campus are almost entirely undocumented. Fares, first and last departure times, operating days, and the actual sequence of stops along a line live in drivers' heads and in student word-of-mouth — a student who has not travelled a line before has no way to look any of it up. Coasterna records that information and makes it searchable.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Screenshots](#screenshots)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Data Model](#data-model)
- [Security Rules](#security-rules)
- [Getting Started](#getting-started)
- [Running Tests](#running-tests)
- [Data Collection Methodology](#data-collection-methodology)
- [Testing & Verification](#testing--verification)
- [Known Limitations](#known-limitations)
- [Future Work](#future-work)
- [Team](#team)
- [Academic Context](#academic-context)

---

## Overview

A student selects a departure stop and, optionally, a destination. Coasterna returns the coaster routes serving that pair with the fare, the expected duration, the operating days, the full ordered stop timeline, and a link that opens the departure stop in Google Maps.

An administrator dashboard — the same Flutter codebase running as a web app — lets the team add, edit, and deactivate routes and stops without touching the database by hand, and review data-error reports submitted by students.

**Scope:** MVP covering AAU routes. The delivered build holds **5 routes** and **5 stops** across **3 operators**.

### Project Objectives

| # | Objective | Status |
|---|---|---|
| 1 | Digitize and organize route, stop, and pricing data for the private coaster networks serving AAU into a single structured database | Met |
| 2 | Provide a reliable search feature that finds routes by departure point, and optionally a destination | Met |
| 3 | Display detailed trip information for each route — stops, price, and a Google Maps link to the departure location | Met |

---

## Features

### Student

- **Route search** by origin stop, with an optional destination filter
- **Trip details** — full ordered stop timeline, fare in JD, duration, operating days, and departure pattern
- **Google Maps integration** — opens the departure stop from its stored coordinates; where a GPX track was recorded, the directions link follows the bus's real road rather than a straight line between stops
- **Live departure status** — a five-state badge computed from the route's schedule and the current time: countdown to the next bus, *Departs when full*, *No service today*, *First bus at HH:mm*, or *Service ended today*. Where the data cannot support a countdown, none is shown — an invented number would mislead a student waiting at a stop
- **Offline support** — searches are answered from the Firestore local cache with no network, and an explicit banner tells the student the data is cached rather than live
- **Browse all routes** without searching first
- **Recent searches**, saved on the device and scoped per user
- **Favorites** for signed-in students
- **Report an issue** — flags incorrect price, schedule, stop information, or a route that no longer operates
- **Guest access** — every student-facing feature except reporting works with no account at all

### Administrator

- **Route management** — add, edit, activate, deactivate, delete; waypoints reorderable with up/down controls
- **Stop management** — same operations, with name, area, and coordinates
- **Reports review** — open reports listed with route, reason, and reporter; resolve in one action
- **Deactivate over delete** — inactive routes and stops disappear from student search but stay in the database for record-keeping

---

## Screenshots

| Home | Search Results | Trip Details |
|:---:|:---:|:---:|
| Origin/destination selection with recent searches | Ordered soonest-departure-first, with direction and status badges | Stop timeline, fare, duration, operating days |

| Admin — Routes | Admin — Reports | Report an Issue |
|:---:|:---:|:---:|
| Data table with status pills and row menu | Route, reason, reporter, and status | Reason picker on Trip Details |

> Screenshots are in the project report (Section 4.3, Figures 12–25), captured from the running application on a real device and from Flutter Web in a desktop browser — not renderings of the design specification.

---

## Tech Stack

| Layer | Choice |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | Firebase — Backend-as-a-Service, no custom server |
| Database | Cloud Firestore (NoSQL, document-based) |
| Authentication | Firebase Authentication |
| State management | `setState` + `FutureBuilder` behind a repository layer |
| Authorization | Firestore Security Rules (server-side) |
| Design | Figma (UI specification), draw.io (UML diagrams) |

### Why this stack

Three alternatives were evaluated and rejected before this one: **Django + SQL**, **FastAPI + SQLAlchemy**, and **FastAPI + SQLite**. All three required building and hosting a custom backend server, which the team judged indefensible to build correctly within a single month with no prior production experience.

Firebase removes that tier entirely — no API to design, host, secure, or keep running — at the cost of pushing authorization into a separate rules language. That trade is covered in Section 6.2 of the report.

**No state-management package.** Each screen loads one collection once and rebuilds when it arrives, which is exactly the shape `FutureBuilder` was designed for. Adding Riverpod or BLoC would have introduced a vocabulary every team member had to learn before writing a screen, for a problem the framework already solves.

---

## Architecture

Feature-first, layered Flutter architecture (presentation / domain / data per feature), backed by Firebase. **There is no REST API layer** — Flutter talks to Cloud Firestore directly through the official SDK, behind a repository layer.

```
┌─────────────────────────────────────────────┐
│  Presentation — screens, widgets            │
│  HomePage · StopPicker · SearchResults      │
│  TripDetails · AdminDashboard · SignIn      │
└──────────────────┬──────────────────────────┘
                   │  typed Dart objects only
┌──────────────────▼──────────────────────────┐
│  Data — repository layer                    │
│  RouteRepository    → routes, stops         │
│  ReportsRepository  → reports               │
│  AuthRepository     → admins (auth check)   │
└──────────────────┬──────────────────────────┘
                   │  Firebase SDK
┌──────────────────▼──────────────────────────┐
│  Cloud Firestore  +  Firebase Auth          │
│  authorization enforced by Security Rules   │
└─────────────────────────────────────────────┘
```

**One rule holds the whole thing together:** no screen calls Firestore directly. Every read and write passes through a repository, and screens receive typed Dart objects rather than raw documents.

That rule paid for itself twice. When offline behaviour had to change, the change was made in one file and every screen inherited it. When the admin dashboard needed to see deactivated stops the student app must never see, the difference became two repository methods — `getAllStops` and `getAllStopsForAdmin` — instead of a condition repeated across several screens.

Reads return data **plus the origin of that data**:

```dart
Future<RepoResult<List<RouteModel>>> searchRoutesByOrigin(
  String originStopId, {
  String? destinationStopId,
});
```

`RepoResult` carries the rows together with `isFromCache`. This matters because Firestore does not throw when the device is offline — it answers the same `get()` from its local cache, and an empty cache returns an empty list with no error. Without that flag, *"no routes from this stop"* and *"no connection"* produce the same screen.

**One codebase, two apps.** On a phone it is the student app; in a desktop browser it is the administrator dashboard. A platform check in `main.dart` decides which one starts — no second project to keep in step, no shared code copied between them.

---

## Project Structure

```
lib/
  core/
    models/          RouteModel, StopModel, RouteStop, ReportModel
    theme/           colours, spacing, radii, text styles
    widgets/         widgets shared across features
    pending_intent.dart
  features/
    about/           about screen
    admin/           login, dashboard shell, route/stop/report management
    auth/            student sign-in, sign-up
    favorites/       favorite button, favorites screen
    profile/         settings/profile screen
    reports/         reports repository (data layer only)
    search/          home, stop picker, results, browse, repository
    splash/          splash screen
    trip/            trip details
  main.dart
test/
firestore.rules
```

Grouped by **feature**, not by layer. A developer adding a field to a route touches `core/models` and the admin form; a developer changing how results look touches `search` alone. Grouping by layer — all screens in one folder, all models in another — would have spread every change across the tree.

---

## Data Model

Four Firestore collections. Firestore has no tables, no foreign keys, and no joins, so a classic ER diagram does not apply — the document shape is the model.

### `stops`

| Field | Type | Notes |
|---|---|---|
| `name` | string | Display name shown to students |
| `area` | string | Used for grouping in the stop picker |
| `latitude` | double | For the Google Maps link |
| `longitude` | double | For the Google Maps link |
| `isActive` | boolean | Inactive stops are hidden from search |

### `routes`

One document per coaster line, **per direction** — a route to AAU and the same route back are two separate documents.

| Field | Type | Notes |
|---|---|---|
| `routeName` | string | Always uses "to", never a dash (frozen terminology) |
| `operatorName` | string | Informational only — not a unique identifier |
| `direction` | string | `OUTBOUND` or `RETURN` only |
| `originStopId` / `originStopName` | string | Reference + denormalized copy, avoids a second read |
| `destinationStopId` / `destinationStopName` | string | Same pattern |
| `priceJD` | double | Jordanian Dinar |
| `durationMinutes` | int64 | Estimated travel time |
| `departureType` | string | `SCHEDULED` or `WHEN_FULL` only |
| `firstDeparture` / `lastDeparture` | string | 24-hour `HH:mm` |
| `frequencyMinutes` | int64 \| null | Required if `SCHEDULED`; null if `WHEN_FULL` |
| `operatingDays` | array\<string\> | e.g. `["SUN","MON",...]` |
| `stops` | array\<map\> | Ordered intermediate stops: `{stopId, stopName, order}` |
| `isActive` | boolean | Inactive routes hidden but kept for record-keeping |
| `collectedBy` / `collectedOn` | string / timestamp | Field-data provenance |
| `pathPoints` | string \| null | `"lat,lng;lat,lng;…"` sampled from the recorded GPX track, steering the Maps directions link onto the bus's real road instead of a stop-to-stop straight line; null falls back to the single-pin origin link |

**Uniqueness rule** (enforced in application code, not by Firestore): a route is a duplicate if `originStopId` + `destinationStopId` + `direction` already exists — regardless of `operatorName`.

**Query pattern:** filtered with `where(originStopId == x)` and `where(isActive == true)`. Every filter is an equality check, so Firestore satisfies it with automatically-created single-field indexes — **no composite index to deploy by hand**. Sorting by soonest departure happens client-side in Dart, because it depends on the current time, which Firestore's query engine has no access to.

### `admins`

One document per admin account, used only inside Security Rules to check permissions. The app never writes it — admin documents are added manually through the Firebase Console.

### `reports`

Student-submitted data-error reports against a route.

| Field | Type | Notes |
|---|---|---|
| `routeId` | string | Reference to `routes.id` |
| `routeName` | string | Denormalized snapshot at report time, so the admin table needs no lookup even if the route is later renamed or deleted |
| `reason` | string enum | `PRICE_INCORRECT` / `SCHEDULE_INCORRECT` / `ROUTE_NOT_OPERATING` / `STOP_INFO_INCORRECT` / `OTHER` |
| `otherText` | string \| null | Only meaningful when `reason` is `OTHER` |
| `reportedByUid` | string | Firebase Auth uid; Security Rules require this to equal the caller's own uid on create |
| `reportedByName` | string \| null | Snapshot of the reporter's display name |
| `status` | string enum | `OPEN` / `RESOLVED`; rules require every new report to be created as `OPEN` |
| `createdAt` | timestamp | Submission time |

### On denormalization

Route documents store `originStopName` and `destinationStopName` as copies alongside the ids. Firestore has no joins — without the copies, every search result would need a second read just to display a name. With them, a search costs one query no matter how many routes come back.

The cost is that renaming a stop does not rename it on routes that already reference it. This is **accepted rather than hidden**: the stop edit form warns the administrator, and an automatic cascade is recorded as future work. Buying read speed with a duplication the writer must maintain is a normal document-database trade-off.

---

## Security Rules

Authorization is **not implemented in Dart**. Hiding a button in the interface prevents nothing, since a request can be sent without the interface at all.

```javascript
function isAdmin() {
  return request.auth != null &&
    exists(/databases/$(database)/documents/admins/$(request.auth.uid));
}
```

| Collection | Read | Write |
|---|---|---|
| `stops` | Public | `isAdmin()` |
| `routes` | Public | `isAdmin()` |
| `admins` | Own document only | Denied for everyone — Console-only provisioning |
| `reports` | `isAdmin()` | Create: signed-in, own uid, status `OPEN`. Update: `isAdmin()`. Delete: denied unconditionally |
| *anything else* | Denied | Denied — default-deny catch-all |

Reports are **never deletable** — they are kept as an audit trail, not a queue items are removed from.

---

## Getting Started

### Prerequisites

- Flutter SDK (stable channel) — [install guide](https://docs.flutter.dev/get-started/install)
- A Firebase project with **Cloud Firestore** and **Firebase Authentication** (Email/Password) enabled
- Firebase CLI and FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
npm install -g firebase-tools
```

### Setup

```bash
# 1. Clone
git clone https://github.com/tariqsanjaq/coasterna.git
cd coasterna

# 2. Install dependencies
flutter pub get

# 3. Connect your own Firebase project
#    (generates lib/firebase_options.dart)
flutterfire configure

# 4. Deploy the Security Rules
firebase deploy --only firestore:rules
```

> `lib/firebase_options.dart` is generated per-project and is **not** committed. Run `flutterfire configure` against your own Firebase project before the first launch.

### Running

```bash
# Student app — phone or emulator
flutter run

# Administrator dashboard — desktop browser
flutter run -d chrome
```

### Creating the first administrator

There is deliberately no admin sign-up path in the application. To grant admin access:

1. Create the account in **Firebase Console → Authentication → Users**
2. Copy its UID
3. In **Firestore**, create a document in the `admins` collection whose **document ID is that UID**

Security Rules block all writes to `admins` from the client in both directions, so this step can only be done through the Console.

---

## Running Tests

```bash
flutter test
```

**79 tests, 0 failures**, across five files:

| Test file | Cases |
|---|---:|
| `route_status_test.dart` | 33 |
| `report_model_test.dart` | 15 |
| `route_model_test.dart` | 14 |
| `favorites_repository_test.dart` | 7 |
| `profile_screen_test.dart` | 7 |
| `pending_intent_test.dart` | 3 |
| **Total** | **79** |

### Why these units

The logic that computes the next scheduled bus and orders search results is **time-sensitive** — its output changes with the current hour and day of week. Verifying it manually means waiting for the clock to reach the hour a case depends on; one black-box case could not be run until a Friday arrived.

Automation removes that dependency by turning the current time into a value the test supplies. All time-dependent tests use **fixed calendar dates** — `DateTime(2026, 8, 16, 12, 0)` for a known Sunday, `DateTime(2026, 8, 14, 12, 0)` for a known Friday — never `DateTime.now()`. A test that passes on Tuesday and fails on Friday is worse than no test at all, because it hides an intermittent failure behind an appearance of stability.

Test data uses the **object mother** pattern: a single `buildRoute()` helper fills every field with a safe default so each test overrides only the field it is actually testing.

---

## Data Collection Methodology

No public dataset exists for these routes. Every value in the database was collected in the field, and **each field records which method produced it**.

| Code | Method | Used for |
|---|---|---|
| **M1** | GPS recording of a full journey | Stop sequence, distance, duration |
| **M2** | Driver interview | Operator, operating hours, operating days |
| **M3** | Published official tariff | Fare |

Every route document carries `collectedBy` and `collectedOn`, so any figure shown in the application can be traced back to a specific survey rather than to an assumption.

---

## Testing & Verification

| Layer | Coverage | Result |
|---|---|---|
| **Black-box** | 19 test cases against requirements and screens | 18 passed, 1 blocked by field data |
| **White-box** | 23 cases against Security Rules source, run in the Firebase Console Rules Playground | 23 passed |
| **Unit** | 79 automated tests over time-sensitive scheduling logic and model serialization | 79 passed |

White-box cases were designed by reading `firestore.rules` directly, so each one exercises a specific named condition or evaluation path — not guessed behaviour from outside the app. This is the core difference from the black-box suite, which is designed from the requirement and the user-facing screen.

**A standing rule:** no test was ever modified to force a pass. A failing test reports a real disagreement between the code and the data model, and is reported rather than edited away.

---

## Known Limitations

Properties of the code as submitted, recorded honestly rather than omitted:

- `RouteModel.fromFirestore` reads every field with an unchecked cast — a malformed document throws at read time instead of failing gracefully
- `deleteStop` performs no referential-integrity check; the admin is shown the referencing-route count and warned in the dialog, so the check is manual
- Renaming a stop does not propagate to route documents holding copies of its name
- The interface is **English only**
- The direction label on a result card is derived from the destination stop name before falling back to the stored `direction` field, so a journey that neither begins nor ends at the university is labelled imprecisely
- Waypoint identifiers are unique only within their own route document — waypoints are drawn on the trip timeline but **cannot be selected as a departure point in search**
- `collectedBy` is free text, so the same surveyor can be recorded under more than one spelling
- The database holds 5 routes and 5 stops at submission — the lines surveyed during the project period, not the whole private network

---

## Future Work

| Item | Why it was deferred |
|---|---|
| **Cascading updates on stop rename** | Would write across the whole `routes` collection on a single rename — too large a change to introduce late in the project |
| **Referential integrity on delete** | Enforcing it in code, or in a Cloud Function, is the natural next step |
| **Searchable intermediate stops** | Requires promoting each waypoint to a real document in the `stops` collection |
| **Typed model parsing** | Checked reads with defaults, or a generated serializer, would remove a whole class of runtime failure |
| **Arabic and RTL support** | Straightforward in Flutter but affects every screen; outside the time available. Several stop names exist in the field *only* in Arabic |
| **Return-leg coverage** | A data-collection task rather than a software one |
| **Live tracking, in-app payment, driver ratings** | Excluded at the proposal stage — each depends on operator cooperation, a commercial problem before a technical one |

---

## Team

**Al-Ahliyya Amman University** · Faculty of Information Technology
Departments of Software Engineering and Computer Science

| Member | Responsibility as delivered |
|---|---|
| **Tariq Muwafaq Sanjaq** | Coordination; administrator dashboard including route and stop management forms; Firebase project setup; GPS field data collection; black-box test execution; report assembly |
| **Gaith Hani Ibrahim Swaidan** | Student-facing screens — home, stop picker, results, trip details, browse; offline banner; cache-aware repository result type |
| **Abdallah Abufara** | Data layer and repository; Firebase Authentication; Firestore Security Rules and their verification record; automated tests |
| **Abdalla Ahmad Odeh** | Documentation and diagrams |

**Supervisor:** Dr. Sumaya Al-Khatib

---

## Academic Context

Graduation Project #301, submitted September 2026 in partial fulfillment of the requirements for the degrees **Bachelor in Software Engineering** and **Bachelor in Computer Science** at Al-Ahliyya Amman University.

### Development process

Agile, with weekly iterations each ending in a working demoable increment — a **vertical slice**, not a finished layer. Two in-person sessions fixed the scope and divided the work; from then on the team met the supervisor every Saturday online, and each meeting was tied to something the team could show rather than to a written status update. By the second meeting a student could complete a search end to end against real Firestore data, which meant every later meeting reviewed a running application rather than a design.

Work was committed to a shared `dev` branch throughout — **79 commits** at submission — with each member committing their own work so individual contribution is visible in the history.

### A negative result worth recording

Requirement FR-07 called for the administrator to *add, update, and deactivate* both routes and stops. Testing found the **update** half had never been built — first for stops, later for routes. Both were subsequently implemented.

The lesson generalizes: *a requirement written as three verbs will be marked complete on the strength of one of them unless each verb is tested separately.*

---

<div align="center">

**Coasterna** — built for the students who ride these buses every day.

</div>
