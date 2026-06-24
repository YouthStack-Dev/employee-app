# Nodal QR Onboarding — Testing Guide

Feature: an employee scans the vehicle's RC-number QR (or types it) at a nodal
hub to mark themselves boarded.

- `GET  /api/v1/employee/nodal/assignment` → assigned hub (shown at top of scan screen)
- `POST /api/v1/employee/nodal/scan` `{ "vehicle_number": "KA01AB1234" }` → marks the booking `Ongoing`

Entry point: dashboard **active-ride card → QR icon** (`Scan QR to board`).

---

## 1. First-time setup (dev machine — Flutter SDK required)

```bash
flutter pub get          # pulls the new mobile_scanner dependency
flutter analyze          # static analysis — expect no new errors
flutter test             # runs the unit tests below
```

> The CI/dev machine must have the Flutter SDK. `mobile_scanner: ^5.2.3` was
> added to `pubspec.yaml`; `flutter pub get` resolves it. Android needs the
> `CAMERA` permission (added to `AndroidManifest.xml`) and iOS needs
> `NSCameraUsageDescription` (added to `Info.plist`).

## 2. Automated tests

```bash
flutter test test/nodal_models_test.dart
flutter test test/nodal_provider_test.dart
```

Covers:
- `VehicleNumber.normalize` / `isValid` (trim, uppercase, strip spaces, RC regex)
- `NodalPoint.fromJson` / `NodalScanResult.fromJson` (numeric-string coercion, nested point, missing fields)
- `NodalProvider`: rejects invalid input without hitting the API, normalizes before send, surfaces errors, populates assignment, clears errors. Uses an injected fake service (no network).

## 3. Manual end-to-end (device/emulator + live backend)

Prereqs: a logged-in employee with `is_active && is_app_active`, a **Nodal** shift
booking for **today** in status `Scheduled`, on a route whose vehicle has a known
`rc_number`, within 30 minutes of shift start.

| # | Step | Expected |
|---|------|----------|
| 1 | Open dashboard, tap the QR icon on the active-ride card | Nodal scan screen opens; "Your nodal hub" card loads from `GET /nodal/assignment` |
| 2 | Grant camera permission when prompted | Live camera viewport with scan frame appears |
| 3 | Deny camera permission (re-test) | Viewport shows "Camera permission denied — enter the vehicle number below"; manual entry still works |
| 4 | Scan the vehicle QR (encodes `rc_number`) | Spinner overlay → success sheet "Boarded successfully" with hub + `Booking #` + `ONGOING`; screen pops on Done |
| 5 | Manual: type `KA01AB1234`, tap Board ride | Same success flow |
| 6 | Manual: type `123` (invalid) | Inline error "doesn't look like a valid vehicle number"; **no** network call |
| 7 | Scan a vehicle with no active route today | Red snackbar "No active trip is running for this vehicle right now." (`ROUTE_NOT_FOUND`); scanner re-arms |
| 8 | Scan when >30 min past shift start | Red snackbar "boarding window has closed" (`BOARDING_WINDOW_CLOSED`) |
| 9 | Scan a non-nodal (Pickup) shift booking | Red snackbar "isn't a nodal-point shift" (`NOT_NODAL_SHIFT`) |
| 10 | Scan an unknown plate | "vehicle number isn't recognised" (`VEHICLE_NOT_FOUND`) |
| 11 | Back out mid-scan | Camera released (controller disposed); no crash; returning to dashboard works |
| 12 | Employee with no hub assigned | Hub card hidden (404 `ASSIGNMENT_NOT_FOUND` treated as "no hub", not a hard error) |

## 4. Error-code → copy map (in `nodal_service.dart`)

| Backend code | Status | User-facing message |
|---|---|---|
| `VEHICLE_NOT_FOUND` | 404 | "That vehicle number isn't recognised…" |
| `ROUTE_NOT_FOUND` | 404 | "No active trip is running for this vehicle right now." |
| `BOOKING_NOT_FOUND` | 404 | "You don't have a scheduled booking on this vehicle today." |
| `NOT_NODAL_SHIFT` | 400 | "This booking isn't a nodal-point shift…" |
| `BOARDING_WINDOW_CLOSED` | 400 | "The boarding window has closed…" |
| `APP_ACCESS_DISABLED` | 403 | "Your app access has been disabled…" |
| `ASSIGNMENT_NOT_FOUND` | 404 | "No nodal point has been assigned to you yet." |
