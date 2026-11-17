import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/clock.dart';
import '../../domain/entities/attendance_event.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/attendance_status.dart';
import '../../domain/entities/event_sync_status.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_local_data_source.dart';
import '../datasources/attendance_remote_data_source.dart';
import '../models/attendance_model.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDataSource remoteDataSource;
  final AttendanceLocalDataSource localDataSource;
  final AppConfig appConfig;
  final Clock clock;
  final Uuid uuid;

  AttendanceRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.appConfig,
    required this.clock,
    this.uuid = const Uuid(),
  });

  @override
  Future<Result<List<AttendanceRecord>>> getAttendanceHistory({
    String? month,
    bool forceRefresh = false,
  }) async {
    // 1. Try remote network first
    try {
      final remoteRecords = await remoteDataSource.getAttendanceHistory(month);
      // Cache in SQLite on success
      await localDataSource.cacheAttendanceRecords(remoteRecords);
      return Success(remoteRecords);
    } on AppError catch (networkError) {
      // 2. Fall back to local SQLite cache
      try {
        final cachedRecords = await localDataSource.getCachedAttendanceRecords(month: month);
        if (cachedRecords.isNotEmpty) {
          return Success(cachedRecords);
        }
      } catch (e) {
        return Failure(DatabaseError('Failed to read cached attendance history.', e));
      }
      return Failure(networkError);
    } catch (e) {
      final cachedRecords = await localDataSource.getCachedAttendanceRecords(month: month);
      if (cachedRecords.isNotEmpty) {
        return Success(cachedRecords);
      }
      return Failure(UnknownError('Failed to fetch attendance history.', e));
    }
  }

  @override
  Future<Result<AttendanceRecord?>> getTodayAttendance() async {
    final todayTz = clock.nowInZone(appConfig.companyTimezone);
    final todayStr = DateFormat('yyyy-MM-dd').format(todayTz);

    AttendanceRecord? baseRecord;

    // 1. Retrieve today's record from cache or remote
    try {
      baseRecord = await localDataSource.getCachedRecordForDate(todayStr);
    } catch (_) {}

    // 2. Overlay any locally stored pending/rejected events for today
    try {
      final localEvents = await localDataSource.getAllStoredEvents();
      AttendanceEvent? checkIn = baseRecord?.checkIn;
      AttendanceEvent? checkOut = baseRecord?.checkOut;

      for (final event in localEvents) {
        final eventDate = DateFormat('yyyy-MM-dd').format(
          clock.nowInZone(appConfig.companyTimezone).copyWith(
                year: event.timestamp.toUtc().year,
                month: event.timestamp.toUtc().month,
                day: event.timestamp.toUtc().day,
              ),
        );

        if (eventDate == todayStr) {
          if (event.isCheckIn) {
            checkIn = event;
          } else if (event.isCheckOut) {
            checkOut = event;
          }
        }
      }

      var status = AttendanceStatus.notCheckedIn;
      if (checkIn != null && checkOut == null) {
        status = AttendanceStatus.checkedIn;
      } else if (checkIn != null && checkOut != null) {
        status = AttendanceStatus.checkedOut;
      }

      final mergedRecord = AttendanceRecord(
        date: todayStr,
        checkIn: checkIn,
        checkOut: checkOut,
        status: status,
      );

      return Success(mergedRecord);
    } catch (e) {
      return Success(baseRecord);
    }
  }

  @override
  Future<Result<AttendanceEvent>> savePendingEventLocally({
    required String type,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) async {
    try {
      // Generate UUID at tap time (ensures idempotent retry identity)
      final eventId = uuid.v4();
      final nowUtc = clock.now().toUtc();

      final pendingEvent = AttendanceEventModel(
        eventId: eventId,
        type: type,
        timestamp: timestamp.toUtc(),
        latitude: latitude,
        longitude: longitude,
        sequence: 0, // Will be computed atomically in local data source
        status: EventSyncStatus.pending,
        rejectionReason: null,
        attempts: 0,
        createdAt: nowUtc,
      );

      final savedEvent = await localDataSource.insertPendingEvent(pendingEvent);
      return Success(savedEvent);
    } catch (e) {
      return Failure(DatabaseError('Failed to save attendance event locally.', e));
    }
  }

  @override
  Future<List<AttendanceEvent>> getPendingEvents() async {
    return await localDataSource.getPendingEvents();
  }

  @override
  Future<void> updateEventSyncStatus({
    required String eventId,
    required EventSyncStatus status,
    String? rejectionReason,
  }) async {
    await localDataSource.updateEventSyncStatus(
      eventId: eventId,
      status: status,
      rejectionReason: rejectionReason,
    );
  }

  @override
  Future<Result<AttendanceEvent>> syncEvent(AttendanceEvent event) async {
    try {
      await localDataSource.incrementEventAttempts(event.eventId);
      final syncedModel = await remoteDataSource.submitAttendanceEvent(event);
      await localDataSource.updateEventSyncStatus(
        eventId: event.eventId,
        status: EventSyncStatus.synced,
      );
      return Success(syncedModel);
    } on ConflictError catch (conflict) {
      // 409 Conflict: record already exists
      await localDataSource.updateEventSyncStatus(
        eventId: event.eventId,
        status: EventSyncStatus.rejected,
        rejectionReason: conflict.message,
      );
      return Failure(conflict);
    } on ValidationError catch (validation) {
      // 422: Geofence or timestamp validation error from server
      await localDataSource.updateEventSyncStatus(
        eventId: event.eventId,
        status: EventSyncStatus.rejected,
        rejectionReason: validation.message,
      );
      return Failure(validation);
    } on LocationError catch (locError) {
      await localDataSource.updateEventSyncStatus(
        eventId: event.eventId,
        status: EventSyncStatus.rejected,
        rejectionReason: locError.message,
      );
      return Failure(locError);
    } on AppError catch (transientError) {
      // Transient network/timeout/5xx: keep event pending for retry
      return Failure(transientError);
    } catch (e) {
      return Failure(UnknownError('Failed to synchronize attendance event.', e));
    }
  }
}
