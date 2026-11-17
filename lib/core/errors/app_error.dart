/// Base application error type for typed error handling throughout Clean Architecture.
sealed class AppError implements Exception {
  final String message;
  const AppError(this.message);

  @override
  String toString() => message;
}

/// No internet connection or offline socket failure.
final class NetworkError extends AppError {
  const NetworkError([super.message = 'No network connection available.']);
}

/// Request timed out before receiving a response.
final class TimeoutError extends AppError {
  const TimeoutError([super.message = 'Network request timed out.']);
}

/// 5xx server-side failures or unexpected gateway errors.
final class ServerError extends AppError {
  final int statusCode;
  final dynamic responseBody;

  const ServerError({
    required this.statusCode,
    String message = 'Internal server error occurred.',
    this.responseBody,
  }) : super(message);
}

/// 409 Conflict: Attendance record already exists for the day/event.
final class ConflictError extends AppError {
  final String? eventId;
  const ConflictError({
    String message = 'Attendance record already exists for this event.',
    this.eventId,
  }) : super(message);
}

/// 422 Unprocessable Entity or local form validation failures.
final class ValidationError extends AppError {
  /// Field-level validation error mapping (e.g. {'reason': 'Must be >= 10 characters'}).
  final Map<String, String> fieldErrors;

  const ValidationError(
    super.message, {
    this.fieldErrors = const {},
  });
}

/// Geofence or device location permission errors.
enum LocationErrorKind {
  permissionDenied,
  permissionPermanentlyDenied,
  serviceDisabled,
  outsideGeofence,
  unavailable,
}

final class LocationError extends AppError {
  final LocationErrorKind kind;
  final double? distanceMeters;
  final double? allowedRadiusMeters;

  const LocationError({
    required String message,
    required this.kind,
    this.distanceMeters,
    this.allowedRadiusMeters,
  }) : super(message);
}

/// Local SQLite database reading/writing failure.
final class DatabaseError extends AppError {
  final Object? cause;
  const DatabaseError(super.message, [this.cause]);
}

/// Unhandled or generic unexpected error.
final class UnknownError extends AppError {
  final Object? cause;
  const UnknownError([super.message = 'An unexpected error occurred.', this.cause]);
}
