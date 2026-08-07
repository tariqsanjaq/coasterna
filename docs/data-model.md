# Coasterna — Firestore Data Model

### Ch.4.2.4 reference — replaces the classic ER Diagram

## Why NoSQL instead of an ER Diagram

This project stores data in Cloud Firestore, a NoSQL document database. There are no foreign keys and no joins. Data is denormalized instead — duplicated in the places it is read, so a search costs exactly one query. This section replaces the classic ER Diagram normally expected in Chapter 4.2.4, and documents the collections, the denormalization decisions behind them, the indexing implications, and the security rules that protect them.

## Collections

### `stops`

| Field | Type | Notes |
|---|---|---|
| name | string | |
| area | string | |
| latitude | number | |
| longitude | number | |
| isActive | boolean | false = excluded from search (e.g. Salt Bus Garages) |

### `routes`

| Field | Type | Notes |
|---|---|---|
| routeName | string | |
| operatorName | string | metadata only — NOT part of uniqueness |
| direction | string enum | OUTBOUND / RETURN |
| originStopId | string | reference to stops.id |
| originStopName | string | denormalized copy |
| destinationStopId | string | reference to stops.id |
| destinationStopName | string | denormalized copy |
| priceJD | number | |
| durationMinutes | number | |
| departureType | string enum | SCHEDULED / WHEN_FULL |
| firstDeparture / lastDeparture | string | |
| frequencyMinutes | number, nullable | null when departureType is WHEN_FULL |
| operatingDays | array\<string\> | |
| stops | array\<map\> | embedded waypoints: stopId (synthetic slug) + stopName + order — NOT searchable |
| isActive | boolean | |
| collectedBy / collectedOn | string / timestamp | field-data provenance |

### `admins`

| Field | Type | Notes |
|---|---|---|
| Document ID | — | equals the Firebase Auth UID exactly (confirmed Task #4) |
| email | string | |
| addedOn | timestamp | |

## Visual Overview

```mermaid
classDiagram
    class StopDocument {
      +string name
      +string area
      +double latitude
      +double longitude
      +bool isActive
    }
    class RouteDocument {
      +string routeName
      +string operatorName
      +string direction
      +string originStopId
      +string originStopName
      +string destinationStopId
      +string destinationStopName
      +double priceJD
      +int durationMinutes
      +string departureType
      +string firstDeparture
      +string lastDeparture
      +int frequencyMinutes "nullable — null if WHEN_FULL"
      +List~string~ operatingDays
      +List~RouteStop~ stops
      +bool isActive
      +string collectedBy
      +Timestamp collectedOn
    }
    class RouteStop {
      +string stopId
      +string stopName
      +int order
    }
    class AdminDocument {
      +string email
      +Timestamp addedOn
    }
    RouteDocument --> RouteStop : embeds array
    RouteDocument ..> StopDocument : denormalized copy of name
```

## Denormalization Rationale

Firestore has no joins, so the data model is designed around the app's single dominant read pattern — a student searching by origin (and optionally destination) — rather than around normalized entity relationships. `originStopName` and `destinationStopName` are stored directly inside each route document, in addition to their IDs, so the search results screen can render a complete result including stop names from one query against `routes`, with no second read against `stops` to resolve names. The waypoints inside the `stops` array are embedded as maps rather than kept as their own collection because they have no independent meaning outside the route they belong to and are never queried on their own — they are only ever read together with their parent route, so embedding avoids extra round trips for data that is always consumed as a unit. `operatorName` is stored as descriptive metadata only, and deliberately excluded from the uniqueness key: a route's identity is defined by `originStopId` + `destinationStopId` + `direction`, since that combination is what makes it a distinct physical trip a student can search for — which company happens to run it does not change that identity.

## Indexes

The current queries in `RouteRepository` use only `==` equality filters on a single collection, with no `orderBy`. `getAllStops()` filters `stops` on `isActive` alone. `searchRoutesByOrigin()` filters `routes` on `originStopId` and `isActive`, plus an optional third equality filter on `destinationStopId` when the student picks a "To" stop. Firestore automatically maintains single-field indexes for every field, and merges them to serve equality-only queries like these — so no composite index is required for the MVP search flow. A composite index would only become necessary if a future query added a range filter (for example, filtering by `priceJD`) or an `orderBy` on a field different from the equality filters — tracked as a Future Work item, not a current requirement.

## Security Rules

Public read access is open on `stops` and `routes` so the student search flow works without authentication. All writes on `stops` and `routes` require `isAdmin()`, checked via an `exists()` lookup against the caller's own document in `admins` — the caller is never trusted by a custom claim, only by document presence. The `admins` collection denies read and write unconditionally from the client, even for the admin who owns that document, since admin accounts are managed manually through the Firebase Console, never through the app. A default-deny catch-all closes every collection added later until rules are explicitly written for it.

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // Returns true only if the currently signed-in user's uid exists
    // as a document ID inside the admins collection. This does NOT
    // require a separate read permission on /admins — exists() checks
    // are evaluated by the rules engine itself, not by the client.
    function isAdmin() {
      return request.auth != null &&
        exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }

    // stops: every student (signed in or not) can read stop data to
    // search and browse. Only a signed-in admin can add, edit, or
    // delete a stop.
    match /stops/{stopId} {
      allow read: if true;
      allow write: if isAdmin();
    }

    // routes: every student (signed in or not) can read route data to
    // search and browse. Only a signed-in admin can add, edit, or
    // delete a route.
    match /routes/{routeId} {
      allow read: if true;
      allow write: if isAdmin();
    }

    // admins: nobody can read or write this collection from the app,
    // in either direction. Admin accounts are added manually through
    // the Firebase Console by Tariq or Abdallah, never through the app.
    match /admins/{adminId} {
      allow read: if false;
      allow write: if false;
    }

    // Any other collection not explicitly listed above is fully
    // locked by default. This protects any collection added later
    // (accidentally or intentionally) until rules for it are written
    // deliberately.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```