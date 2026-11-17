# REBS HRMS Mock HTTP API Server

A standalone Node.js Express server that simulates the REBS HRMS backend for local testing, offline synchronization verification, and repeatable scenario testing.

---

## 🚀 Quick Start

From the root project directory:
```bash
cd mock_server
npm install
npm start
```
By default, the server runs on `http://localhost:3000`.

To run with a custom port:
```bash
PORT=4000 npm start
```

---

## 🌐 Connecting via ngrok

To expose this server to physical test devices or Android emulators using your ngrok domain:
```bash
ngrok http 3000
```
Or with a static ngrok domain:
```bash
ngrok http --url=<your-static-domain>.ngrok-free.app 3000
```

---

## 📡 API Endpoints

### 1. Employee Profile & Office Geofence
* **Method:** `GET`
* **Endpoint:** `/employee/me`
* **Response:**
  ```json
  {
    "id": "EMP-1042",
    "name": "Alex Mercer",
    "department": "Engineering",
    "designation": "Senior Mobile Engineer",
    "officeLocation": {
      "latitude": 12.971598,
      "longitude": 77.594562,
      "radiusMeters": 200.0
    },
    "timezone": "Asia/Kolkata"
  }
  ```

### 2. Attendance History
* **Method:** `GET`
* **Endpoint:** `/attendance?month=YYYY-MM`
* **Response:** List of monthly attendance records sorted descending by date.

### 3. Submit Attendance Event (Check-In / Check-Out)
* **Method:** `POST`
* **Endpoint:** `/attendance/events`
* **Headers:** `Content-Type: application/json`
* **Payload:**
  ```json
  {
    "eventId": "c1f7a83d-6b54-4f0e-b87e-857e4bfa9c01",
    "type": "check_in",
    "timestamp": "2026-11-17T09:30:00.000Z",
    "latitude": 12.971598,
    "longitude": 77.594562
  }
  ```
* **Behaviors:**
  * **Idempotency:** Replaying the identical `eventId` returns the original stored result with `200 OK`.
  * **Geofence Enforcement:** Coordinates farther than 200m from the office are rejected with `422 Unprocessable Entity`.
  * **Check-In Rules:** Exactly one check-in allowed per calendar day. A second check-in with a different `eventId` returns `409 Conflict`.
  * **Check-Out Rules:** Check-out only allowed after a valid check-in for the same date; timestamp must be $\ge$ check-in timestamp.

### 4. Available Leave Balance
* **Method:** `GET`
* **Endpoint:** `/leave/balance`

### 5. Leave Requests
* **Method:** `GET`
* **Endpoint:** `/leave/requests`

### 6. Submit Leave Application
* **Method:** `POST`
* **Endpoint:** `/leave/requests`
* **Headers:** `Content-Type: application/json`
* **Payload:**
  ```json
  {
    "type": "Casual",
    "startDate": "2026-11-28",
    "endDate": "2026-11-30",
    "reason": "Attending annual technology conference"
  }
  ```
* **Validations:**
  * Start date cannot be before today in `Asia/Kolkata`.
  * End date cannot be before start date.
  * Reason must be $\ge$ 10 non-whitespace characters.
  * Requested days cannot exceed available balance.
  * Dates cannot overlap existing `Pending` or `Approved` leave requests.
  * Validation errors return `422` with a structured `fieldErrors` map.

---

## 🧪 Repeatable Testing Scenarios

Switch scenarios at runtime using the `POST /__admin/scenario` endpoint:

| Scenario Name | Description |
|---|---|
| `success` | Normal operational mode. All valid requests succeed immediately. |
| `slow` | Injects a 3.5-second network delay before responding. |
| `timeout` | Accepts and stores the event internally, but holds the HTTP response for 16 seconds (exceeding Flutter client's 10s timeout). Used to verify client retry idempotency! |
| `server_error` | Immediately returns `500 Internal Server Error`. |
| `duplicate_conflict`| On `POST /attendance/events`, returns `409 Conflict`. |
| `leave_rejection` | On `POST /leave/requests`, returns `422` with field-level rejection. |

### Reset Server State
To clear test data and return to initial seed state:
```bash
curl -X POST http://localhost:3000/__admin/reset
```

---

## 💻 Curl Examples

### Get Current Scenario:
```bash
curl http://localhost:3000/__admin/scenario
```

### Switch Scenario to 'slow':
```bash
curl -X POST http://localhost:3000/__admin/scenario \
  -H "Content-Type: application/json" \
  -d '{"name": "slow"}'
```

### Switch Scenario to 'timeout':
```bash
curl -X POST http://localhost:3000/__admin/scenario \
  -H "Content-Type: application/json" \
  -d '{"name": "timeout"}'
```

### Switch Scenario to 'server_error':
```bash
curl -X POST http://localhost:3000/__admin/scenario \
  -H "Content-Type: application/json" \
  -d '{"name": "server_error"}'
```

### Switch Scenario back to 'success':
```bash
curl -X POST http://localhost:3000/__admin/scenario \
  -H "Content-Type: application/json" \
  -d '{"name": "success"}'
```

### Test Valid Check-in (inside 200m geofence):
```bash
curl -X POST http://localhost:3000/attendance/events \
  -H "Content-Type: application/json" \
  -d '{
    "eventId": "test-uuid-001",
    "type": "check_in",
    "timestamp": "2026-11-17T09:30:00.000Z",
    "latitude": 12.971598,
    "longitude": 77.594562
  }'
```

### Test Idempotency (replay same eventId):
```bash
curl -X POST http://localhost:3000/attendance/events \
  -H "Content-Type: application/json" \
  -d '{
    "eventId": "test-uuid-001",
    "type": "check_in",
    "timestamp": "2026-11-17T09:30:00.000Z",
    "latitude": 12.971598,
    "longitude": 77.594562
  }'
```

### Test Geofence Violation (outside 200m radius):
```bash
curl -X POST http://localhost:3000/attendance/events \
  -H "Content-Type: application/json" \
  -d '{
    "eventId": "test-uuid-002",
    "type": "check_in",
    "timestamp": "2026-11-17T09:30:00.000Z",
    "latitude": 12.980000,
    "longitude": 77.600000
  }'
```

### Test Leave Submission (Validation Success):
```bash
curl -X POST http://localhost:3000/leave/requests \
  -H "Content-Type: application/json" \
  -d '{
    "type": "Casual",
    "startDate": "2026-11-28",
    "endDate": "2026-11-29",
    "reason": "Attending annual technical summit"
  }'
```

### Test Leave Rejection (Overlapping dates or short reason):
```bash
curl -X POST http://localhost:3000/leave/requests \
  -H "Content-Type: application/json" \
  -d '{
    "type": "Casual",
    "startDate": "2026-11-24",
    "endDate": "2026-11-25",
    "reason": "Short"
  }'
```
