# REBS HRMS — Mobile Engineering Assessment

A robust, offline-first mobile HRMS application built with **Flutter 3**, **Riverpod**, and **Clean Architecture** for the Teqbae Innovations and Solutions technical assessment.

---

## 🏗️ Architecture

The codebase follows a **Feature-First Clean Architecture** with strict unidirectional data flow:

```
lib/
├── core/                  # Infrastructure (ApiClient, AppConfig, SQLite, Clock)
└── features/
    ├── employee/          # Profile & designation
    ├── attendance/        # 200m GPS geofencing & live duration timer
    ├── sync/              # Offline-first FIFO sync engine & conflict resolution
    ├── leave/             # Leave requests, balance limits & overlap validations
    └── settings/          # Runtime API URL, geofence editing & location simulator
```

Each feature is divided into three isolated layers:
* **Domain**: Pure Dart business logic, repository contracts, and entities (no Flutter or third-party dependencies).
* **Data**: SQLite persistence (`sqflite`), remote data sources, models, and repository implementations.
* **Presentation**: Reactive UI powered by **Riverpod** (`Notifier` / `AsyncNotifier`), handling loading, error, empty, and offline states cleanly.

---

## ⚡ Quick Setup (2 Minutes)

### 1. Start the Mock Server
```bash
cd mock_server
npm install
node server.js
# Running on http://localhost:3000
```

### 2. Launch the Flutter App
```bash
# Android Emulator (uses 10.0.2.2 loopback):
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000

# iOS Simulator / macOS Desktop:
flutter run -d ios --dart-define=API_BASE_URL=http://localhost:3000
```

> **Testing on a Physical Phone via ngrok:**  
> Run `/Users/hadiya/.gemini/antigravity/bin/ngrok http 3000` on your computer. Open the app on your phone, go to **Settings**, tap the **`[🌐 Live ngrok Tunnel]`** preset button, and tap **Save**. The app automatically bypasses ngrok's browser warning header.

---

## ✅ Completed Features

* **Dashboard & Live Work Ticker**: Shows employee details (Alex Mercer, EMP-1042), today's status, leave balance summary, and a real-time ticking timer (`00:00:00`) that continues seamlessly across app restarts.
* **200m GPS Geofence Attendance**: Uses spherical geodesy (Haversine formula) to validate distance against company office coordinates (`12.971598, 77.594562`). Only employees within 200m can check in.
* **In-App Location Simulator (Reviewer Tool)**: Built directly into the **Settings** tab. Allows reviewers on real phones or emulators to simulate:
  * `At Office (0m)` — **Permitted**
  * `Inside (~150m)` — **Permitted**
  * `Boundary (200m)` — **Permitted**
  * `Outside (~280m)` — **Rejected**
  * Custom coordinates input
* **Offline-First Synchronization Engine (Highest Priority)**:
  * Check-ins and check-outs are immediately saved locally to SQLite with a client-generated UUIDv4 `eventId`.
  * **FIFO Queue**: Queued events replay in strict chronological order when network returns.
  * **Idempotency**: Server replays previously accepted `eventId`s without creating duplicate attendance rows.
  * **Failure Isolation**: Transient network errors halt the queue to preserve sequence; permanent rejections (409/422) mark the event as rejected and cascade to dependent check-outs safely.
  * Includes a manual **Sync Now** action and connectivity auto-triggers.
* **Leave Management**:
  * Apply for Casual or Sick leave with client-side & server-side validation.
  * Enforces: start date $\ge$ today, end date $\ge$ start date, reason $\ge$ 10 chars, balance checks, and overlap detection against pending/approved requests.
* **Interactive Settings & Scenario Testing**:
  * Switch between `Normal`, `Slow (3s)`, `Timeout (12s)`, `500 Error`, `409 Conflict`, and `Leave 422 Reject` directly in the UI.
  * Edit office coordinates and radius dynamically.

---

## 📌 Assumptions Made

1. **One Session Per Day**: Each employee has at most one check-in and one check-out per calendar day. Overnight shifts are outside current scope.
2. **Company Timezone**: All business day calculations and midnight cutoffs strictly use the company's configured timezone (`Asia/Kolkata` / IST).
3. **Dynamic Configuration**: The app loads office location and allowed radius dynamically from `GET /employee/me`, avoiding hardcoded coordinates.
4. **Calendar Leave Days**: All calendar days within a leave span count as leave days (as per assessment spec).
5. **Client UUID Ownership**: The client generates persistent UUIDv4 identifiers before any network attempt, ensuring guaranteed retry idempotency.

---

## ⚠️ Limitations & Production Considerations

* **Background OS Termination**: Background sync while the app is killed/terminated is intentionally excluded (requires native workmanager / background fetch).
* **Mock Server State**: The mock Node.js server maintains state in-memory during testing. Resetting or restarting the process clears stored sessions back to seed data.
* **Production GPS Security**: In a production enterprise app, client GPS checks provide instant UX feedback, but the production server must independently re-verify coordinates and employ Play Integrity / DeviceCheck to guard against rooted/jailbroken spoofing.

---

## 🧪 Automated Testing

All business rules, edge cases, and UI states are validated by **58 comprehensive automated tests**:

```bash
# Run test suite:
flutter test

# Run static code analysis:
flutter analyze
```

* `test/features/attendance/attendance_rules_test.dart` — 1 session/day rule, check-out without check-in rejection.
* `test/features/sync/sync_engine_test.dart` — UUID retry idempotency, FIFO order, network drop queue halting, 409 conflict cascading.
* `test/features/leave/leave_validator_test.dart` — Date sanity, balance exhaustion, overlapping request blocking.
* `test/core/location_simulator_test.dart` — Geodesy formulas for 0m, 150m, 200m, and 280m presets.
* `test/widget_test.dart` — Widget rendering for badges, banners, forms, and tab switches.

---

## ⏱️ Time Spent

* **Task Planning & System Design**: **~1.0 hr** (Yesterday, 5:30 PM – 6:30 PM)  
  Requirement breakdown, architecture mapping, and offline sync strategy.
* **Implementation, Testing & Refinements**: **Yesterday, 6:30 PM – Today, 1:00 PM**  
  * Geofence coordinate bug resolution & dynamic API configuration
  * Offline-first SQLite persistence, UUID idempotency & FIFO Sync Engine
  * Leave application logic, live validations & balance constraints
  * Reviewer GPS location simulator, settings screen & mock server scenarios
  * UI responsiveness fixes, 58 automated tests (100% green), and release packaging.

---

## 🤖 Tooling & AI Disclosure

As requested in the assessment guidelines:
* **AI Assistance**: AI tools (Google Antigravity) were utilized as an engineering accelerator for architectural brainstorming, boilerplate generation, and generating comprehensive test case suites.
* **Engineering Ownership**: All business logic, offline sync engine idempotency design, geofencing geodesy calculations, and Riverpod state management were designed, reviewed, debugged, and verified by the developer.

---

## 📦 Deliverables

* **Debug APK**: `deliverables/REBS_HRMS_Hadiya_Debug.apk`
* **Release APK**: `deliverables/REBS_HRMS_Hadiya_Release.apk`
* **Source Archive**: `deliverables/REBS_HRMS_Hadiya_Source.zip`
* **Demo Video**: `deliverables/REBS_HRMS_Hadiya_Demo.mp4`

