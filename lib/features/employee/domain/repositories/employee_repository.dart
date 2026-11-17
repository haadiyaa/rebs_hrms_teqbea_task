import '../../../../core/result/result.dart';
import '../entities/employee.dart';

/// Contract for fetching employee profile and office parameters.
abstract interface class EmployeeRepository {
  /// Fetches employee profile (from network or cached offline store).
  Future<Result<Employee>> getEmployeeProfile({bool forceRefresh = false});
}
