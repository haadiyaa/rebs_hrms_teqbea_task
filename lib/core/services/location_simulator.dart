import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/attendance/domain/utils/geofence_calculator.dart';

/// Indicates whether developer/reviewer location simulation is permitted.
/// Permitted in all builds (debug, testing, and reviewer release APK) so reviewers
/// can test the 200m geofence rules from any device.
const bool isLocationSimulatorAllowed = true;

/// Available presets for debug-only location simulation.
enum LocationSimulatorPreset {
  office0m('At Office (0m)', 0.0),
  inside150m('Inside Geofence (~150m)', 150.0),
  boundary200m('Exact Boundary (200m)', 200.0),
  outside280m('Outside Geofence (~280m)', 280.0),
  custom('Custom Coordinates', null);

  final String label;
  final double? distanceMeters;

  const LocationSimulatorPreset(this.label, this.distanceMeters);
}

/// State representation for debug location simulation.
class LocationSimulatorState {
  final bool isEnabled;
  final double? simulatedLatitude;
  final double? simulatedLongitude;
  final LocationSimulatorPreset activePreset;
  final double? calculatedDistanceMeters;

  const LocationSimulatorState({
    this.isEnabled = false,
    this.simulatedLatitude,
    this.simulatedLongitude,
    this.activePreset = LocationSimulatorPreset.office0m,
    this.calculatedDistanceMeters,
  });

  LocationSimulatorState copyWith({
    bool? isEnabled,
    double? simulatedLatitude,
    double? simulatedLongitude,
    LocationSimulatorPreset? activePreset,
    double? calculatedDistanceMeters,
  }) {
    return LocationSimulatorState(
      isEnabled: isEnabled ?? this.isEnabled,
      simulatedLatitude: simulatedLatitude ?? this.simulatedLatitude,
      simulatedLongitude: simulatedLongitude ?? this.simulatedLongitude,
      activePreset: activePreset ?? this.activePreset,
      calculatedDistanceMeters:
          calculatedDistanceMeters ?? this.calculatedDistanceMeters,
    );
  }
}

/// Riverpod provider for debug location simulator.
final locationSimulatorProvider =
    NotifierProvider<LocationSimulatorNotifier, LocationSimulatorState>(
  LocationSimulatorNotifier.new,
);

class LocationSimulatorNotifier extends Notifier<LocationSimulatorState> {
  @override
  LocationSimulatorState build() {
    return const LocationSimulatorState();
  }

  /// Calculates a GPS point at an exact distance north of the office coordinate.
  static ({double lat, double lng}) calculateOffsetPoint(
    double officeLat,
    double officeLng,
    double distanceMeters,
  ) {
    if (distanceMeters == 0.0) {
      return (lat: officeLat, lng: officeLng);
    }
    // Spherical geodesy: deltaLat in radians = distance / earthRadius
    final deltaLatRad = distanceMeters / GeofenceCalculator.earthRadiusMeters;
    final deltaLatDeg = deltaLatRad * (180.0 / math.pi);
    return (lat: officeLat + deltaLatDeg, lng: officeLng);
  }

  /// Toggles simulated location on or off. Strictly guarded by [isLocationSimulatorAllowed].
  void toggle(
    bool enable, {
    required double officeLat,
    required double officeLng,
  }) {
    // SECURITY GUARD: Never allow simulator unless debug or explicitly permitted reviewer build
    if (!isLocationSimulatorAllowed && enable) {
      return;
    }

    if (!enable) {
      state = state.copyWith(isEnabled: false);
      return;
    }

    // Default to office0m preset if none active
    setPreset(
      state.activePreset,
      officeLat: officeLat,
      officeLng: officeLng,
    );
  }

  /// Activates one of the standard reviewer presets.
  void setPreset(
    LocationSimulatorPreset preset, {
    required double officeLat,
    required double officeLng,
  }) {
    // SECURITY GUARD: Never allow simulator unless debug or explicitly permitted reviewer build
    if (!isLocationSimulatorAllowed) {
      return;
    }

    if (preset == LocationSimulatorPreset.custom) {
      final lat = state.simulatedLatitude ?? officeLat;
      final lng = state.simulatedLongitude ?? officeLng;
      final dist = GeofenceCalculator.distanceBetween(lat, lng, officeLat, officeLng);
      state = LocationSimulatorState(
        isEnabled: true,
        simulatedLatitude: lat,
        simulatedLongitude: lng,
        activePreset: LocationSimulatorPreset.custom,
        calculatedDistanceMeters: dist,
      );
      return;
    }

    final targetDistance = preset.distanceMeters ?? 0.0;
    final coords = calculateOffsetPoint(officeLat, officeLng, targetDistance);
    final actualDistance = GeofenceCalculator.distanceBetween(
      coords.lat,
      coords.lng,
      officeLat,
      officeLng,
    );

    state = LocationSimulatorState(
      isEnabled: true,
      simulatedLatitude: coords.lat,
      simulatedLongitude: coords.lng,
      activePreset: preset,
      calculatedDistanceMeters: actualDistance,
    );
  }

  /// Sets custom simulated coordinates entered by reviewer.
  void setCustomLocation(
    double lat,
    double lng, {
    required double officeLat,
    required double officeLng,
  }) {
    // SECURITY GUARD: Never allow simulator unless debug or explicitly permitted reviewer build
    if (!isLocationSimulatorAllowed) {
      return;
    }

    final actualDistance = GeofenceCalculator.distanceBetween(
      lat,
      lng,
      officeLat,
      officeLng,
    );

    state = LocationSimulatorState(
      isEnabled: true,
      simulatedLatitude: lat,
      simulatedLongitude: lng,
      activePreset: LocationSimulatorPreset.custom,
      calculatedDistanceMeters: actualDistance,
    );
  }

  /// Disables simulation and reverts to device GPS.
  void disable() {
    state = const LocationSimulatorState(isEnabled: false);
  }
}
