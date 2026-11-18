import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/data_providers.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/clock.dart';
import '../../../employee/domain/entities/office_location.dart';
import '../../../employee/domain/repositories/employee_repository.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/attendance_status.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../domain/usecases/attendance_rules.dart';
import '../../../../core/services/location_simulator.dart';
import 'attendance_state.dart';

/// Provider for the LocationService instance.
final locationServiceProvider = Provider<LocationService>((ref) {
  final config = ref.watch(appConfigProvider);
  final simulator = ref.watch(locationSimulatorProvider);
  return GeolocatorLocationService(
    appConfig: config,
    simulatorState: simulator,
  );
});

/// Riverpod Notifier managing attendance check-in/out and dashboard attendance state.
final attendanceNotifierProvider =
    NotifierProvider<AttendanceNotifier, AttendanceState>(
  AttendanceNotifier.new,
);

class AttendanceNotifier extends Notifier<AttendanceState> {
  AttendanceRepository get _attendanceRepository =>
      ref.read(attendanceRepositoryProvider);
  EmployeeRepository get _employeeRepository =>
      ref.read(employeeRepositoryProvider);
  LocationService get _locationService => ref.read(locationServiceProvider);
  AppConfig get _appConfig => ref.read(appConfigProvider);
  Clock get _clock => ref.read(clockProvider);

  @override
  AttendanceState build() {
    // Initial fetch on provider registration
    Future.microtask(() => loadDashboardAttendance());
    return const AttendanceState(isLoading: true);
  }

  /// Loads today's attendance record and latest 5 attendance history entries.
  Future<void> loadDashboardAttendance({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, clearError: true, clearUserMessage: true);

    // 1. Fetch today's record (merged from server cache + local pending events)
    final todayResult = await _attendanceRepository.getTodayAttendance();
    final todayRec = todayResult.dataOrNull;

    // 2. Fetch monthly history
    final historyResult = await _attendanceRepository.getAttendanceHistory(
      forceRefresh: forceRefresh,
    );

    final historyList = historyResult.dataOrNull ?? [];
    // Take latest 5 attendance records as requested by assignment specifications
    final latest5 = historyList.take(5).toList();

    state = state.copyWith(
      todayRecord: todayRec,
      recentHistory: latest5,
      isLoading: false,
    );
  }

  /// Executes the employee Check-In flow.
  /// Guarded against double-taps by [isActionInProgress].
  Future<bool> checkIn() async {
    // DOUBLE-TAP PREVENTION GUARD:
    // If an action is already in flight, immediately reject subsequent taps.
    if (state.isActionInProgress) {
      return false;
    }

    state = state.copyWith(
      isActionInProgress: true,
      clearError: true,
      clearUserMessage: true,
    );

    try {
      // 1. Get office geofence parameters
      final officeLocation = await _resolveOfficeLocation();

      // 2. Acquire current GPS coordinates
      final locationResult = await _locationService.getCurrentPosition();
      if (locationResult.isFailure) {
        final locError = locationResult.errorOrNull!;
        state = state.copyWith(
          isActionInProgress: false,
          error: locError,
          userMessage: locError.message,
        );
        return false;
      }

      final coords = locationResult.dataOrNull!;
      final eventTimestamp = _clock.now();

      // 3. Domain validation (Geofence, one check-in per day, timestamp sanity)
      final validationResult = AttendanceRules.validateCheckIn(
        todayRecord: state.todayRecord,
        currentLatitude: coords.latitude,
        currentLongitude: coords.longitude,
        officeLocation: officeLocation,
        eventTimestamp: eventTimestamp,
        clock: _clock,
      );

      if (validationResult.isFailure) {
        final validationError = validationResult.errorOrNull!;
        state = state.copyWith(
          isActionInProgress: false,
          error: validationError,
          userMessage: validationError.message,
        );
        return false;
      }

      // 4. Save pending event locally in SQLite within a transaction
      // Generates a UUIDv4 eventId at tap time for retry idempotency
      final saveResult = await _attendanceRepository.savePendingEventLocally(
        type: 'check_in',
        latitude: coords.latitude,
        longitude: coords.longitude,
        timestamp: eventTimestamp,
      );

      if (saveResult.isFailure) {
        final dbError = saveResult.errorOrNull!;
        state = state.copyWith(
          isActionInProgress: false,
          error: dbError,
          userMessage: dbError.message,
        );
        return false;
      }

      final pendingEvent = saveResult.dataOrNull!;

      // 5. Optimistically update today's record in UI (shows Checked In - Pending Sync)
      final optimisticRecord = (state.todayRecord ??
              AttendanceRecord(date: pendingEvent.createdAt.toIso8601String()))
          .copyWith(
        checkIn: pendingEvent,
        status: AttendanceStatus.checkedIn,
      );

      state = state.copyWith(
        todayRecord: optimisticRecord,
        userMessage: 'Check-in recorded locally. Synchronizing...',
      );

      // 6. Attempt immediate synchronization if online
      final syncResult = await _attendanceRepository.syncEvent(pendingEvent);
      if (syncResult.isSuccess) {
        final syncedEvent = syncResult.dataOrNull!;
        state = state.copyWith(
          todayRecord: state.todayRecord?.copyWith(checkIn: syncedEvent),
          userMessage: 'Check-in synced successfully with server.',
          isActionInProgress: false,
        );
      } else {
        // If offline / timeout / server error, keep as Pending Sync
        final error = syncResult.errorOrNull!;
        if (error is ConflictError) {
          state = state.copyWith(
            userMessage: 'Server conflict: ${error.message}',
            isActionInProgress: false,
          );
        } else {
          state = state.copyWith(
            userMessage: 'Saved offline. Event will sync when connection is available.',
            isActionInProgress: false,
          );
        }
      }

      // Refresh today's record from repository to ensure consistency
      await _refreshTodayRecord();
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionInProgress: false,
        error: UnknownError('Check-in failed unexpectedly: $e'),
        userMessage: 'An unexpected error occurred during check-in.',
      );
      return false;
    }
  }

  /// Executes the employee Check-Out flow.
  /// Guarded against double-taps by [isActionInProgress].
  Future<bool> checkOut() async {
    // DOUBLE-TAP PREVENTION GUARD:
    if (state.isActionInProgress) {
      return false;
    }

    state = state.copyWith(
      isActionInProgress: true,
      clearError: true,
      clearUserMessage: true,
    );

    try {
      // 1. Get office geofence parameters
      final officeLocation = await _resolveOfficeLocation();

      // 2. Acquire current GPS coordinates
      final locationResult = await _locationService.getCurrentPosition();
      if (locationResult.isFailure) {
        final locError = locationResult.errorOrNull!;
        state = state.copyWith(
          isActionInProgress: false,
          error: locError,
          userMessage: locError.message,
        );
        return false;
      }

      final coords = locationResult.dataOrNull!;
      final eventTimestamp = _clock.now();

      // 3. Domain validation (Geofence, check-out only after check-in, check-out >= check-in)
      final validationResult = AttendanceRules.validateCheckOut(
        todayRecord: state.todayRecord,
        currentLatitude: coords.latitude,
        currentLongitude: coords.longitude,
        officeLocation: officeLocation,
        eventTimestamp: eventTimestamp,
        clock: _clock,
      );

      if (validationResult.isFailure) {
        final validationError = validationResult.errorOrNull!;
        state = state.copyWith(
          isActionInProgress: false,
          error: validationError,
          userMessage: validationError.message,
        );
        return false;
      }

      // 4. Save pending event locally in SQLite within a transaction
      final saveResult = await _attendanceRepository.savePendingEventLocally(
        type: 'check_out',
        latitude: coords.latitude,
        longitude: coords.longitude,
        timestamp: eventTimestamp,
      );

      if (saveResult.isFailure) {
        final dbError = saveResult.errorOrNull!;
        state = state.copyWith(
          isActionInProgress: false,
          error: dbError,
          userMessage: dbError.message,
        );
        return false;
      }

      final pendingEvent = saveResult.dataOrNull!;

      // 5. Optimistically update today's record in UI (shows Checked Out - Pending Sync)
      final optimisticRecord = state.todayRecord!.copyWith(
        checkOut: pendingEvent,
        status: AttendanceStatus.checkedOut,
      );

      state = state.copyWith(
        todayRecord: optimisticRecord,
        userMessage: 'Check-out recorded locally. Synchronizing...',
      );

      // 6. Attempt immediate synchronization if online
      final syncResult = await _attendanceRepository.syncEvent(pendingEvent);
      if (syncResult.isSuccess) {
        final syncedEvent = syncResult.dataOrNull!;
        state = state.copyWith(
          todayRecord: state.todayRecord?.copyWith(checkOut: syncedEvent),
          userMessage: 'Check-out synced successfully with server.',
          isActionInProgress: false,
        );
      } else {
        final error = syncResult.errorOrNull!;
        if (error is ConflictError) {
          state = state.copyWith(
            userMessage: 'Server conflict: ${error.message}',
            isActionInProgress: false,
          );
        } else {
          state = state.copyWith(
            userMessage: 'Saved offline. Event will sync when connection is available.',
            isActionInProgress: false,
          );
        }
      }

      await _refreshTodayRecord();
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionInProgress: false,
        error: UnknownError('Check-out failed unexpectedly: $e'),
        userMessage: 'An unexpected error occurred during check-out.',
      );
      return false;
    }
  }

  /// Opens the device App Settings screen for permanently denied location permissions.
  Future<bool> openAppSettings() async {
    return await _locationService.openAppSettings();
  }

  /// Dismisses any active user toast / banner message.
  void dismissUserMessage() {
    state = state.copyWith(clearUserMessage: true, clearError: true);
  }

  Future<void> _refreshTodayRecord() async {
    final todayResult = await _attendanceRepository.getTodayAttendance();
    if (todayResult.isSuccess) {
      state = state.copyWith(todayRecord: todayResult.dataOrNull);
    }
  }

  Future<OfficeLocation> _resolveOfficeLocation() async {
    try {
      final empResult = await _employeeRepository.getEmployeeProfile();
      if (empResult.isSuccess) {
        return empResult.dataOrNull!.officeLocation;
      }
    } catch (_) {}

    // Fall back to AppConfig defaults if employee profile is not yet loaded
    return OfficeLocation(
      latitude: _appConfig.officeLatitude,
      longitude: _appConfig.officeLongitude,
      radiusMeters: _appConfig.officeRadiusMeters,
    );
  }
}
