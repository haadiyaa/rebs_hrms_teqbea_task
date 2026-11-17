import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../utils/clock.dart';

/// Provider for injectable [Clock] instance (defaults to [SystemClock]).
/// Override in unit/widget tests with [TestClock].
final clockProvider = Provider<Clock>((ref) {
  return const SystemClock();
});

/// SharedPreferences instance provider, initialized asynchronously or in main().
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden at startup');
});

/// StateNotifier/Notifier for [AppConfig] allowing runtime overrides of Base URL.
final appConfigProvider = NotifierProvider<AppConfigNotifier, AppConfig>(
  AppConfigNotifier.new,
);

class AppConfigNotifier extends Notifier<AppConfig> {
  @override
  AppConfig build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedBaseUrl = prefs.getString(AppConstants.prefsBaseUrlKey);
    return AppConfig.fromEnvironment(runtimeBaseUrlOverride: savedBaseUrl);
  }

  /// Updates the runtime API base URL and persists it to SharedPreferences.
  Future<void> updateBaseUrl(String newUrl) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final trimmed = newUrl.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(AppConstants.prefsBaseUrlKey);
      state = AppConfig.fromEnvironment();
    } else {
      await prefs.setString(AppConstants.prefsBaseUrlKey, trimmed);
      state = state.copyWith(apiBaseUrl: trimmed);
    }
  }

  /// Updates the office location coordinates and radius (e.g. from /employee/me).
  void updateOfficeGeofence({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    String? timezone,
  }) {
    state = state.copyWith(
      officeLatitude: latitude,
      officeLongitude: longitude,
      officeRadiusMeters: radiusMeters,
      companyTimezone: timezone ?? state.companyTimezone,
    );
  }
}
