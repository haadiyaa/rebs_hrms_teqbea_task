import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../models/employee_model.dart';

abstract interface class EmployeeLocalDataSource {
  Future<EmployeeModel?> getCachedEmployee();
  Future<void> cacheEmployee(EmployeeModel employee);
}

class EmployeeLocalDataSourceImpl implements EmployeeLocalDataSource {
  final DatabaseHelper _databaseHelper;

  EmployeeLocalDataSourceImpl(this._databaseHelper);

  @override
  Future<EmployeeModel?> getCachedEmployee() async {
    final db = await _databaseHelper.database;
    final results = await db.query(
      AppConstants.tableCachedEmployee,
      limit: 1,
    );

    if (results.isEmpty) return null;
    return EmployeeModel.fromDbMap(results.first);
  }

  @override
  Future<void> cacheEmployee(EmployeeModel employee) async {
    final db = await _databaseHelper.database;
    await db.insert(
      AppConstants.tableCachedEmployee,
      employee.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
