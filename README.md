# REBS HRMS — Mobile Application Assessment

A production-ready, offline-capable mobile HRMS application built with **Flutter 3**, **Riverpod**, and **Clean Architecture** (Feature-First) for the Teqbae Innovations and Solutions technical assessment.

---

## Quick Start (Run in 2 Minutes)

### 1. Start the Mock Server
```bash
cd mock_server
npm install
node server.js
# Running on http://localhost:3000
```

### 2. Run the Flutter App
```bash
# Android Emulator (uses 10.0.2.2 loopback):
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000

# iOS Simulator / macOS Desktop:
flutter run -d ios --dart-define=API_BASE_URL=http://localhost:3000
```

> **Note for Physical Devices & ngrok**: You can also point the app to an ngrok tunnel (e.g. `https://xxxx.ngrok-free.app`) in the **Settings** tab at runtime without rebuilding. The app automatically handles `ngrok-skip-browser-warning`.

---

## Key Features & Highlights

- **Employee Dashboard**: Live attendance status, real-time 1-second working duration counter, profile info, leave summary, and 5 latest attendance records.
- **200m GPS Geofence Attendance**: Haversine distance validation against the configured office coordinates (`12.971598, 77.594562`). Check-in is permitted only within 200 meters.
- **In-App Location Simulator (Debug Testing)**: Allows reviewers on emulators or outside the office to test geofencing immediately without external GPS spoofing tools.
- **Offline Storage & FIFO Sync Engine**:
  - Offline check-in/out actions are saved locally in SQLite with unique client-generated UUIDv4 `eventId`s.
  - Replays queued actions in **strict chronological sequence (FIFO)** when connectivity resumes.
  - **Idempotency**: Retrying with the same `eventId` avoids duplicate attendance on the server.
  - Halts the queue automatically on network timeouts or 5xx server errors to preserve action ordering.
- **Leave Management**: Casual and Sick leave application with live validations (date range, $\ge$ 10 char reason, balance limits, overlap detection) and server 422 error mapping.
- **Runtime Configuration & Scenario Testing**: Change backend URL, edit office geofence coordinates, and trigger mock server scenarios (`Slow`, `Timeout`, `500 Error`, `409 Conflict`, `422 Reject`) directly from the Settings screen.

---

## Reviewer Guide: Testing the Core Requirements

| Requirement | How to Test in the App |
|---|---|
| **1. 200m Geofence Validation** | 1. Go to **Settings** > Toggle **GPS Location Simulator** ON.<br>2. Select **At Office (0m)** $\rightarrow$ Go to Dashboard $\rightarrow$ Tap **Check In** (succeeds, live ticker starts).<br>3. Select **Outside (~280m)** $\rightarrow$ Tap **Check In** $\rightarrow$ Displays rejection: *"You are ~280m away from the office. Attendance is only permitted within 200m."* |
| **2. Dynamic Office Coordinates** | Go to **Settings** > **Office Geofence & Policies** > Tap **Edit** to update office latitude/longitude/radius dynamically. |
| **3. Offline Storage & Sync** | 1. Turn on Airplane mode on your device/emulator.<br>2. Tap **Check In** $\rightarrow$ Saved locally in SQLite; displays *"Saved offline. Will sync when online."* with a pending badge.<br>3. Turn off Airplane mode $\rightarrow$ Background connectivity listener detects internet and automatically syncs the event to the server. |
| **4. Idempotency & Conflict Handling** | Go to **Settings** > Tap **409 Conflict** under Mock Server Scenarios > Tap **Force Sync Queue Now** $\rightarrow$ Rejection is handled gracefully with cascading protection. |
| **5. Leave Date Overlap & Validation** | Go to **Leaves** tab > Tap **Apply for Leave** > Select dates overlapping an existing request or enter < 10 characters reason $\rightarrow$ Form rejects with clear inline field errors. |

---

## Tech Stack & Architecture

- **Framework**: Flutter 3 (Dart 3 null-safety)
- **Architecture**: Clean Architecture (Domain $\rightarrow$ Data $\rightarrow$ Presentation, Feature-First)
- **State Management**: `flutter_riverpod` (v2.6) Notifiers & AsyncNotifiers
- **Local Database**: `sqflite` (SQLite with ACID transaction support)
- **HTTP Client**: `http` encapsulated in `ApiClient` with typed error mapping
- **Location**: `geolocator` with injectable debug simulator fallback
- **Backend**: Node.js & Express.js mock REST API

---

## Automated Tests

58 unit, widget, and domain tests covering all business rules:
```bash
# Run all automated tests:
flutter test

# Run code analyzer:
flutter analyze
```

**Key Test Coverage**:
- `test/features/attendance/attendance_rules_test.dart`: Check-out without check-in rejection, 1 session/day rule.
- `test/features/sync/sync_engine_test.dart`: Idempotent UUID retry, FIFO ordering, transient error queue halting.
- `test/features/leave/leave_validator_test.dart`: Overlapping leave rejection, weekend exclusions, reason length.
- `test/core/location_simulator_test.dart`: Geodesy offset math for 0m, 150m, 200m boundary, and 280m outside.
- `test/widget_test.dart`: Visual state tests for banners, badges, dashboard, and settings tabs.

---

## Pre-Built APK Deliverables

- **Debug APK** (Includes in-app Location Simulator for reviewers):
  `build/app/outputs/flutter-apk/app-debug.apk`
- **Release APK** (Optimized, tree-shaken, simulator compiled out):
  `build/app/outputs/flutter-apk/app-release.apk`

---

## Production Security Notes

In a live production deployment:
1. **Server-Side Verification**: Client GPS validation provides immediate user feedback, but the backend must independently re-compute geofencing and enforce sequence ordering.
2. **Anti-Spoofing & Attestation**: Release builds enforce real hardware GPS (`kDebugMode` strips the simulator); production apps should also check `isMocked` flags and use Google Play Integrity / Apple DeviceCheck.
