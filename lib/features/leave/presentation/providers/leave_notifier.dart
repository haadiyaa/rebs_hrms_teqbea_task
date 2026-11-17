import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/data_providers.dart';
import '../../../../core/utils/clock.dart';
import '../../domain/entities/leave_type.dart';
import '../../domain/repositories/leave_repository.dart';
import '../../domain/validators/leave_validator.dart';
import 'leave_state.dart';

/// Provider for LeaveNotifier instance.
final leaveNotifierProvider = NotifierProvider<LeaveNotifier, LeaveState>(
  LeaveNotifier.new,
);

class LeaveNotifier extends Notifier<LeaveState> {
  LeaveRepository get _leaveRepository => ref.read(leaveRepositoryProvider);
  AppConfig get _appConfig => ref.read(appConfigProvider);
  Clock get _clock => ref.read(clockProvider);

  @override
  LeaveState build() {
    Future.microtask(() => loadLeaveData());
    return const LeaveState(isLoading: true);
  }

  /// Loads leave balance and requests (network-first, falling back to SQLite cache).
  Future<void> loadLeaveData({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, clearErrors: true);

    final balanceResult = await _leaveRepository.getLeaveBalance(
      forceRefresh: forceRefresh,
    );
    final requestsResult = await _leaveRepository.getLeaveRequests(
      forceRefresh: forceRefresh,
    );

    state = state.copyWith(
      balance: balanceResult.dataOrNull ?? state.balance,
      requests: requestsResult.dataOrNull ?? state.requests,
      isLoading: false,
    );
  }

  /// Validates input values live as the user edits the form.
  Map<String, String> validateForm({
    required LeaveType type,
    required String startDateStr,
    required String endDateStr,
    required String reason,
  }) {
    final result = LeaveValidator.validate(
      type: type,
      startDateStr: startDateStr,
      endDateStr: endDateStr,
      reason: reason,
      balance: state.balance,
      existingRequests: state.requests,
      clock: _clock,
      companyTimezone: _appConfig.companyTimezone,
    );

    if (result.isFailure) {
      final error = result.errorOrNull!;
      if (error is ValidationError) {
        state = state.copyWith(fieldErrors: error.fieldErrors);
        return error.fieldErrors;
      }
    }

    state = state.copyWith(clearErrors: true);
    return const {};
  }

  /// Submits the leave request to the backend.
  /// Rule: Leave submission requires an active network connection.
  Future<bool> submitLeave({
    required LeaveType type,
    required String startDateStr,
    required String endDateStr,
    required String reason,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearErrors: true,
      clearSuccessMessage: true,
    );

    // 1. Device-side domain validation
    final localValidation = LeaveValidator.validate(
      type: type,
      startDateStr: startDateStr,
      endDateStr: endDateStr,
      reason: reason,
      balance: state.balance,
      existingRequests: state.requests,
      clock: _clock,
      companyTimezone: _appConfig.companyTimezone,
    );

    if (localValidation.isFailure) {
      final valError = localValidation.errorOrNull as ValidationError;
      state = state.copyWith(
        isSubmitting: false,
        fieldErrors: valError.fieldErrors,
        error: valError,
      );
      return false;
    }

    // 2. Submit to server via repository
    final submitResult = await _leaveRepository.submitLeaveRequest(
      type: type,
      startDate: startDateStr,
      endDate: endDateStr,
      reason: reason,
    );

    if (submitResult.isSuccess) {
      final newRequest = submitResult.dataOrNull!;
      final updatedList = [newRequest, ...state.requests];

      // Refresh balance
      final updatedBalance = await _leaveRepository.getLeaveBalance();

      state = state.copyWith(
        isSubmitting: false,
        requests: updatedList,
        balance: updatedBalance.dataOrNull ?? state.balance,
        successMessage:
            'Leave request for ${newRequest.days} day(s) submitted successfully!',
        clearErrors: true,
      );
      return true;
    }

    // 3. Handle server-side failure
    final submitError = submitResult.errorOrNull!;

    if (submitError is ValidationError) {
      // Handles server 422 field errors even when device validation passed!
      state = state.copyWith(
        isSubmitting: false,
        fieldErrors: submitError.fieldErrors,
        error: submitError,
      );
    } else if (submitError is NetworkError) {
      state = state.copyWith(
        isSubmitting: false,
        error: const NetworkError(
          'Leave submission requires an active network connection. '
          'Please verify your internet connection and try again.',
        ),
      );
    } else {
      state = state.copyWith(
        isSubmitting: false,
        error: submitError,
      );
    }

    return false;
  }

  void clearMessages() {
    state = state.copyWith(clearErrors: true, clearSuccessMessage: true);
  }
}
