import 'leave_status.dart';
import 'leave_type.dart';

/// Represents an applied leave request.
class LeaveRequest {
  final String id;
  final LeaveType type;

  /// Start date formatted as YYYY-MM-DD.
  final String startDate;

  /// End date formatted as YYYY-MM-DD.
  final String endDate;

  /// Total inclusive calendar days.
  final int days;

  /// Application reason (minimum 10 non-whitespace characters).
  final String reason;

  /// Current approval status: Pending, Approved, or Rejected.
  final LeaveStatus status;

  /// Timestamp when application was created.
  final DateTime createdAt;

  const LeaveRequest({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  bool get isPending => status == LeaveStatus.pending;
  bool get isApproved => status == LeaveStatus.approved;
  bool get isRejected => status == LeaveStatus.rejected;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LeaveRequest &&
          other.id == id &&
          other.type == type &&
          other.startDate == startDate &&
          other.endDate == endDate &&
          other.days == days &&
          other.reason == reason &&
          other.status == status &&
          other.createdAt == createdAt);

  @override
  int get hashCode => Object.hash(
        id,
        type,
        startDate,
        endDate,
        days,
        reason,
        status,
        createdAt,
      );

  @override
  String toString() =>
      'LeaveRequest($id, ${type.label}, $startDate to $endDate, days: $days, status: ${status.label})';
}
