import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../config/app_config.dart';
import '../errors/app_error.dart';
import '../result/result.dart';
import 'location_simulator.dart';

/// GPS Coordinates holder.
class LocationCoordinates {
  final double latitude;
  final double longitude;

  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() => 'LocationCoordinates($latitude, $longitude)';
}

/// Abstract location service interface for GPS capture and permission handling.
abstract interface class LocationService {
  Future<Result<LocationCoordinates>> getCurrentPosition();
  Future<bool> openAppSettings();
  Future<void> requestPermissionOnStartup();
}

/// Production LocationService wrapping geolocator with permission handling,
/// debug location simulation, and optional --dart-define MOCK_LAT / MOCK_LNG overrides.
class GeolocatorLocationService implements LocationService {
  final AppConfig appConfig;
  final LocationSimulatorState? simulatorState;

  GeolocatorLocationService({
    required this.appConfig,
    this.simulatorState,
  });

  @override
  Future<void> requestPermissionOnStartup() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {
      // Ignored on startup if platform channel unavailable
    }
  }

  /// Indicates whether the location simulator is actively overriding coordinates.
  bool get isUsingSimulatedLocation =>
      isLocationSimulatorAllowed &&
      simulatorState != null &&
      simulatorState!.isEnabled &&
      simulatorState!.simulatedLatitude != null &&
      simulatorState!.simulatedLongitude != null;

  @override
  Future<Result<LocationCoordinates>> getCurrentPosition() async {
    // 1. Location simulator check (Active in debug or when explicitly enabled for reviewer)
    if (isLocationSimulatorAllowed &&
        simulatorState != null &&
        simulatorState!.isEnabled &&
        simulatorState!.simulatedLatitude != null &&
        simulatorState!.simulatedLongitude != null) {
      return Success(
        LocationCoordinates(
          latitude: simulatorState!.simulatedLatitude!,
          longitude: simulatorState!.simulatedLongitude!,
        ),
      );
    }

    // 2. Developer / Reviewer simulation override via compile-time MOCK_LAT and MOCK_LNG
    if (appConfig.mockLatitude != null && appConfig.mockLongitude != null) {
      return Success(
        LocationCoordinates(
          latitude: appConfig.mockLatitude!,
          longitude: appConfig.mockLongitude!,
        ),
      );
    }

    // 2. Check if device location services (GPS hardware) are enabled
    final bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      return Failure(
        LocationError(
          message: 'Unable to check location services: $e',
          kind: LocationErrorKind.unavailable,
        ),
      );
    }

    if (!serviceEnabled) {
      return const Failure(
        LocationError(
          message:
              'Device location service is disabled. Please turn on GPS in your device settings to check in/out.',
          kind: LocationErrorKind.serviceDisabled,
        ),
      );
    }

    // 3. Check and request location permission
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const Failure(
            LocationError(
              message:
                  'Location permission was denied. Location is required to verify office geofence for attendance.',
              kind: LocationErrorKind.permissionDenied,
            ),
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const Failure(
          LocationError(
            message:
                'Location permission is permanently denied. Please tap below to open App Settings and grant location permission.',
            kind: LocationErrorKind.permissionPermanentlyDenied,
          ),
        );
      }
    } catch (e) {
      return Failure(
        LocationError(
          message: 'Failed to request location permission: $e',
          kind: LocationErrorKind.unavailable,
        ),
      );
    }

    // 4. Capture current GPS location with high accuracy
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return Success(
        LocationCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on TimeoutException {
      return const Failure(
        LocationError(
          message: 'GPS location request timed out. Please ensure you have clear GPS reception.',
          kind: LocationErrorKind.unavailable,
        ),
      );
    } catch (e) {
      return Failure(
        LocationError(
          message: 'Unable to acquire current location: $e',
          kind: LocationErrorKind.unavailable,
        ),
      );
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
