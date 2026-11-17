import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs_hrms/core/config/app_config.dart';
import 'package:rebs_hrms/core/database/database_helper.dart';
import 'package:rebs_hrms/core/errors/app_error.dart';
import 'package:rebs_hrms/core/utils/clock.dart';
import 'package:rebs_hrms/features/attendance/data/datasources/attendance_local_data_source.dart';
import 'package:rebs_hrms/features/attendance/data/datasources/attendance_remote_data_source.dart';
import 'package:rebs_hrms/features/attendance/data/models/attendance_model.dart';
import 'package:rebs_hrms/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_status.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/event_sync_status.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockAttendanceRemoteDataSource extends Mock
    implements AttendanceRemoteDataSource {}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AttendanceRepositoryImpl', () {
    late String dbName;
    late DatabaseHelper dbHelper;
    late AttendanceLocalDataSource localDataSource;
    late MockAttendanceRemoteDataSource mockRemoteDataSource;
    late AttendanceRepositoryImpl repository;
    late TestClock clock;
    const appConfig = AppConfig(apiBaseUrl: 'http://localhost:3000');

    final testTime = DateTime.utc(2026, 11, 17, 9, 30);

    setUp(() async {
      dbName = 'test_repo_db_${DateTime.now().microsecondsSinceEpoch}.db';
      dbHelper = DatabaseHelper(
        databaseFactory: databaseFactoryFfi,
        dbName: dbName,
      );
      localDataSource = AttendanceLocalDataSourceImpl(dbHelper);
      mockRemoteDataSource = MockAttendanceRemoteDataSource();
      clock = TestClock(testTime);

      repository = AttendanceRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        localDataSource: localDataSource,
        appConfig: appConfig,
        clock: clock,
      );
    });

    tearDown(() async {
      await dbHelper.close();
      try {
        final databasesPath = await databaseFactoryFfi.getDatabasesPath();
        await databaseFactoryFfi.deleteDatabase('$databasesPath/$dbName');
      } catch (_) {}
    });

    test('getAttendanceHistory fetches from network and updates local SQLite cache', () async {
      final remoteRecords = [
        AttendanceRecordModel(
          date: '2026-11-16',
          checkIn: AttendanceEventModel(
            eventId: 'remote-1',
            type: 'check_in',
            timestamp: DateTime.utc(2026, 11, 16, 9, 0),
            latitude: 12.971598,
            longitude: 77.594562,
            status: EventSyncStatus.synced,
            createdAt: DateTime.utc(2026, 11, 16, 9, 0),
          ),
          status: AttendanceStatus.checkedIn,
        ),
      ];

      when(() => mockRemoteDataSource.getAttendanceHistory(any()))
          .thenAnswer((_) async => remoteRecords);

      final result = await repository.getAttendanceHistory(month: '2026-11');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!.length, equals(1));
      expect(result.dataOrNull!.first.date, equals('2026-11-16'));

      // Verify records were saved to local SQLite cache
      final cached = await localDataSource.getCachedAttendanceRecords(month: '2026-11');
      expect(cached.length, equals(1));
      expect(cached.first.date, equals('2026-11-16'));
    });

    test('getAttendanceHistory falls back to local SQLite cache when offline', () async {
      // Seed local cache directly
      await localDataSource.cacheAttendanceRecords([
        const AttendanceRecordModel(
          date: '2026-11-15',
          status: AttendanceStatus.checkedOut,
        ),
      ]);

      // Network throws NetworkError
      when(() => mockRemoteDataSource.getAttendanceHistory(any()))
          .thenThrow(const NetworkError('No internet connection'));

      final result = await repository.getAttendanceHistory(month: '2026-11');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!.length, equals(1));
      expect(result.dataOrNull!.first.date, equals('2026-11-15'));
    });

    test('savePendingEventLocally generates UUIDv4 eventId and persists with pending status', () async {
      final result = await repository.savePendingEventLocally(
        type: 'check_in',
        latitude: 12.971598,
        longitude: 77.594562,
        timestamp: testTime,
      );

      expect(result.isSuccess, isTrue);
      final event = result.dataOrNull!;
      expect(event.eventId, isNotEmpty);
      expect(event.type, equals('check_in'));
      expect(event.status, equals(EventSyncStatus.pending));

      // Read back from SQLite
      final pendingQueue = await repository.getPendingEvents();
      expect(pendingQueue.length, equals(1));
      expect(pendingQueue.first.eventId, equals(event.eventId));
    });
  });
}
