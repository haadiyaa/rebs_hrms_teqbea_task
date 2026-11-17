import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/data_providers.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';

/// State representation for Employee Profile.
class EmployeeState {
  final Employee? employee;
  final bool isLoading;
  final String? errorMessage;

  const EmployeeState({
    this.employee,
    this.isLoading = false,
    this.errorMessage,
  });

  EmployeeState copyWith({
    Employee? employee,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EmployeeState(
      employee: employee ?? this.employee,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for EmployeeNotifier.
final employeeNotifierProvider =
    NotifierProvider<EmployeeNotifier, EmployeeState>(
  EmployeeNotifier.new,
);

class EmployeeNotifier extends Notifier<EmployeeState> {
  EmployeeRepository get _repository => ref.read(employeeRepositoryProvider);

  @override
  EmployeeState build() {
    Future.microtask(() => loadEmployee());
    return const EmployeeState(isLoading: true);
  }

  Future<void> loadEmployee({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _repository.getEmployeeProfile(forceRefresh: forceRefresh);

    if (result.isSuccess) {
      final emp = result.dataOrNull;
      if (emp != null) {
        // Dynamically configure office coordinates and radius from API
        ref.read(appConfigProvider.notifier).updateOfficeGeofence(
              latitude: emp.officeLocation.latitude,
              longitude: emp.officeLocation.longitude,
              radiusMeters: emp.officeLocation.radiusMeters,
              timezone: emp.timezone,
            );
      }
      state = state.copyWith(
        employee: emp,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorOrNull?.message,
      );
    }
  }
}
