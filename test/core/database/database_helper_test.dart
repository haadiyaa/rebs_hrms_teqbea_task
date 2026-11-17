import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/constants/app_constants.dart';
import 'package:rebs_hrms/core/database/database_helper.dart';
import 'package:rebs_hrms/features/attendance/data/datasources/attendance_local_data_source.dart';
import 'package:rebs_hrms/features/attendance/data/models/attendance_model.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/event_sync_status.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper & SQLite Persistence', () {
    late String dbName;
    late DatabaseHelper dbHelper;
    late AttendanceLocalDataSourceImpl attendanceLocalDataSource;

    setUp(() async {
      dbName = 'test_db_${DateTime.now().microsecondsSinceEpoch}.db';
      dbHelper = DatabaseHelper(
        databaseFactory: databaseFactoryFfi,
        dbName: dbName,
      );
      attendanceLocalDataSource = AttendanceLocalDataSourceImpl(dbHelper);
    });

    tearDown(() async {
      await dbHelper.close();
      try {
        final databasesPath = await databaseFactoryFfi.getDatabasesPath();
        await databaseFactoryFfi.deleteDatabase('$databasesPath/$dbName');
      } catch (_) {}
    });

    test('creates all required tables on startup', () async {
      final db = await dbHelper.database;
      final tablesResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final tableNames = tablesResult.map((r) => r['name'] as String).toSet();

      expect(tableNames, contains(AppConstants.tablePendingEvents));
      expect(tableNames, contains(AppConstants.tableCachedAttendance));
      expect(tableNames, contains(AppConstants.tableCachedEmployee));
      expect(tableNames, contains(AppConstants.tableCachedLeaveBalance));
      expect(tableNames, contains(AppConstants.tableCachedLeaveRequests));
    });

    test('pending_events assigns strictly increasing sequence numbers for FIFO ordering', () async {
      final event1 = AttendanceEventModel(
        eventId: 'evt-uuid-1',
        type: 'check_in',
        timestamp: DateTime.utc(2026, 11, 17, 9, 0),
        latitude: 12.971598,
        longitude: 77.594562,
        createdAt: DateTime.utc(2026, 11, 17, 9, 0),
      );

      final event2 = AttendanceEventModel(
        eventId: 'evt-uuid-2',
        type: 'check_out',
        timestamp: DateTime.utc(2026, 11, 17, 17, 30),
        latitude: 12.971598,
        longitude: 77.594562,
        createdAt: DateTime.utc(2026, 11, 17, 17, 30),
      );

      final inserted1 = await attendanceLocalDataSource.insertPendingEvent(event1);
      final inserted2 = await attendanceLocalDataSource.insertPendingEvent(event2);

      expect(inserted1.sequence, equals(1));
      expect(inserted2.sequence, equals(2));

      final pendingList = await attendanceLocalDataSource.getPendingEvents();
      expect(pendingList.length, equals(2));
      expect(pendingList[0].eventId, equals('evt-uuid-1'));
      expect(pendingList[1].eventId, equals('evt-uuid-2'));
    });

    test('updating event status persists and removes from pending queue', () async {
      final event = AttendanceEventModel(
        eventId: 'evt-uuid-sync-test',
        type: 'check_in',
        timestamp: DateTime.utc(2026, 11, 17, 9, 0),
        latitude: 12.971598,
        longitude: 77.594562,
        createdAt: DateTime.utc(2026, 11, 17, 9, 0),
      );

      await attendanceLocalDataSource.insertPendingEvent(event);
      expect((await attendanceLocalDataSource.getPendingEvents()).length, equals(1));

      // Mark as Synced
      await attendanceLocalDataSource.updateEventSyncStatus(
        eventId: 'evt-uuid-sync-test',
        status: EventSyncStatus.synced,
      );

      // Should no longer appear in pending queue
      final pendingAfterSync = await attendanceLocalDataSource.getPendingEvents();
      expect(pendingAfterSync, isEmpty);

      // Should appear in all stored events with Synced status
      final allEvents = await attendanceLocalDataSource.getAllStoredEvents();
      expect(allEvents.length, equals(1));
      expect(allEvents.first.status, equals(EventSyncStatus.synced));
    });
  });
}
