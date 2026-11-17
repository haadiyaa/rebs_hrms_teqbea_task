import '../../../../core/errors/app_error.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/clock.dart';
import '../../../employee/domain/entities/office_location.dart';
import '../entities/attendance_record.dart';
import '../utils/geofence_calculator.dart';

/// Pure Dart attendance business validation rules.
/// Rule: All validations use an injectable [Clock] and pure Dart logic.
abstract final class AttendanceRules {
  /// Maximum permitted forward clock skew buffer (5 minutes).
  static const Duration maxFutureClockSkew = Duration(minutes: 5);

  /// Validates a check-in attempt before creating or recording an event.
  static Result<void> validateCheckIn({
    required AttendanceRecord? todayRecord,
    required double currentLatitude,
    required double currentLongitude,
    required OfficeLocation officeLocation,
    required DateTime eventTimestamp,
    required Clock clock,
  }) {
    // 1. Geofence verification
    final distance = GeofenceCalculator.distanceBetween(
      currentLatitude,
      currentLongitude,
      officeLocation.latitude,
      officeLocation.longitude,
    );

    if (distance > officeLocation.radiusMeters) {
      return Failure(
        LocationError(
          message:
              'You are ${distance.toStringAsFixed(0)}m away from the office. '
              'Attendance is only permitted within ${officeLocation.radiusMeters.toStringAsFixed(0)}m.',
          kind: LocationErrorKind.outsideGeofence,
          distanceMeters: distance,
          allowedRadiusMeters: officeLocation.radiusMeters,
        ),
      );
    }

    // 2. Timestamp sanity: Cannot be in the future
    final clockNow = clock.now();
    if (eventTimestamp.isAfter(clockNow.add(maxFutureClockSkew))) {
      return const Failure(
        ValidationError('Event timestamp cannot be in the future.'),
      );
    }

    // 3. Rule: One check-in per working day. Reject repeats.
    if (todayRecord != null && todayRecord.checkIn != null) {
      return Failure(
        ConflictError(
          message:
              'You have already checked in for today at '
              '${todayRecord.checkIn!.timestamp.toLocal()}.',
        ),
      );
    }

    return const Success(null);
  }

  /// Validates a check-out attempt before creating or recording an event.
  static Result<void> validateCheckOut({
    required AttendanceRecord? todayRecord,
    required double currentLatitude,
    required double currentLongitude,
    required OfficeLocation officeLocation,
    required DateTime eventTimestamp,
    required Clock clock,
  }) {
    // 1. Geofence verification
    final distance = GeofenceCalculator.distanceBetween(
      currentLatitude,
      currentLongitude,
      officeLocation.latitude,
      officeLocation.longitude,
    );

    if (distance > officeLocation.radiusMeters) {
      return Failure(
        LocationError(
          message:
              'You are ${distance.toStringAsFixed(0)}m away from the office. '
              'Attendance is only permitted within ${officeLocation.radiusMeters.toStringAsFixed(0)}m.',
          kind: LocationErrorKind.outsideGeofence,
          distanceMeters: distance,
          allowedRadiusMeters: officeLocation.radiusMeters,
        ),
      );
    }

    // 2. Timestamp sanity: Cannot be in the future
    final clockNow = clock.now();
    if (eventTimestamp.isAfter(clockNow.add(maxFutureClockSkew))) {
      return const Failure(
        ValidationError('Event timestamp cannot be in the future.'),
      );
    }

    // 3. Rule: Check-out is permitted only after check-in
    if (todayRecord == null || todayRecord.checkIn == null) {
      return const Failure(
        ConflictError(
          message: 'Cannot check out: You have not checked in today yet.',
        ),
      );
    }

    // 4. Rule: One check-out per working day. Reject repeats.
    if (todayRecord.checkOut != null) {
      return Failure(
        ConflictError(
          message:
              'You have already checked out for today at '
              '${todayRecord.checkOut!.timestamp.toLocal()}.',
        ),
      );
    }

    // 5. Rule: Check-out timestamp cannot be earlier than check-in timestamp
    if (eventTimestamp.isBefore(todayRecord.checkIn!.timestamp)) {
      return const Failure(
        ValidationError(
          'Check-out timestamp cannot be earlier than your check-in timestamp.',
        ),
      );
    }

    return const Success(null);
  }
}
