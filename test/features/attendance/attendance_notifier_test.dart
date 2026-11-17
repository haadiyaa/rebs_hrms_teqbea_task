import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs_hrms/core/config/app_config.dart';
import 'package:rebs_hrms/core/errors/app_error.dart';
import 'package:rebs_hrms/core/providers/core_providers.dart';
import 'package:rebs_hrms/core/providers/data_providers.dart';
import 'package:rebs_hrms/core/result/result.dart';
import 'package:rebs_hrms/core/services/location_service.dart';
import 'package:rebs_hrms/core/utils/clock.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_event.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_status.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/event_sync_status.dart';
import 'package:rebs_hrms/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:rebs_hrms/features/attendance/presentation/providers/attendance_notifier.dart';
import 'package:rebs_hrms/features/employee/domain/entities/employee.dart';
import 'package:rebs_hrms/features/employee/domain/entities/office_location.dart';
import 'package:rebs_hrms/features/employee/domain/repositories/employee_repository.dart';

class MockAttendanceRepository extends Mock implements AttendanceRepository {}

class MockEmployeeRepository extends Mock implements EmployeeRepository {}

class MockLocationService extends Mock implements LocationService {}

class MockAppConfigNotifier extends AppConfigNotifier {
  final AppConfig _mockConfig;
  MockAppConfigNotifier(this._mockConfig);

  @override
  AppConfig build() => _mockConfig;
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      AttendanceEvent(
        eventId: 'fb-event',
        type: 'check_in',
        timestamp: DateTime.now(),
        latitude: 0,
        longitude: 0,
        createdAt: DateTime.now(),
      ),
    );
  });

  group('AttendanceNotifier & Location Integration', () {
    late MockAttendanceRepository mockAttendanceRepo;
    late MockEmployeeRepository mockEmployeeRepo;
    late MockLocationService mockLocationService;
    late TestClock testClock;
    late ProviderContainer container;

    const office = OfficeLocation(
      latitude: 12.971598,
      longitude: 77.594562,
      radiusMeters: 200.0,
    );

    const employee = Employee(
      id: 'EMP-1042',
      name: 'Alex Mercer',
      department: 'Engineering',
      designation: 'Senior Engineer',
      officeLocation: office,
    );

    final currentTime = DateTime.utc(2026, 11, 17, 9, 30);

    setUp(() {
      mockAttendanceRepo = MockAttendanceRepository();
      mockEmployeeRepo = MockEmployeeRepository();
      mockLocationService = MockLocationService();
      testClock = TestClock(currentTime);

      when(() => mockEmployeeRepo.getEmployeeProfile(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => const Success(employee));

      when(() => mockAttendanceRepo.getTodayAttendance())
          .thenAnswer((_) async => const Success(null));

      when(() => mockAttendanceRepo.getAttendanceHistory(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => const Success([]));

      container = ProviderContainer(
        overrides: [
          attendanceRepositoryProvider.overrideWithValue(mockAttendanceRepo),
          employeeRepositoryProvider.overrideWithValue(mockEmployeeRepo),
          locationServiceProvider.overrideWithValue(mockLocationService),
          clockProvider.overrideWithValue(testClock),
          appConfigProvider.overrideWith(
            () => MockAppConfigNotifier(
              const AppConfig(
                apiBaseUrl: 'http://localhost:3000',
                officeLatitude: 12.971598,
                officeLongitude: 77.594562,
                officeRadiusMeters: 200.0,
              ),
            ),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('checkIn succeeds inside 200m geofence and saves pending event locally', () async {
      when(() => mockLocationService.getCurrentPosition()).thenAnswer(
        (_) async => const Success(
          LocationCoordinates(latitude: 12.971598, longitude: 77.594562),
        ),
      );

      final createdEvent = AttendanceEvent(
        eventId: 'test-uuid-in',
        type: 'check_in',
        timestamp: currentTime,
        latitude: 12.971598,
        longitude: 77.594562,
        sequence: 1,
        status: EventSyncStatus.pending,
        createdAt: currentTime,
      );

      when(
        () => mockAttendanceRepo.savePendingEventLocally(
          type: 'check_in',
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          timestamp: any(named: 'timestamp'),
        ),
      ).thenAnswer((_) async => Success(createdEvent));

      when(() => mockAttendanceRepo.syncEvent(any())).thenAnswer(
        (_) async => Success(
          createdEvent.copyWith(status: EventSyncStatus.synced),
        ),
      );

      final notifier = container.read(attendanceNotifierProvider.notifier);
      final success = await notifier.checkIn();

      expect(success, isTrue);
      final state = container.read(attendanceNotifierProvider);
      expect(state.todayStatus, equals(AttendanceStatus.checkedIn));
      expect(state.isActionInProgress, isFalse);
    });

    test('checkIn displays meaningful message and rejects when outside 200m geofence', () async {
      // 5 km away from office
      when(() => mockLocationService.getCurrentPosition()).thenAnswer(
        (_) async => const Success(
          LocationCoordinates(latitude: 13.010000, longitude: 77.594562),
        ),
      );

      final notifier = container.read(attendanceNotifierProvider.notifier);
      final success = await notifier.checkIn();

      expect(success, isFalse);
      final state = container.read(attendanceNotifierProvider);
      expect(state.error, isA<LocationError>());
      expect(state.userMessage, contains('away from the office'));
      expect(state.userMessage, contains('Attendance is only permitted within 200m'));

      // Verify no event was saved locally
      verifyNever(
        () => mockAttendanceRepo.savePendingEventLocally(
          type: any(named: 'type'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          timestamp: any(named: 'timestamp'),
        ),
      );
    });

    test('offline check-in preserves pending status with offline user message', () async {
      when(() => mockLocationService.getCurrentPosition()).thenAnswer(
        (_) async => const Success(
          LocationCoordinates(latitude: 12.971598, longitude: 77.594562),
        ),
      );

      final createdEvent = AttendanceEvent(
        eventId: 'test-uuid-offline',
        type: 'check_in',
        timestamp: currentTime,
        latitude: 12.971598,
        longitude: 77.594562,
        sequence: 1,
        status: EventSyncStatus.pending,
        createdAt: currentTime,
      );

      when(
        () => mockAttendanceRepo.savePendingEventLocally(
          type: 'check_in',
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          timestamp: any(named: 'timestamp'),
        ),
      ).thenAnswer((_) async => Success(createdEvent));

      // Network sync fails with NetworkError
      when(() => mockAttendanceRepo.syncEvent(any()))
          .thenAnswer((_) async => const Failure(NetworkError()));

      final notifier = container.read(attendanceNotifierProvider.notifier);
      final success = await notifier.checkIn();

      expect(success, isTrue);
      final state = container.read(attendanceNotifierProvider);
      expect(state.todayStatus, equals(AttendanceStatus.checkedIn));
      expect(state.userMessage, contains('Saved offline'));
      expect(state.isActionInProgress, isFalse);
    });
  });
}
