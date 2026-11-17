import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/attendance/data/datasources/attendance_local_data_source.dart';
import '../../features/attendance/data/datasources/attendance_remote_data_source.dart';
import '../../features/attendance/data/repositories/attendance_repository_impl.dart';
import '../../features/attendance/domain/repositories/attendance_repository.dart';
import '../../features/employee/data/datasources/employee_local_data_source.dart';
import '../../features/employee/data/datasources/employee_remote_data_source.dart';
import '../../features/employee/data/repositories/employee_repository_impl.dart';
import '../../features/employee/domain/repositories/employee_repository.dart';
import '../../features/leave/data/datasources/leave_local_data_source.dart';
import '../../features/leave/data/datasources/leave_remote_data_source.dart';
import '../../features/leave/data/repositories/leave_repository_impl.dart';
import '../../features/leave/domain/repositories/leave_repository.dart';
import '../database/database_helper.dart';
import '../network/api_client.dart';
import 'core_providers.dart';

/// Provider for SQLite DatabaseHelper singleton.
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  final helper = DatabaseHelper();
  ref.onDispose(() {
    helper.close();
  });
  return helper;
});

/// Provider for ApiClient configured with active AppConfig (supports runtime base URL).
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return ApiClient(appConfig: config);
});

// Employee Feature Providers
final employeeRemoteDataSourceProvider = Provider<EmployeeRemoteDataSource>((ref) {
  return EmployeeRemoteDataSourceImpl(ref.watch(apiClientProvider));
});

final employeeLocalDataSourceProvider = Provider<EmployeeLocalDataSource>((ref) {
  return EmployeeLocalDataSourceImpl(ref.watch(databaseHelperProvider));
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepositoryImpl(
    remoteDataSource: ref.watch(employeeRemoteDataSourceProvider),
    localDataSource: ref.watch(employeeLocalDataSourceProvider),
  );
});

// Attendance Feature Providers
final attendanceRemoteDataSourceProvider = Provider<AttendanceRemoteDataSource>((ref) {
  return AttendanceRemoteDataSourceImpl(ref.watch(apiClientProvider));
});

final attendanceLocalDataSourceProvider = Provider<AttendanceLocalDataSource>((ref) {
  return AttendanceLocalDataSourceImpl(ref.watch(databaseHelperProvider));
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl(
    remoteDataSource: ref.watch(attendanceRemoteDataSourceProvider),
    localDataSource: ref.watch(attendanceLocalDataSourceProvider),
    appConfig: ref.watch(appConfigProvider),
    clock: ref.watch(clockProvider),
  );
});

// Leave Feature Providers
final leaveRemoteDataSourceProvider = Provider<LeaveRemoteDataSource>((ref) {
  return LeaveRemoteDataSourceImpl(ref.watch(apiClientProvider));
});

final leaveLocalDataSourceProvider = Provider<LeaveLocalDataSource>((ref) {
  return LeaveLocalDataSourceImpl(ref.watch(databaseHelperProvider));
});

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepositoryImpl(
    remoteDataSource: ref.watch(leaveRemoteDataSourceProvider),
    localDataSource: ref.watch(leaveLocalDataSourceProvider),
  );
});
