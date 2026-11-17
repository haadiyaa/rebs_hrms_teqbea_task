import 'dart:math' as math;

/// Pure Dart Haversine distance calculation utility for geofence verification.
abstract final class GeofenceCalculator {
  /// Mean radius of the Earth in meters.
  static const double earthRadiusMeters = 6371000.0;

  /// Calculates the great-circle distance between two GPS coordinates in meters.
  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    final dLat = _toRadians(endLatitude - startLatitude);
    final dLon = _toRadians(endLongitude - startLongitude);

    final lat1Rad = _toRadians(startLatitude);
    final lat2Rad = _toRadians(endLatitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(lat1Rad) *
            math.cos(lat2Rad);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Returns true if the distance between coordinates is within [radiusMeters].
  static bool isWithinRadius({
    required double currentLatitude,
    required double currentLongitude,
    required double targetLatitude,
    required double targetLongitude,
    double radiusMeters = 200.0,
  }) {
    final distance = distanceBetween(
      currentLatitude,
      currentLongitude,
      targetLatitude,
      targetLongitude,
    );
    return distance <= radiusMeters;
  }

  static double _toRadians(double degree) => degree * (math.pi / 180.0);
}
