import '../../../../core/network/api_client.dart';
import '../../domain/entities/leave_type.dart';
import '../models/leave_model.dart';

abstract interface class LeaveRemoteDataSource {
  Future<LeaveBalanceModel> getLeaveBalance();
  Future<List<LeaveRequestModel>> getLeaveRequests();
  Future<LeaveRequestModel> submitLeaveRequest({
    required LeaveType type,
    required String startDate,
    required String endDate,
    required String reason,
  });
}

class LeaveRemoteDataSourceImpl implements LeaveRemoteDataSource {
  final ApiClient _apiClient;

  LeaveRemoteDataSourceImpl(this._apiClient);

  @override
  Future<LeaveBalanceModel> getLeaveBalance() async {
    final response = await _apiClient.get('/leave/balance');
    return LeaveBalanceModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<LeaveRequestModel>> getLeaveRequests() async {
    final response = await _apiClient.get('/leave/requests');
    if (response is Map && response['requests'] is List) {
      final list = response['requests'] as List;
      return list
          .map((r) => LeaveRequestModel.fromJson(r as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<LeaveRequestModel> submitLeaveRequest({
    required LeaveType type,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    final payload = {
      'type': type.label,
      'startDate': startDate,
      'endDate': endDate,
      'reason': reason,
    };

    final response = await _apiClient.post(
      '/leave/requests',
      body: payload,
    );

    return LeaveRequestModel.fromJson(response as Map<String, dynamic>);
  }
}
