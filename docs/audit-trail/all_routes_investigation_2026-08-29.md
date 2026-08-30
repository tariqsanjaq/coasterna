# "All routes" screen — Step 1 investigation (2026-08-29)

## 1. Screen file
`lib/features/search/presentation/all_routes_screen.dart` — `AllRoutesScreen`,
`StatefulWidget`, AppBar title `'All routes'` (line 87). Reached from
`home_page.dart` "Browse all routes".

## 2. Route card widget
**Inline**, not a separate widget file. Built directly inside
`ListView.separated`'s `itemBuilder` in `_buildBody()` (an `InkWell` wrapping a
`Container`). Nothing else in the repo renders it, so rewriting it is local.

## 3. Route model — `lib/core/models/route_model.dart` (`RouteModel`)
Exact fields:

| field | type |
|---|---|
| `id` | `String` |
| `routeName` | `String` |
| `operatorName` | `String` |
| `direction` | `RouteDirection` (`outbound` / `returnTrip`) |
| `originStopId` | `String` |
| `originStopName` | `String` |
| `destinationStopId` | `String` |
| `destinationStopName` | `String` |
| `priceJD` | `double` |
| `durationMinutes` | `int` |
| `departureType` | `DepartureType` (`scheduled` / `whenFull`) |
| `firstDeparture` | `String` ("HH:MM") |
| `lastDeparture` | `String` ("HH:MM") |
| `frequencyMinutes` | `int?` (nullable) |
| `operatingDays` | `List<String>` |
| `stops` | `List<RouteStop>` (`stopId`, `stopName`, `order`) |
| `isActive` | `bool` |
| `collectedBy` | `String` |
| `collectedOn` | `DateTime` |

**Result: NO blocker.** Duration (`durationMinutes`), frequency
(`frequencyMinutes`), and operator name (`operatorName`) all already exist and
are already parsed in `RouteModel.fromFirestore`. No model or repository change
is needed, so Abdallah's sign-off is not required for this task.

The real-time status text is not one field — it is computed from
`operatingDays` + `departureType` + `firstDeparture` / `lastDeparture` +
`frequencyMinutes` by the badge helpers listed below.

## 4. Search Results status badge + price style — reusable as-is
- Widget: `RouteStatusBadge` in
  `lib/features/search/presentation/widgets/route_status_badge.dart`.
  Public, takes only `RouteModel`, resolves all five states internally:
  `No service today` (red), `Departs when full` (amber), `First bus at HH:MM`
  (green), `Service ended today` (amber), `Next bus in about N min` (green),
  and the **D41 fallback** — scheduled + inside hours + `frequencyMinutes ==
  null` renders the `HH:MM - HH:MM` operating-hours range instead of an empty
  card (`_BadgeStyle.operatingHours`).
  Free functions also exported from that file: `parseTimeOnDay`,
  `formatTimeLabel`, `routeRunsToday`, `minutesUntilNextDeparture`,
  `routeDepartureRank`.
- Price / duration text style: `AppTextStyles.monoData(fontSize: 13.5)`
  (IBM Plex Mono via `google_fonts`), used in
  `search_results_placeholder.dart` `_buildRouteCard` and in
  `trip_details_screen.dart:383` (`_DetailRow`).

## 5. Where the navy AppBar comes from — **LOCAL override, not the theme**
`appTheme` in `lib/core/theme/app_theme.dart` defines **no `appBarTheme` at
all**. Every AppBar colour in the app is set per screen:

| screen | AppBar `backgroundColor` |
|---|---|
| `all_routes_screen.dart:85` | `AppColors.primary` (navy) ← this task |
| `home_page.dart:212` | `AppColors.primary` (navy) |
| `student_signup_screen.dart:77` | `AppColors.primary` (navy) |
| `search_results_placeholder.dart:86` | `AppColors.background` (plain) |
| `trip_details_screen.dart:144` | `AppColors.background` (plain) |
| `about_page.dart:12` | `AppColors.background` (plain) |

**Result: NO blocker.** Changing the "All routes" AppBar touches only this one
screen; `app_theme.dart` is not modified and no other screen is affected.
Home and Sign up keep their navy bars — out of scope for this task.

## Conclusion
Both stop conditions are clear. Proceeding to Step 2 with no model,
repository, or theme changes.
