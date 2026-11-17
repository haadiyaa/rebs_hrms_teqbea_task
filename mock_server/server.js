const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Log incoming requests
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.url}`);
  next();
});

// ==========================================
// CONFIGURATION & SEED DATA
// ==========================================
const DEFAULT_OFFICE = {
  latitude: 12.971598,
  longitude: 77.594562,
  radiusMeters: 200.0,
};

const COMPANY_TIMEZONE = 'Asia/Kolkata';

// Initial state generators
function getInitialEmployee() {
  return {
    id: 'EMP-1042',
    name: 'Alex Mercer',
    department: 'Engineering',
    designation: 'Senior Mobile Engineer',
    officeLocation: { ...DEFAULT_OFFICE },
    timezone: COMPANY_TIMEZONE,
  };
}

function getInitialLeaveBalance() {
  return {
    total: 18,
    used: 4,
    available: 14,
    breakdown: {
      casual: { total: 10, used: 2, available: 8 },
      sick: { total: 8, used: 2, available: 6 },
    },
  };
}

function getInitialLeaveRequests() {
  return [
    {
      id: 'LR-101',
      type: 'Casual',
      startDate: '2026-11-24',
      endDate: '2026-11-25',
      days: 2,
      reason: 'Family gathering and personal travel',
      status: 'Approved',
      createdAt: '2026-11-10T10:00:00.000Z',
    },
    {
      id: 'LR-100',
      type: 'Sick',
      startDate: '2026-11-05',
      endDate: '2026-11-06',
      days: 2,
      reason: 'Seasonal viral fever and medical recovery',
      status: 'Approved',
      createdAt: '2026-11-04T08:30:00.000Z',
    },
  ];
}

function getInitialAttendanceRecords() {
  return [
    {
      date: '2026-11-14',
      checkIn: {
        eventId: 'evt-seed-14-in',
        timestamp: '2026-11-14T09:12:00.000Z',
        latitude: 12.971600,
        longitude: 77.594570,
      },
      checkOut: {
        eventId: 'evt-seed-14-out',
        timestamp: '2026-11-14T17:45:00.000Z',
        latitude: 12.971610,
        longitude: 77.594580,
      },
      status: 'Checked Out',
    },
    {
      date: '2026-11-15',
      checkIn: {
        eventId: 'evt-seed-15-in',
        timestamp: '2026-11-15T09:05:00.000Z',
        latitude: 12.971590,
        longitude: 77.594560,
      },
      checkOut: {
        eventId: 'evt-seed-15-out',
        timestamp: '2026-11-15T18:02:00.000Z',
        latitude: 12.971605,
        longitude: 77.594565,
      },
      status: 'Checked Out',
    },
    {
      date: '2026-11-16',
      checkIn: {
        eventId: 'evt-seed-16-in',
        timestamp: '2026-11-16T09:20:00.000Z',
        latitude: 12.971598,
        longitude: 77.594562,
      },
      checkOut: {
        eventId: 'evt-seed-16-out',
        timestamp: '2026-11-16T17:50:00.000Z',
        latitude: 12.971600,
        longitude: 77.594564,
      },
      status: 'Checked Out',
    },
  ];
}

// In-Memory Database State
let state = {
  employee: getInitialEmployee(),
  leaveBalance: getInitialLeaveBalance(),
  leaveRequests: getInitialLeaveRequests(),
  attendanceRecords: getInitialAttendanceRecords(),
  // Map of eventId -> stored event payload for idempotency
  processedEvents: new Map(),
  // Current active scenario: 'success' | 'slow' | 'timeout' | 'server_error' | 'duplicate_conflict' | 'leave_rejection'
  scenario: 'success',
};

// Seed initial processedEvents map from initial attendance
for (const rec of state.attendanceRecords) {
  if (rec.checkIn) {
    state.processedEvents.set(rec.checkIn.eventId, {
      eventId: rec.checkIn.eventId,
      type: 'check_in',
      timestamp: rec.checkIn.timestamp,
      latitude: rec.checkIn.latitude,
      longitude: rec.checkIn.longitude,
      status: 'synced',
    });
  }
  if (rec.checkOut) {
    state.processedEvents.set(rec.checkOut.eventId, {
      eventId: rec.checkOut.eventId,
      type: 'check_out',
      timestamp: rec.checkOut.timestamp,
      latitude: rec.checkOut.latitude,
      longitude: rec.checkOut.longitude,
      status: 'synced',
    });
  }
}

// ==========================================
// UTILITY FUNCTIONS
// ==========================================

/**
 * Calculates Haversine distance between two coordinates in meters.
 */
function calculateHaversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth radius in meters
  const toRad = (x) => (x * Math.PI) / 180;
  const phi1 = toRad(lat1);
  const phi2 = toRad(lat2);
  const deltaPhi = toRad(lat2 - lat1);
  const deltaLambda = toRad(lon2 - lon1);

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

/**
 * Converts a date or ISO string to YYYY-MM-DD in the company timezone.
 */
function getCompanyDateString(isoDateStr) {
  const date = isoDateStr ? new Date(isoDateStr) : new Date();
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: COMPANY_TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(date);
}

// ==========================================
// SCENARIO MIDDLEWARE & CONTROLLER
// ==========================================
app.use((req, res, next) => {
  // Bypass admin endpoints from scenario interference
  if (req.path.startsWith('/__admin')) {
    return next();
  }

  // Scenario: server_error (Returns HTTP 500)
  if (state.scenario === 'server_error') {
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Simulated 500 internal server error triggered by scenario.',
    });
  }

  // Scenario: slow (Adds 3500ms delay)
  if (state.scenario === 'slow') {
    return setTimeout(next, 3500);
  }

  // Scenario: timeout (Stores event if POST /attendance/events, but delays response for 16s)
  // Client has 10s timeout, so it will time out client-side, testing idempotency on retry.
  if (state.scenario === 'timeout' && req.method === 'POST') {
    console.log('[Scenario: timeout] Simulating server acceptance with delayed client response...');
    // We let the request handler proceed after 16 seconds
    return setTimeout(next, 16000);
  }

  next();
});

// ==========================================
// ADMIN ENDPOINTS FOR SCENARIO TESTING
// ==========================================
app.get('/__admin/scenario', (req, res) => {
  res.json({ scenario: state.scenario });
});

app.post('/__admin/scenario', (req, res) => {
  const { name } = req.body;
  const validScenarios = [
    'success',
    'slow',
    'timeout',
    'server_error',
    'duplicate_conflict',
    'leave_rejection',
  ];

  if (!name || !validScenarios.includes(name)) {
    return res.status(400).json({
      error: 'Invalid scenario',
      allowedScenarios: validScenarios,
    });
  }

  state.scenario = name;
  console.log(`[Admin] Scenario switched to: ${name}`);
  res.json({
    scenario: state.scenario,
    message: `Scenario successfully set to '${name}'`,
  });
});

app.post('/__admin/reset', (req, res) => {
  state.employee = getInitialEmployee();
  state.leaveBalance = getInitialLeaveBalance();
  state.leaveRequests = getInitialLeaveRequests();
  state.attendanceRecords = getInitialAttendanceRecords();
  state.processedEvents = new Map();
  state.scenario = 'success';

  for (const rec of state.attendanceRecords) {
    if (rec.checkIn) {
      state.processedEvents.set(rec.checkIn.eventId, {
        eventId: rec.checkIn.eventId,
        type: 'check_in',
        timestamp: rec.checkIn.timestamp,
        latitude: rec.checkIn.latitude,
        longitude: rec.checkIn.longitude,
        status: 'synced',
      });
    }
    if (rec.checkOut) {
      state.processedEvents.set(rec.checkOut.eventId, {
        eventId: rec.checkOut.eventId,
        type: 'check_out',
        timestamp: rec.checkOut.timestamp,
        latitude: rec.checkOut.latitude,
        longitude: rec.checkOut.longitude,
        status: 'synced',
      });
    }
  }

  console.log('[Admin] Server state reset to default seeds.');
  res.json({ message: 'State successfully reset to factory defaults.' });
});

app.get('/__admin/state', (req, res) => {
  res.json({
    scenario: state.scenario,
    processedEventsCount: state.processedEvents.size,
    attendanceCount: state.attendanceRecords.length,
    leaveRequestsCount: state.leaveRequests.length,
    leaveBalance: state.leaveBalance,
  });
});

// ==========================================
// CORE BUSINESS ENDPOINTS
// ==========================================

// 1. Employee Profile & Office Geofence Config
app.get('/employee/me', (req, res) => {
  res.json(state.employee);
});

// 2. Attendance History (Filterable by month=YYYY-MM)
app.get('/attendance', (req, res) => {
  const { month } = req.query;
  let records = [...state.attendanceRecords];

  if (month) {
    records = records.filter((r) => r.date.startsWith(month));
  }

  // Sort descending by date
  records.sort((a, b) => b.date.localeCompare(a.date));

  res.json({
    month: month || 'all',
    records,
  });
});

// 3. Submit Attendance Event (Check-in / Check-out)
app.post('/attendance/events', (req, res) => {
  const { eventId, type, timestamp, latitude, longitude } = req.body;

  // Basic payload validation
  if (!eventId || !type || !timestamp || latitude === undefined || longitude === undefined) {
    return res.status(400).json({
      error: 'Bad Request',
      message: 'Missing required event fields: eventId, type, timestamp, latitude, longitude.',
    });
  }

  if (type !== 'check_in' && type !== 'check_out') {
    return res.status(400).json({
      error: 'Bad Request',
      message: "Event type must be either 'check_in' or 'check_out'.",
    });
  }

  // --- IDEMPOTENCY CHECK ---
  // If this exact eventId was already successfully stored, return the original record.
  if (state.processedEvents.has(eventId)) {
    console.log(`[Idempotency] Returning previously stored event for eventId: ${eventId}`);
    const existing = state.processedEvents.get(eventId);
    return res.status(200).json({
      ...existing,
      idempotentReplay: true,
      message: 'Event previously accepted and processed.',
    });
  }

  // --- SCENARIO CHECK: duplicate_conflict ---
  if (state.scenario === 'duplicate_conflict') {
    return res.status(409).json({
      error: 'Conflict',
      message: 'Simulated 409 conflict: Duplicate attendance record exists for this date.',
    });
  }

  // --- SERVER-SIDE VALIDATION 1: Geofence (200 meters) ---
  const distance = calculateHaversineDistance(
    latitude,
    longitude,
    state.employee.officeLocation.latitude,
    state.employee.officeLocation.longitude
  );

  if (distance > state.employee.officeLocation.radiusMeters) {
    return res.status(422).json({
      error: 'Geofence Violation',
      message: `Current location is ${distance.toFixed(1)}m from office, exceeding the ${state.employee.officeLocation.radiusMeters}m permitted radius.`,
      distanceMeters: Math.round(distance),
      allowedRadiusMeters: state.employee.officeLocation.radiusMeters,
    });
  }

  // --- SERVER-SIDE VALIDATION 2: Timestamp Sanity (No future events beyond 5 mins buffer) ---
  const eventTime = new Date(timestamp).getTime();
  const nowTime = Date.now();
  if (eventTime > nowTime + 5 * 60 * 1000) {
    return res.status(422).json({
      error: 'Timestamp Invalid',
      message: 'Event timestamp cannot be in the future.',
    });
  }

  // Determine calendar date in company timezone
  const eventDateStr = getCompanyDateString(timestamp);

  // Look for existing record on this day
  let dayRecord = state.attendanceRecords.find((r) => r.date === eventDateStr);

  if (type === 'check_in') {
    // Rule: Exactly one check-in per day
    if (dayRecord && dayRecord.checkIn) {
      return res.status(409).json({
        error: 'Conflict',
        message: `Employee has already checked in for ${eventDateStr} (existing check-in at ${dayRecord.checkIn.timestamp}).`,
      });
    }

    const eventPayload = {
      eventId,
      type: 'check_in',
      timestamp,
      latitude,
      longitude,
      status: 'synced',
    };

    if (!dayRecord) {
      dayRecord = {
        date: eventDateStr,
        checkIn: eventPayload,
        checkOut: null,
        status: 'Checked In',
      };
      state.attendanceRecords.push(dayRecord);
    } else {
      dayRecord.checkIn = eventPayload;
      dayRecord.status = 'Checked In';
    }

    state.processedEvents.set(eventId, eventPayload);

    return res.status(201).json({
      ...eventPayload,
      message: 'Check-in recorded successfully.',
    });
  }

  if (type === 'check_out') {
    // Rule: Check-out only permitted after check-in
    if (!dayRecord || !dayRecord.checkIn) {
      return res.status(409).json({
        error: 'Conflict',
        message: `Cannot check out: No check-in record found for ${eventDateStr}.`,
      });
    }

    // Rule: Check-out only once per day
    if (dayRecord.checkOut) {
      return res.status(409).json({
        error: 'Conflict',
        message: `Employee has already checked out for ${eventDateStr} at ${dayRecord.checkOut.timestamp}.`,
      });
    }

    // Rule: Check-out timestamp must be >= check-in timestamp
    const checkInTime = new Date(dayRecord.checkIn.timestamp).getTime();
    if (eventTime < checkInTime) {
      return res.status(422).json({
        error: 'Invalid Timestamp',
        message: 'Check-out time cannot be earlier than check-in time.',
      });
    }

    const eventPayload = {
      eventId,
      type: 'check_out',
      timestamp,
      latitude,
      longitude,
      status: 'synced',
    };

    dayRecord.checkOut = eventPayload;
    dayRecord.status = 'Checked Out';

    state.processedEvents.set(eventId, eventPayload);

    return res.status(201).json({
      ...eventPayload,
      message: 'Check-out recorded successfully.',
    });
  }
});

// 4. Available Leave Balance
app.get('/leave/balance', (req, res) => {
  res.json(state.leaveBalance);
});

// 5. Existing Leave Requests
app.get('/leave/requests', (req, res) => {
  // Sort descending by creation date
  const sorted = [...state.leaveRequests].sort(
    (a, b) => new Date(b.createdAt) - new Date(a.createdAt)
  );
  res.json({ requests: sorted });
});

// 6. Submit Leave Application
app.post('/leave/requests', (req, res) => {
  const { type, startDate, endDate, reason } = req.body;

  // --- SCENARIO CHECK: leave_rejection ---
  if (state.scenario === 'leave_rejection') {
    return res.status(422).json({
      error: 'Validation Failed',
      fieldErrors: {
        dates: 'Simulated 422: Department quota exceeded for selected leave period.',
      },
    });
  }

  const fieldErrors = {};

  // Field: type validation
  if (!type || (type !== 'Casual' && type !== 'Sick')) {
    fieldErrors.type = "Leave type must be either 'Casual' or 'Sick'.";
  }

  // Field: reason validation (>= 10 non-whitespace characters)
  const trimmedReason = (reason || '').trim();
  if (trimmedReason.length < 10) {
    fieldErrors.reason = 'Reason must contain at least 10 non-whitespace characters.';
  }

  // Field: date validation format
  if (!startDate || !/^\d{4}-\d{2}-\d{2}$/.test(startDate)) {
    fieldErrors.startDate = 'Start date is required in YYYY-MM-DD format.';
  }

  if (!endDate || !/^\d{4}-\d{2}-\d{2}$/.test(endDate)) {
    fieldErrors.endDate = 'End date is required in YYYY-MM-DD format.';
  }

  if (Object.keys(fieldErrors).length > 0) {
    return res.status(422).json({
      error: 'Validation Failed',
      fieldErrors,
    });
  }

  // Date logical validation
  const todayStr = getCompanyDateString();
  if (startDate < todayStr) {
    fieldErrors.startDate = `Start date cannot be before today (${todayStr}) in company timezone.`;
  }

  if (endDate < startDate) {
    fieldErrors.endDate = 'End date cannot be earlier than start date.';
  }

  // Calculate inclusive calendar days
  const startMs = new Date(`${startDate}T00:00:00Z`).getTime();
  const endMs = new Date(`${endDate}T00:00:00Z`).getTime();
  const diffDays = Math.round((endMs - startMs) / (1000 * 60 * 60 * 24)) + 1;

  // Balance validation
  const leaveCategory = (type || '').toLowerCase();
  const availableInCategory =
    state.leaveBalance.breakdown[leaveCategory]?.available ?? state.leaveBalance.available;

  if (diffDays > availableInCategory) {
    fieldErrors.days = `Requested ${diffDays} days exceeds available ${type} balance of ${availableInCategory} days.`;
  }

  // Overlap validation: cannot overlap with existing Pending or Approved requests
  const hasOverlap = state.leaveRequests.some((lr) => {
    if (lr.status !== 'Pending' && lr.status !== 'Approved') return false;
    // Overlaps if not (newEnd < existingStart or newStart > existingEnd)
    return !(endDate < lr.startDate || startDate > lr.endDate);
  });

  if (hasOverlap) {
    fieldErrors.dates = 'Requested dates overlap with an existing Pending or Approved leave request.';
  }

  if (Object.keys(fieldErrors).length > 0) {
    return res.status(422).json({
      error: 'Validation Failed',
      fieldErrors,
    });
  }

  // Create new Leave Request
  const newRequest = {
    id: `LR-${100 + state.leaveRequests.length + 1}`,
    type,
    startDate,
    endDate,
    days: diffDays,
    reason: trimmedReason,
    status: 'Pending',
    createdAt: new Date().toISOString(),
  };

  state.leaveRequests.push(newRequest);

  // Update balance used and available
  state.leaveBalance.used += diffDays;
  state.leaveBalance.available = Math.max(0, state.leaveBalance.available - diffDays);
  if (state.leaveBalance.breakdown[leaveCategory]) {
    state.leaveBalance.breakdown[leaveCategory].used += diffDays;
    state.leaveBalance.breakdown[leaveCategory].available = Math.max(
      0,
      state.leaveBalance.breakdown[leaveCategory].available - diffDays
    );
  }

  res.status(201).json(newRequest);
});

// Root welcome & health route
app.get('/', (req, res) => {
  res.json({
    name: 'REBS HRMS Mock API Server',
    status: 'online',
    scenario: state.scenario,
    companyTimezone: COMPANY_TIMEZONE,
    officeLocation: state.employee.officeLocation,
    adminEndpoints: {
      getScenario: 'GET /__admin/scenario',
      setScenario: 'POST /__admin/scenario',
      reset: 'POST /__admin/reset',
      state: 'GET /__admin/state',
    },
  });
});

app.listen(PORT, () => {
  console.log(`===============================================`);
  console.log(`🚀 REBS HRMS Mock Server listening on port ${PORT}`);
  console.log(`📍 Office Geofence: ${DEFAULT_OFFICE.latitude}, ${DEFAULT_OFFICE.longitude} (Radius: ${DEFAULT_OFFICE.radiusMeters}m)`);
  console.log(`🕒 Company Timezone: ${COMPANY_TIMEZONE}`);
  console.log(`⚙️  Active Scenario: ${state.scenario}`);
  console.log(`===============================================`);
});
