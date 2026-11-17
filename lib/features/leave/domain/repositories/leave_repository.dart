import '../../../../core/result/result.dart';
import '../entities/leave_balance.dart';
import '../entities/leave_request.dart';
import '../entities/leave_type.dart';

/// Contract for leave management operations.
abstract interface class LeaveRepository {
  /// Fetches available leave balance (network-first with local cache).
  Future<Result<LeaveBalance>> getLeaveBalance({bool forceRefresh = false});

  /// Fetches historical leave requests (network-first with local cache).
  Future<Result<List<LeaveRequest>>> getLeaveRequests({bool forceRefresh = false});

  /// Submits a new leave application to the remote server.
  /// (Requires active network connection).
  Future<Result<LeaveRequest>> submitLeaveRequest({
    required LeaveType type,
    required String startDate,
    required String endDate,
    required String reason,
  });
}
