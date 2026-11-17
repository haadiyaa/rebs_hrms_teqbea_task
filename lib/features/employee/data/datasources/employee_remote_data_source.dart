import '../../../../core/network/api_client.dart';
import '../models/employee_model.dart';

abstract interface class EmployeeRemoteDataSource {
  Future<EmployeeModel> getEmployeeProfile();
}

class EmployeeRemoteDataSourceImpl implements EmployeeRemoteDataSource {
  final ApiClient _apiClient;

  EmployeeRemoteDataSourceImpl(this._apiClient);

  @override
  Future<EmployeeModel> getEmployeeProfile() async {
    final response = await _apiClient.get('/employee/me');
    return EmployeeModel.fromJson(response as Map<String, dynamic>);
  }
}
