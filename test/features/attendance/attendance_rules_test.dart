import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/errors/app_error.dart';
import 'package:rebs_hrms/core/utils/clock.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_event.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_record.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_status.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/event_sync_status.dart';
import 'package:rebs_hrms/features/attendance/domain/usecases/attendance_rules.dart';
import 'package:rebs_hrms/features/employee/domain/entities/office_location.dart';

void main() {
  group('AttendanceRules', () {
    const office = OfficeLocation(
      latitude: 12.971598,
      longitude: 77.594562,
      radiusMeters: 200.0,
    );

    late TestClock clock;
    final testTime = DateTime.utc(2026, 11, 17, 9, 30);

    setUp(() {
      clock = TestClock(testTime);
    });

    test('valid check-in inside geofence succeeds', () {
      final result = AttendanceRules.validateCheckIn(
        todayRecord: null,
        currentLatitude: office.latitude,
        currentLongitude: office.longitude,
        officeLocation: office,
        eventTimestamp: testTime,
        clock: clock,
      );

      expect(result.isSuccess, isTrue);
    });

    test('check-in outside 200m radius returns LocationError', () {
      final result = AttendanceRules.validateCheckIn(
        todayRecord: null,
        currentLatitude: 13.000000, // ~3.1 km away
        currentLongitude: 77.594562,
        officeLocation: office,
        eventTimestamp: testTime,
        clock: clock,
      );

      expect(result.isFailure, isTrue);
      final error = result.errorOrNull;
      expect(error, isA<LocationError>());
      final locError = error as LocationError;
      expect(locError.kind, equals(LocationErrorKind.outsideGeofence));
      expect(locError.distanceMeters, greaterThan(200.0));
      expect(locError.message, contains('away from the office'));
    });

    test('repeated check-in on the same day is rejected with ConflictError', () {
      final todayRecord = AttendanceRecord(
        date: '2026-11-17',
        checkIn: AttendanceEvent(
          eventId: 'evt-existing-in',
          type: 'check_in',
          timestamp: testTime.subtract(const Duration(hours: 1)),
          latitude: office.latitude,
          longitude: office.longitude,
          status: EventSyncStatus.synced,
          createdAt: testTime.subtract(const Duration(hours: 1)),
        ),
        status: AttendanceStatus.checkedIn,
      );

      final result = AttendanceRules.validateCheckIn(
        todayRecord: todayRecord,
        currentLatitude: office.latitude,
        currentLongitude: office.longitude,
        officeLocation: office,
        eventTimestamp: testTime,
        clock: clock,
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ConflictError>());
      expect(result.errorOrNull!.message, contains('already checked in'));
    });

    // REQUIRED TEST 1: Check-out without check-in is rejected
    test('Required Test 1: Check-out without check-in is rejected with ConflictError', () {
      final result = AttendanceRules.validateCheckOut(
        todayRecord: null, // No check-in today
        currentLatitude: office.latitude,
        currentLongitude: office.longitude,
        officeLocation: office,
        eventTimestamp: testTime,
        clock: clock,
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ConflictError>());
      expect(
        result.errorOrNull!.message,
        contains('Cannot check out: You have not checked in today yet'),
      );
    });

    test('valid check-out after check-in succeeds', () {
      final checkInTime = testTime.subtract(const Duration(hours: 8));
      final todayRecord = AttendanceRecord(
        date: '2026-11-17',
        checkIn: AttendanceEvent(
          eventId: 'evt-in',
          type: 'check_in',
          timestamp: checkInTime,
          latitude: office.latitude,
          longitude: office.longitude,
          status: EventSyncStatus.synced,
          createdAt: checkInTime,
        ),
        status: AttendanceStatus.checkedIn,
      );

      final result = AttendanceRules.validateCheckOut(
        todayRecord: todayRecord,
        currentLatitude: office.latitude,
        currentLongitude: office.longitude,
        officeLocation: office,
        eventTimestamp: testTime,
        clock: clock,
      );

      expect(result.isSuccess, isTrue);
    });

    test('repeated check-out on the same day is rejected with ConflictError', () {
      final checkInTime = testTime.subtract(const Duration(hours: 8));
      final checkOutTime = testTime.subtract(const Duration(minutes: 30));

      final todayRecord = AttendanceRecord(
        date: '2026-11-17',
        checkIn: AttendanceEvent(
          eventId: 'evt-in',
          type: 'check_in',
          timestamp: checkInTime,
          latitude: office.latitude,
          longitude: office.longitude,
          status: EventSyncStatus.synced,
          createdAt: checkInTime,
        ),
        checkOut: AttendanceEvent(
          eventId: 'evt-out',
          type: 'check_out',
          timestamp: checkOutTime,
          latitude: office.latitude,
          longitude: office.longitude,
          status: EventSyncStatus.synced,
          createdAt: checkOutTime,
        ),
        status: AttendanceStatus.checkedOut,
      );

      final result = AttendanceRules.validateCheckOut(
        todayRecord: todayRecord,
        currentLatitude: office.latitude,
        currentLongitude: office.longitude,
        officeLocation: office,
        eventTimestamp: testTime,
        clock: clock,
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ConflictError>());
      expect(result.errorOrNull!.message, contains('already checked out'));
    });

    test('check-out timestamp earlier than check-in is rejected with ValidationError', () {
      final checkInTime = testTime;
      final todayRecord = AttendanceRecord(
        date: '2026-11-17',
        checkIn: AttendanceEvent(
          eventId: 'evt-in',
          type: 'check_in',
          timestamp: checkInTime,
          latitude: office.latitude,
          longitude: office.longitude,
          status: EventSyncStatus.synced,
          createdAt: checkInTime,
        ),
        status: AttendanceStatus.checkedIn,
      );

      // Attempting check-out 1 hour before check-in
      final invalidCheckOutTime = checkInTime.subtract(const Duration(hours: 1));

      final result = AttendanceRules.validateCheckOut(
        todayRecord: todayRecord,
        currentLatitude: office.latitude,
        currentLongitude: office.longitude,
        officeLocation: office,
        eventTimestamp: invalidCheckOutTime,
        clock: clock,
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationError>());
    });
  });
}
