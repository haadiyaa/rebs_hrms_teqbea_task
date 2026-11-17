import '../../../../core/result/result.dart';
import '../entities/attendance_event.dart';
import '../entities/attendance_record.dart';
import '../entities/event_sync_status.dart';

/// Contract for attendance local persistence and remote synchronization.
abstract interface class AttendanceRepository {
  /// Fetches monthly attendance history (network-first with local cache fallback).
  Future<Result<List<AttendanceRecord>>> getAttendanceHistory({
    String? month,
    bool forceRefresh = false,
  });

  /// Retrieves today's attendance record combining synced and locally pending events.
  Future<Result<AttendanceRecord?>> getTodayAttendance();

  /// Creates and saves a new attendance event locally in SQLite within a transaction.
  /// Generates UUIDv4 eventId at tap time.
  Future<Result<AttendanceEvent>> savePendingEventLocally({
    required String type,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  });

  /// Retrieves all pending events waiting for sync, ordered strictly by sequence (FIFO).
  Future<List<AttendanceEvent>> getPendingEvents();

  /// Updates an event's sync status in SQLite (e.g. Synced or Rejected).
  Future<void> updateEventSyncStatus({
    required String eventId,
    required EventSyncStatus status,
    String? rejectionReason,
  });

  /// Synchronizes a specific pending event with the remote API.
  Future<Result<AttendanceEvent>> syncEvent(AttendanceEvent event);
}
