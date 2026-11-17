import '../../../../core/errors/app_error.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/leave_balance.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/entities/leave_type.dart';
import '../../domain/repositories/leave_repository.dart';
import '../datasources/leave_local_data_source.dart';
import '../datasources/leave_remote_data_source.dart';

class LeaveRepositoryImpl implements LeaveRepository {
  final LeaveRemoteDataSource remoteDataSource;
  final LeaveLocalDataSource localDataSource;

  LeaveRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Result<LeaveBalance>> getLeaveBalance({bool forceRefresh = false}) async {
    try {
      final remoteBalance = await remoteDataSource.getLeaveBalance();
      await localDataSource.cacheLeaveBalance(remoteBalance);
      return Success(remoteBalance);
    } on AppError catch (networkError) {
      try {
        final cached = await localDataSource.getCachedLeaveBalance();
        if (cached != null) {
          return Success(cached);
        }
      } catch (e) {
        return Failure(DatabaseError('Failed to read cached leave balance.', e));
      }
      return Failure(networkError);
    } catch (e) {
      final cached = await localDataSource.getCachedLeaveBalance();
      if (cached != null) {
        return Success(cached);
      }
      return Failure(UnknownError('Failed to fetch leave balance.', e));
    }
  }

  @override
  Future<Result<List<LeaveRequest>>> getLeaveRequests({bool forceRefresh = false}) async {
    try {
      final remoteRequests = await remoteDataSource.getLeaveRequests();
      await localDataSource.cacheLeaveRequests(remoteRequests);
      return Success(remoteRequests);
    } on AppError catch (networkError) {
      try {
        final cached = await localDataSource.getCachedLeaveRequests();
        if (cached.isNotEmpty) {
          return Success(cached);
        }
      } catch (e) {
        return Failure(DatabaseError('Failed to read cached leave requests.', e));
      }
      return Failure(networkError);
    } catch (e) {
      final cached = await localDataSource.getCachedLeaveRequests();
      if (cached.isNotEmpty) {
        return Success(cached);
      }
      return Failure(UnknownError('Failed to fetch leave requests.', e));
    }
  }

  @override
  Future<Result<LeaveRequest>> submitLeaveRequest({
    required LeaveType type,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    try {
      final submitted = await remoteDataSource.submitLeaveRequest(
        type: type,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );

      // Cache newly submitted leave application
      await localDataSource.insertSubmittedRequest(submitted);

      // Optimistically or eagerly refresh balance if possible
      try {
        final updatedBalance = await remoteDataSource.getLeaveBalance();
        await localDataSource.cacheLeaveBalance(updatedBalance);
      } catch (_) {}

      return Success(submitted);
    } on AppError catch (appError) {
      return Failure(appError);
    } catch (e) {
      return Failure(UnknownError('Failed to submit leave request.', e));
    }
  }
}
