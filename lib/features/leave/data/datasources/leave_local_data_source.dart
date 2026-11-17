import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../models/leave_model.dart';

abstract interface class LeaveLocalDataSource {
  Future<void> cacheLeaveBalance(LeaveBalanceModel balance);
  Future<LeaveBalanceModel?> getCachedLeaveBalance();
  Future<void> cacheLeaveRequests(List<LeaveRequestModel> requests);
  Future<List<LeaveRequestModel>> getCachedLeaveRequests();
  Future<void> insertSubmittedRequest(LeaveRequestModel request);
}

class LeaveLocalDataSourceImpl implements LeaveLocalDataSource {
  final DatabaseHelper _databaseHelper;

  LeaveLocalDataSourceImpl(this._databaseHelper);

  @override
  Future<void> cacheLeaveBalance(LeaveBalanceModel balance) async {
    final db = await _databaseHelper.database;
    await db.insert(
      AppConstants.tableCachedLeaveBalance,
      balance.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<LeaveBalanceModel?> getCachedLeaveBalance() async {
    final db = await _databaseHelper.database;
    final results = await db.query(
      AppConstants.tableCachedLeaveBalance,
      limit: 1,
    );

    if (results.isEmpty) return null;
    return LeaveBalanceModel.fromDbMap(results.first);
  }

  @override
  Future<void> cacheLeaveRequests(List<LeaveRequestModel> requests) async {
    final db = await _databaseHelper.database;
    final batch = db.batch();

    // Clear previous cache to mirror remote list
    batch.delete(AppConstants.tableCachedLeaveRequests);

    for (final req in requests) {
      batch.insert(
        AppConstants.tableCachedLeaveRequests,
        req.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<List<LeaveRequestModel>> getCachedLeaveRequests() async {
    final db = await _databaseHelper.database;
    final results = await db.query(
      AppConstants.tableCachedLeaveRequests,
      orderBy: 'createdAt DESC',
    );

    return results.map((m) => LeaveRequestModel.fromDbMap(m)).toList();
  }

  @override
  Future<void> insertSubmittedRequest(LeaveRequestModel request) async {
    final db = await _databaseHelper.database;
    await db.insert(
      AppConstants.tableCachedLeaveRequests,
      request.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
