import 'attendance_event.dart';
import 'attendance_status.dart';

/// Aggregates an employee's attendance events for a single calendar day.
class AttendanceRecord {
  /// Date string formatted as YYYY-MM-DD in the company timezone.
  final String date;

  /// The check-in event for this day, if any.
  final AttendanceEvent? checkIn;

  /// The check-out event for this day, if any.
  final AttendanceEvent? checkOut;

  /// Computed or assigned daily attendance status.
  final AttendanceStatus status;

  const AttendanceRecord({
    required this.date,
    this.checkIn,
    this.checkOut,
    this.status = AttendanceStatus.notCheckedIn,
  });

  /// Calculates completed working duration between check-in and check-out.
  /// If only checked in, returns null (use [getLiveWorkingDuration] with a Clock).
  Duration? get completedWorkingDuration {
    if (checkIn != null && checkOut != null) {
      return checkOut!.timestamp.difference(checkIn!.timestamp);
    }
    return null;
  }

  /// Calculates live working duration up to [currentTime].
  Duration? getLiveWorkingDuration(DateTime currentTime) {
    if (checkIn == null) return null;
    if (checkOut != null) {
      return checkOut!.timestamp.difference(checkIn!.timestamp);
    }
    final diff = currentTime.difference(checkIn!.timestamp);
    return diff.isNegative ? Duration.zero : diff;
  }

  AttendanceRecord copyWith({
    String? date,
    AttendanceEvent? checkIn,
    AttendanceEvent? checkOut,
    AttendanceStatus? status,
  }) {
    return AttendanceRecord(
      date: date ?? this.date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceRecord &&
          other.date == date &&
          other.checkIn == checkIn &&
          other.checkOut == checkOut &&
          other.status == status);

  @override
  int get hashCode => Object.hash(date, checkIn, checkOut, status);

  @override
  String toString() =>
      'AttendanceRecord($date, status: ${status.label}, in: ${checkIn != null}, out: ${checkOut != null})';
}
