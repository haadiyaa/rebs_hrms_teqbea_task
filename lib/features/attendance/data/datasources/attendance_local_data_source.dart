import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/entities/event_sync_status.dart';
import '../models/attendance_model.dart';

abstract interface class AttendanceLocalDataSource {
  Future<AttendanceEventModel> insertPendingEvent(AttendanceEventModel event);
  Future<List<AttendanceEventModel>> getPendingEvents();
  Future<List<AttendanceEventModel>> getAllStoredEvents();
  Future<void> updateEventSyncStatus({
    required String eventId,
    required EventSyncStatus status,
    String? rejectionReason,
  });
  Future<void> incrementEventAttempts(String eventId);
  Future<void> cacheAttendanceRecords(List<AttendanceRecordModel> records);
  Future<List<AttendanceRecordModel>> getCachedAttendanceRecords({String? month});
  Future<AttendanceRecordModel?> getCachedRecordForDate(String date);
}

class AttendanceLocalDataSourceImpl implements AttendanceLocalDataSource {
  final DatabaseHelper _databaseHelper;

  AttendanceLocalDataSourceImpl(this._databaseHelper);

  @override
  Future<AttendanceEventModel> insertPendingEvent(AttendanceEventModel event) async {
    final db = await _databaseHelper.database;

    // Use a transaction to safely compute the next sequence number and insert atomically
    return await db.transaction<AttendanceEventModel>((txn) async {
      final maxSeqResult = await txn.rawQuery(
        'SELECT COALESCE(MAX(sequence), 0) as maxSeq FROM ${AppConstants.tablePendingEvents}',
      );
      final int nextSequence = ((maxSeqResult.first['maxSeq'] as int?) ?? 0) + 1;

      final eventWithSeq = AttendanceEventModel(
        eventId: event.eventId,
        type: event.type,
        timestamp: event.timestamp,
        latitude: event.latitude,
        longitude: event.longitude,
        sequence: nextSequence,
        status: EventSyncStatus.pending,
        rejectionReason: null,
        attempts: 0,
        createdAt: event.createdAt,
      );

      await txn.insert(
        AppConstants.tablePendingEvents,
        eventWithSeq.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return eventWithSeq;
    });
  }

  @override
  Future<List<AttendanceEventModel>> getPendingEvents() async {
    final db = await _databaseHelper.database;
    // Strictly ordered by sequence ascending (FIFO)
    final results = await db.query(
      AppConstants.tablePendingEvents,
      where: 'status = ?',
      whereArgs: [EventSyncStatus.pending.name],
      orderBy: 'sequence ASC',
    );

    return results.map((m) => AttendanceEventModel.fromDbMap(m)).toList();
  }

  @override
  Future<List<AttendanceEventModel>> getAllStoredEvents() async {
    final db = await _databaseHelper.database;
    final results = await db.query(
      AppConstants.tablePendingEvents,
      orderBy: 'sequence ASC',
    );

    return results.map((m) => AttendanceEventModel.fromDbMap(m)).toList();
  }

  @override
  Future<void> updateEventSyncStatus({
    required String eventId,
    required EventSyncStatus status,
    String? rejectionReason,
  }) async {
    final db = await _databaseHelper.database;
    await db.update(
      AppConstants.tablePendingEvents,
      {
        'status': status.name,
        'rejectionReason': rejectionReason,
      },
      where: 'eventId = ?',
      whereArgs: [eventId],
    );
  }

  @override
  Future<void> incrementEventAttempts(String eventId) async {
    final db = await _databaseHelper.database;
    await db.rawUpdate(
      'UPDATE ${AppConstants.tablePendingEvents} SET attempts = attempts + 1 WHERE eventId = ?',
      [eventId],
    );
  }

  @override
  Future<void> cacheAttendanceRecords(List<AttendanceRecordModel> records) async {
    final db = await _databaseHelper.database;
    final batch = db.batch();

    for (final record in records) {
      batch.insert(
        AppConstants.tableCachedAttendance,
        record.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<List<AttendanceRecordModel>> getCachedAttendanceRecords({String? month}) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> results;

    if (month != null && month.isNotEmpty) {
      results = await db.query(
        AppConstants.tableCachedAttendance,
        where: 'date LIKE ?',
        whereArgs: ['$month%'],
        orderBy: 'date DESC',
      );
    } else {
      results = await db.query(
        AppConstants.tableCachedAttendance,
        orderBy: 'date DESC',
      );
    }

    return results.map((m) => AttendanceRecordModel.fromDbMap(m)).toList();
  }

  @override
  Future<AttendanceRecordModel?> getCachedRecordForDate(String date) async {
    final db = await _databaseHelper.database;
    final results = await db.query(
      AppConstants.tableCachedAttendance,
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return AttendanceRecordModel.fromDbMap(results.first);
  }
}
