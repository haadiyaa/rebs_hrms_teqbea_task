/// Represents the physical office coordinates and authorized geofence radius.
class OfficeLocation {
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const OfficeLocation({
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 200.0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfficeLocation &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.radiusMeters == radiusMeters);

  @override
  int get hashCode => Object.hash(latitude, longitude, radiusMeters);

  @override
  String toString() =>
      'OfficeLocation($latitude, $longitude, radius: ${radiusMeters}m)';
}
