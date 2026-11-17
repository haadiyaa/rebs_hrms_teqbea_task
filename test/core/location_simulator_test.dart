import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/config/app_config.dart';
import 'package:rebs_hrms/core/services/location_service.dart';
import 'package:rebs_hrms/core/services/location_simulator.dart';
import 'package:rebs_hrms/features/attendance/domain/utils/geofence_calculator.dart';

void main() {
  group('LocationSimulator Math & Geodesy', () {
    const officeLat = 12.971598;
    const officeLng = 77.594562;

    test('At Office (0m) preset returns exactly office coordinates', () {
      final point = LocationSimulatorNotifier.calculateOffsetPoint(
        officeLat,
        officeLng,
        0.0,
      );

      expect(point.lat, closeTo(officeLat, 0.000001));
      expect(point.lng, closeTo(officeLng, 0.000001));

      final dist = GeofenceCalculator.distanceBetween(
        point.lat,
        point.lng,
        officeLat,
        officeLng,
      );
      expect(dist, closeTo(0.0, 0.1));
    });

    test('Inside Geofence (150m) preset generates coordinates within 200m radius', () {
      final point = LocationSimulatorNotifier.calculateOffsetPoint(
        officeLat,
        officeLng,
        150.0,
      );

      final dist = GeofenceCalculator.distanceBetween(
        point.lat,
        point.lng,
        officeLat,
        officeLng,
      );
      expect(dist, closeTo(150.0, 1.0));
      expect(dist, lessThan(200.0));
    });

    test('Exact Boundary (200m) preset generates coordinates at exactly 200m', () {
      final point = LocationSimulatorNotifier.calculateOffsetPoint(
        officeLat,
        officeLng,
        200.0,
      );

      final dist = GeofenceCalculator.distanceBetween(
        point.lat,
        point.lng,
        officeLat,
        officeLng,
      );
      expect(dist, closeTo(200.0, 1.0));
      expect(dist, lessThanOrEqualTo(200.05));
    });

    test('Outside Geofence (280m) preset generates coordinates beyond 200m radius', () {
      final point = LocationSimulatorNotifier.calculateOffsetPoint(
        officeLat,
        officeLng,
        280.0,
      );

      final dist = GeofenceCalculator.distanceBetween(
        point.lat,
        point.lng,
        officeLat,
        officeLng,
      );
      expect(dist, closeTo(280.0, 1.0));
      expect(dist, greaterThan(200.0));
    });
  });

  group('GeolocatorLocationService Simulator Injection', () {
    const testConfig = AppConfig(
      apiBaseUrl: 'http://localhost:3000',
      officeLatitude: 12.971598,
      officeLongitude: 77.594562,
      officeRadiusMeters: 200.0,
    );

    test('returns simulated position when simulator is enabled in debug mode', () async {
      const simState = LocationSimulatorState(
        isEnabled: true,
        simulatedLatitude: 12.972945,
        simulatedLongitude: 77.594562,
        activePreset: LocationSimulatorPreset.inside150m,
        calculatedDistanceMeters: 150.0,
      );

      final service = GeolocatorLocationService(
        appConfig: testConfig,
        simulatorState: simState,
      );
      final result = await service.getCurrentPosition();

      expect(result.isSuccess, isTrue);
      final coords = result.dataOrNull!;
      expect(coords.latitude, equals(12.972945));
      expect(coords.longitude, equals(77.594562));
    });

    test('isUsingSimulatedLocation reflects enabled state correctly', () {
      const activeSim = LocationSimulatorState(
        isEnabled: true,
        simulatedLatitude: 12.971598,
        simulatedLongitude: 77.594562,
      );
      const inactiveSim = LocationSimulatorState(isEnabled: false);

      final activeService = GeolocatorLocationService(
        appConfig: testConfig,
        simulatorState: activeSim,
      );
      final inactiveService = GeolocatorLocationService(
        appConfig: testConfig,
        simulatorState: inactiveSim,
      );

      expect(activeService.isUsingSimulatedLocation, isTrue);
      expect(inactiveService.isUsingSimulatedLocation, isFalse);
    });
  });
}
