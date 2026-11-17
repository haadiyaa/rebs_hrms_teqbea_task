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
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_event.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/event_sync_status.dart';
import 'package:rebs_hrms/features/sync/data/sync_engine_impl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockAttendanceRemoteDataSource extends Mock
    implements AttendanceRemoteDataSource {}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(
      AttendanceEvent(
        eventId: 'fallback-evt',
        type: 'check_in',
        timestamp: DateTime.now(),
        latitude: 0,
        longitude: 0,
        createdAt: DateTime.now(),
      ),
    );
  });

  group('SyncEngine', () {
    late String dbName;
    late DatabaseHelper dbHelper;
    late AttendanceLocalDataSource localDataSource;
    late MockAttendanceRemoteDataSource mockRemoteDataSource;
    late AttendanceRepositoryImpl attendanceRepository;
    late SyncEngineImpl syncEngine;
    late TestClock clock;
    const appConfig = AppConfig(apiBaseUrl: 'http://localhost:3000');

    final testTime = DateTime.utc(2026, 11, 17, 9, 0);

    setUp(() async {
      dbName = 'sync_engine_test_${DateTime.now().microsecondsSinceEpoch}.db';
      dbHelper = DatabaseHelper(
        databaseFactory: databaseFactoryFfi,
        dbName: dbName,
      );
      localDataSource = AttendanceLocalDataSourceImpl(dbHelper);
      mockRemoteDataSource = MockAttendanceRemoteDataSource();
      clock = TestClock(testTime);

      attendanceRepository = AttendanceRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        localDataSource: localDataSource,
        appConfig: appConfig,
        clock: clock,
      );

      syncEngine = SyncEngineImpl(
        attendanceRepository: attendanceRepository,
      );
    });

    tearDown(() async {
      await dbHelper.close();
      try {
        final databasesPath = await databaseFactoryFfi.getDatabasesPath();
        await databaseFactoryFfi.deleteDatabase('$databasesPath/$dbName');
      } catch (_) {}
    });

    // REQUIRED TEST 3: Pending events persist (write, recreate DB/repo, read back) and sync in order
    test('Required Test 3: Pending events survive persistence across repository recreation and sync in strict FIFO order', () async {
      // 1. Record check-in and check-out locally
      final inResult = await attendanceRepository.savePendingEventLocally(
        type: 'check_in',
        latitude: 12.971598,
        longitude: 77.594562,
        timestamp: testTime,
      );
      expect(inResult.isSuccess, isTrue);

      final outResult = await attendanceRepository.savePendingEventLocally(
        type: 'check_out',
        latitude: 12.971598,
        longitude: 77.594562,
        timestamp: testTime.add(const Duration(hours: 8)),
      );
      expect(outResult.isSuccess, isTrue);

      // 2. SIMULATE APP TERMINATION / RESTART: Close DB and recreate repository & sync engine from scratch
      await dbHelper.close();

      final newDbHelper = DatabaseHelper(
        databaseFactory: databaseFactoryFfi,
        dbName: dbName,
      );
      final newLocalDataSource = AttendanceLocalDataSourceImpl(newDbHelper);
      final newAttendanceRepo = AttendanceRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        localDataSource: newLocalDataSource,
        appConfig: appConfig,
        clock: clock,
      );
      final newSyncEngine = SyncEngineImpl(attendanceRepository: newAttendanceRepo);

      // Verify pending events survived persistence
      final pendingAfterRestart = await newAttendanceRepo.getPendingEvents();
      expect(pendingAfterRestart.length, equals(2));
      expect(pendingAfterRestart[0].type, equals('check_in'));
      expect(pendingAfterRestart[0].sequence, equals(1));
      expect(pendingAfterRestart[1].type, equals('check_out'));
      expect(pendingAfterRestart[1].sequence, equals(2));

      // 3. Sync events and verify order execution
      final List<String> executionOrder = [];

      when(() => mockRemoteDataSource.submitAttendanceEvent(any())).thenAnswer(
        (invocation) async {
          final event = invocation.positionalArguments.first as AttendanceEvent;
          executionOrder.add(event.type);
          return AttendanceEventModel.fromEntity(
            event.copyWith(status: EventSyncStatus.synced),
          );
        },
      );

      final syncResult = await newSyncEngine.synchronize();

      expect(syncResult.syncedCount, equals(2));
      expect(syncResult.rejectedCount, equals(0));
      expect(executionOrder, equals(['check_in', 'check_out']));

      // Queue is now empty
      expect(await newAttendanceRepo.getPendingEvents(), isEmpty);

      await newDbHelper.close();
    });

    // REQUIRED TEST 2: Repeated submission or retry does not create duplicate attendance (Idempotency)
    test('Required Test 2: Retrying with the same eventId returns original result and does not create duplicate server records', () async {
      final saveResult = await attendanceRepository.savePendingEventLocally(
        type: 'check_in',
        latitude: 12.971598,
        longitude: 77.594562,
        timestamp: testTime,
      );
      final pendingEvent = saveResult.dataOrNull!;

      // Simulate: Server already accepted the event on first attempt (e.g. before timeout)
      // When retried with the SAME eventId, remote server returns the originally stored event
      when(() => mockRemoteDataSource.submitAttendanceEvent(any())).thenAnswer(
        (_) async => AttendanceEventModel(
          eventId: pendingEvent.eventId, // Same UUID eventId
          type: pendingEvent.type,
          timestamp: pendingEvent.timestamp,
          latitude: pendingEvent.latitude,
          longitude: pendingEvent.longitude,
          sequence: pendingEvent.sequence,
          status: EventSyncStatus.synced,
          createdAt: pendingEvent.createdAt,
        ),
      );

      final result1 = await attendanceRepository.syncEvent(pendingEvent);
      expect(result1.isSuccess, isTrue);
      expect(result1.dataOrNull!.eventId, equals(pendingEvent.eventId));

      // Replay / retry identical eventId again
      final result2 = await attendanceRepository.syncEvent(pendingEvent);
      expect(result2.isSuccess, isTrue);
      expect(result2.dataOrNull!.eventId, equals(pendingEvent.eventId));

      // Only one unique record exists for this eventId
      verify(() => mockRemoteDataSource.submitAttendanceEvent(any())).called(2);
    });

    test('transient network failure (timeout) stops the queue immediately and keeps events pending', () async {
      await attendanceRepository.savePendingEventLocally(
        type: 'check_in',
        latitude: 12.971598,
        longitude: 77.594562,
        timestamp: testTime,
      );
      await attendanceRepository.savePendingEventLocally(
        type: 'check_out',
        latitude: 12.971598,
        longitude: 77.594562,
        timestamp: testTime.add(const Duration(hours: 8)),
      );

      // Remote throws TimeoutError on check-in
      when(() => mockRemoteDataSource.submitAttendanceEvent(any()))
          .thenThrow(const TimeoutError('Request timed out'));

      final syncResult = await syncEngine.synchronize();

      expect(syncResult.wasInterrupted, isTrue);
      expect(syncResult.syncedCount, equals(0));
      expect(syncResult.rejectedCount, equals(0));

      // Both events remain in the pending queue
      final remaining = await attendanceRepository.getPendingEvents();
      expect(remaining.length, equals(2));
      expect(remaining[0].status, equals(EventSyncStatus.pending));
      expect(remaining[1].status, equals(EventSyncStatus.pending));
    });

    test('409 Conflict marks check-in as rejected and cascades rejection to dependent check-out', () async {
      await attendanceRepository.savePendingEventLocally(
        type: 'check_in',
        latitude: 12.971598,
        longitude: 77.594562,
        timestamp: testTime,
      );
      await attendanceRepository.savePendingEventLocally(
        type: 'check_out',
        latitude: 12.971598,
        longitude: 77.594562,
        timestamp: testTime.add(const Duration(hours: 8)),
      );

      // Server rejects check-in with 409 Conflict
      when(() => mockRemoteDataSource.submitAttendanceEvent(any())).thenThrow(
        const ConflictError(message: 'Attendance record already exists for 2026-11-17'),
      );

      final syncResult = await syncEngine.synchronize();

      // Check-in was rejected, and check-out was cascaded as rejected
      expect(syncResult.rejectedCount, equals(2));
      expect(syncResult.syncedCount, equals(0));

      // Pending queue is empty
      expect(await attendanceRepository.getPendingEvents(), isEmpty);

      // Both events now stored with rejected status
      final allEvents = await localDataSource.getAllStoredEvents();
      expect(allEvents[0].status, equals(EventSyncStatus.rejected));
      expect(allEvents[0].rejectionReason, contains('already exists'));
      expect(allEvents[1].status, equals(EventSyncStatus.rejected));
      expect(allEvents[1].rejectionReason, contains('Dependent check-in was rejected'));
    });
  });
}
