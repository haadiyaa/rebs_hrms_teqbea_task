import '../../../../core/errors/app_error.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employee_local_data_source.dart';
import '../datasources/employee_remote_data_source.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  final EmployeeRemoteDataSource remoteDataSource;
  final EmployeeLocalDataSource localDataSource;

  EmployeeRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Result<Employee>> getEmployeeProfile({bool forceRefresh = false}) async {
    // 1. Try network first unless forceRefresh is false and cache is available
    try {
      final remoteModel = await remoteDataSource.getEmployeeProfile();
      // Cache after successful fetch
      await localDataSource.cacheEmployee(remoteModel);
      return Success(remoteModel);
    } on AppError catch (networkError) {
      // 2. Network failed: fallback to offline cache
      try {
        final cached = await localDataSource.getCachedEmployee();
        if (cached != null) {
          return Success(cached);
        }
      } catch (cacheError) {
        return Failure(DatabaseError('Failed to read cached employee profile.', cacheError));
      }
      return Failure(networkError);
    } catch (e) {
      // Check cache before failing on unexpected error
      final cached = await localDataSource.getCachedEmployee();
      if (cached != null) {
        return Success(cached);
      }
      return Failure(UnknownError('Failed to retrieve employee profile.', e));
    }
  }
}
