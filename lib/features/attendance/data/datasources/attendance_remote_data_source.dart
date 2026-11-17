import '../../../../core/network/api_client.dart';
import '../../domain/entities/attendance_event.dart';
import '../models/attendance_model.dart';

abstract interface class AttendanceRemoteDataSource {
  Future<List<AttendanceRecordModel>> getAttendanceHistory(String? month);
  Future<AttendanceEventModel> submitAttendanceEvent(AttendanceEvent event);
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  final ApiClient _apiClient;

  AttendanceRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<AttendanceRecordModel>> getAttendanceHistory(String? month) async {
    final queryParams = month != null ? {'month': month} : null;
    final response = await _apiClient.get(
      '/attendance',
      queryParameters: queryParams,
    );

    if (response is Map && response['records'] is List) {
      final recordsList = response['records'] as List;
      return recordsList
          .map((r) => AttendanceRecordModel.fromJson(r as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<AttendanceEventModel> submitAttendanceEvent(AttendanceEvent event) async {
    final payload = (AttendanceEventModel.fromEntity(event)).toJson();
    final response = await _apiClient.post(
      '/attendance/events',
      body: payload,
    );

    if (response is Map<String, dynamic>) {
      return AttendanceEventModel.fromJson(response);
    }

    return AttendanceEventModel.fromEntity(event);
  }
}
