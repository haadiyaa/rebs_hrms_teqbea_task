import '../../../../core/errors/app_error.dart';
import '../../domain/entities/leave_balance.dart';
import '../../domain/entities/leave_request.dart';

/// State representation for Leave balance, requests list, and form submission.
class LeaveState {
  final LeaveBalance? balance;
  final List<LeaveRequest> requests;
  final bool isLoading;
  final bool isSubmitting;
  final Map<String, String> fieldErrors;
  final String? successMessage;
  final AppError? error;

  const LeaveState({
    this.balance,
    this.requests = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.fieldErrors = const {},
    this.successMessage,
    this.error,
  });

  bool get hasFieldErrors => fieldErrors.isNotEmpty;

  LeaveState copyWith({
    LeaveBalance? balance,
    List<LeaveRequest>? requests,
    bool? isLoading,
    bool? isSubmitting,
    Map<String, String>? fieldErrors,
    String? successMessage,
    AppError? error,
    bool clearErrors = false,
    bool clearSuccessMessage = false,
  }) {
    return LeaveState(
      balance: balance ?? this.balance,
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      fieldErrors: clearErrors ? const {} : (fieldErrors ?? this.fieldErrors),
      successMessage: clearSuccessMessage ? null : (successMessage ?? this.successMessage),
      error: clearErrors ? null : (error ?? this.error),
    );
  }
}
