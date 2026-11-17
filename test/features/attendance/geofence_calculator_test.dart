import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/features/attendance/domain/utils/geofence_calculator.dart';

void main() {
  group('GeofenceCalculator', () {
    const officeLat = 12.971598;
    const officeLng = 77.594562;

    test('distance between identical points is 0 meters', () {
      final distance = GeofenceCalculator.distanceBetween(
        officeLat,
        officeLng,
        officeLat,
        officeLng,
      );

      expect(distance, equals(0.0));
      expect(
        GeofenceCalculator.isWithinRadius(
          currentLatitude: officeLat,
          currentLongitude: officeLng,
          targetLatitude: officeLat,
          targetLongitude: officeLng,
          radiusMeters: 200.0,
        ),
        isTrue,
      );
    });

    test('point within 100 meters is identified inside 200m radius', () {
      // Small shift (~50 meters north: 0.00045 degrees lat is ~50m)
      const nearbyLat = officeLat + 0.00045;
      const nearbyLng = officeLng;

      final distance = GeofenceCalculator.distanceBetween(
        nearbyLat,
        nearbyLng,
        officeLat,
        officeLng,
      );

      expect(distance, inInclusiveRange(45.0, 55.0));
      expect(
        GeofenceCalculator.isWithinRadius(
          currentLatitude: nearbyLat,
          currentLongitude: nearbyLng,
          targetLatitude: officeLat,
          targetLongitude: officeLng,
          radiusMeters: 200.0,
        ),
        isTrue,
      );
    });

    test('point 300 meters away is identified outside 200m radius', () {
      // Shift ~330 meters north (0.003 degrees lat is ~330m)
      const distantLat = officeLat + 0.003;
      const distantLng = officeLng;

      final distance = GeofenceCalculator.distanceBetween(
        distantLat,
        distantLng,
        officeLat,
        officeLng,
      );

      expect(distance, greaterThan(200.0));
      expect(
        GeofenceCalculator.isWithinRadius(
          currentLatitude: distantLat,
          currentLongitude: distantLng,
          targetLatitude: officeLat,
          targetLongitude: officeLng,
          radiusMeters: 200.0,
        ),
        isFalse,
      );
    });
  });
}
