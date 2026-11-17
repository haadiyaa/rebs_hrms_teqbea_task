import 'dart:async';
import 'package:intl/intl.dart';
import 'package:rebs_hrms/core/errors/app_error.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/event_sync_status.dart';
import 'package:rebs_hrms/features/attendance/domain/repositories/attendance_repository.dart';
import '../domain/sync_engine.dart';
import '../domain/sync_result.dart';

/// Production Offline Synchronization Engine.
///
/// DESIGN & ARCHITECTURAL DECISIONS:
///
/// 1. STRICT FIFO ORDERING (by Sequence):
///    Pending events are ordered by their sequential integer ID assigned at creation time.
///    Why? Attendance is inherently causal: an employee must check in before checking out.
///    Attempting concurrent requests or out-of-order synchronization risks a check-out
///    reaching the server before its check-in, causing spurious 409 rejections.
///
/// 2. IDEMPOTENT EVENT IDENTITY (UUIDv4):
///    Each event is permanently stamped with a UUIDv4 at the exact instant the user taps
///    check-in/out. If a network timeout or connection drop occurs, the client retains
///    the event and retries with the IDENTICAL eventId. If the server already received and
///    processed the event before the connection dropped, the server's idempotency table
///    returns the original record (HTTP 200), allowing the client to safely mark it Synced.
///
/// 3. TRANSIENT FAILURE QUEUE HALTING:
///    On transient network failures (timeout, socket drop, HTTP 5xx), the queue halts
///    immediately and leaves remaining events in the 'pending' state.
///    Why? If event N fails due to connectivity, attempting event N+1 is guaranteed to
///    either fail or violate ordering dependencies.
///
/// 4. CONFLICT HANDLING & DEPENDENT REJECTION CASCADE:
///    If the server rejects a check-in with HTTP 409 (e.g. record already exists on server),
///    the check-in is marked 'rejected' with the server's reason. Crucially, the engine
///    scans ahead for any dependent check-out for that same day and cascades the rejection,
///    because a check-out cannot exist without an accepted check-in.
///
/// 5. CONCURRENCY MUTEX:
///    A boolean flag (`_isSyncing`) guards against concurrent sync invocations
///    from multiple triggers (e.g. network restored while user presses 'Sync Now').
class SyncEngineImpl implements SyncEngine {
  final AttendanceRepository attendanceRepository;

  bool _isSyncing = false;

  SyncEngineImpl({
    required this.attendanceRepository,
  });

  @override
  bool get isSyncing => _isSyncing;

  @override
  Future<int> getPendingCount() async {
    final pending = await attendanceRepository.getPendingEvents();
    return pending.length;
  }

  @override
  Future<SyncResult> synchronize({String trigger = 'manual'}) async {
    // CONCURRENCY GUARD (Mutex):
    // Drop execution if another sync routine is currently active.
    if (_isSyncing) {
      return SyncResult.inProgress();
    }

    _isSyncing = true;
    int syncedCount = 0;
    int rejectedCount = 0;

    try {
      // 1. Fetch pending events ordered strictly by sequence ascending (FIFO)
      final pendingEvents = await attendanceRepository.getPendingEvents();
      if (pendingEvents.isEmpty) {
        return const SyncResult();
      }

      final totalPending = pendingEvents.length;

      // Track rejected check-in dates to cascade rejections to dependent check-outs
      final Set<String> rejectedCheckInDates = {};

      for (int i = 0; i < pendingEvents.length; i++) {
        final event = pendingEvents[i];
        final eventDateStr = DateFormat('yyyy-MM-dd').format(event.timestamp.toUtc());

        // Check if a preceding check-in for this day was rejected
        if (event.isCheckOut && rejectedCheckInDates.contains(eventDateStr)) {
          // CASCADE DEPENDENT REJECTION:
          await attendanceRepository.updateEventSyncStatus(
            eventId: event.eventId,
            status: EventSyncStatus.rejected,
            rejectionReason:
                'Dependent check-in was rejected by server. Check-out cannot be processed.',
          );
          rejectedCount++;
          continue;
        }

        // Attempt remote synchronization
        final syncResult = await attendanceRepository.syncEvent(event);

        if (syncResult.isSuccess) {
          syncedCount++;
        } else {
          final error = syncResult.errorOrNull!;

          // CASE 1: PERMANENT REJECTION (Conflict 409, Geofence / Validation 422)
          if (error is ConflictError || error is ValidationError || error is LocationError) {
            rejectedCount++;
            if (event.isCheckIn) {
              rejectedCheckInDates.add(eventDateStr);
            }
            // Continue to next independent event in queue
            continue;
          }

          // CASE 2: TRANSIENT FAILURE (Timeout, No Network, Server 5xx)
          // STOP QUEUE IMMEDIATELY. Preserve remaining events as pending.
          return SyncResult(
            totalPending: totalPending,
            syncedCount: syncedCount,
            rejectedCount: rejectedCount,
            wasInterrupted: true,
            interruptionReason: error.message,
          );
        }
      }

      return SyncResult(
        totalPending: totalPending,
        syncedCount: syncedCount,
        rejectedCount: rejectedCount,
      );
    } finally {
      // Release concurrency mutex
      _isSyncing = false;
    }
  }
}
