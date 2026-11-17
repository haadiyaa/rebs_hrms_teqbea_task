import '../../../../core/errors/app_error.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/attendance_status.dart';

/// State representation for Attendance operations and dashboard widgets.
class AttendanceState {
  final AttendanceRecord? todayRecord;
  final List<AttendanceRecord> recentHistory;
  final bool isLoading;
  final bool isActionInProgress;
  final String? userMessage;
  final AppError? error;

  const AttendanceState({
    this.todayRecord,
    this.recentHistory = const [],
    this.isLoading = false,
    this.isActionInProgress = false,
    this.userMessage,
    this.error,
  });

  /// Today's current attendance status
  AttendanceStatus get todayStatus =>
      todayRecord?.status ?? AttendanceStatus.notCheckedIn;

  bool get canCheckIn =>
      !isActionInProgress && todayStatus == AttendanceStatus.notCheckedIn;

  bool get canCheckOut =>
      !isActionInProgress && todayStatus == AttendanceStatus.checkedIn;

  AttendanceState copyWith({
    AttendanceRecord? todayRecord,
    List<AttendanceRecord>? recentHistory,
    bool? isLoading,
    bool? isActionInProgress,
    String? userMessage,
    AppError? error,
    bool clearError = false,
    bool clearUserMessage = false,
  }) {
    return AttendanceState(
      todayRecord: todayRecord ?? this.todayRecord,
      recentHistory: recentHistory ?? this.recentHistory,
      isLoading: isLoading ?? this.isLoading,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      userMessage: clearUserMessage ? null : (userMessage ?? this.userMessage),
      error: clearError ? null : (error ?? this.error),
    );
  }
}
