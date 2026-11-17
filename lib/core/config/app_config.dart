/// Application Configuration
/// Handles API base URL, office location, geofence radius,
/// company timezone, timeouts, and compile-time/runtime overrides.
class AppConfig {
  /// Base URL for the mock API server or ngrok tunnel.
  final String apiBaseUrl;

  /// Network request timeout duration.
  final Duration requestTimeout;

  /// Office location latitude.
  final double officeLatitude;

  /// Office location longitude.
  final double officeLongitude;

  /// Allowed geofence radius in meters (standard: 200m).
  final double officeRadiusMeters;

  /// Company official timezone (IANA timezone name, e.g. "Asia/Kolkata").
  final String companyTimezone;

  /// Optional mock latitude for developer/reviewer testing via --dart-define.
  final double? mockLatitude;

  /// Optional mock longitude for developer/reviewer testing via --dart-define.
  final double? mockLongitude;

  const AppConfig({
    required this.apiBaseUrl,
    this.requestTimeout = const Duration(seconds: 10),
    this.officeLatitude = 12.971598,
    this.officeLongitude = 77.594562,
    this.officeRadiusMeters = 200.0,
    this.companyTimezone = 'Asia/Kolkata',
    this.mockLatitude,
    this.mockLongitude,
  });

  /// Compile-time defaults read from environment (--dart-define flags)
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const int _defaultTimeoutSec = int.fromEnvironment(
    'REQUEST_TIMEOUT_SECONDS',
    defaultValue: 10,
  );

  static const String _envOfficeLat = String.fromEnvironment('OFFICE_LAT');
  static const String _envOfficeLng = String.fromEnvironment('OFFICE_LNG');
  static const String _envRadiusMeters = String.fromEnvironment('OFFICE_RADIUS_METERS');

  static const String _defaultCompanyTimezone = String.fromEnvironment(
    'COMPANY_TIMEZONE',
    defaultValue: 'Asia/Kolkata',
  );

  static const String _envMockLat = String.fromEnvironment('MOCK_LAT');
  static const String _envMockLng = String.fromEnvironment('MOCK_LNG');

  /// Creates an [AppConfig] with environment defines, optionally overridden by
  /// a runtime Base URL saved locally by the user or reviewer in settings.
  factory AppConfig.fromEnvironment({
    String? runtimeBaseUrlOverride,
    double? runtimeOfficeLat,
    double? runtimeOfficeLng,
    double? runtimeRadiusMeters,
    String? runtimeCompanyTimezone,
  }) {
    final double defaultLat = _envOfficeLat.isNotEmpty
        ? (double.tryParse(_envOfficeLat) ?? 12.971598)
        : 12.971598;
    final double defaultLng = _envOfficeLng.isNotEmpty
        ? (double.tryParse(_envOfficeLng) ?? 77.594562)
        : 77.594562;
    final double defaultRadius = _envRadiusMeters.isNotEmpty
        ? (double.tryParse(_envRadiusMeters) ?? 200.0)
        : 200.0;

    final double? mockLat =
        _envMockLat.isNotEmpty ? double.tryParse(_envMockLat) : null;
    final double? mockLng =
        _envMockLng.isNotEmpty ? double.tryParse(_envMockLng) : null;

    final String baseUrl = (runtimeBaseUrlOverride != null &&
            runtimeBaseUrlOverride.trim().isNotEmpty)
        ? runtimeBaseUrlOverride.trim()
        : _defaultBaseUrl;

    return AppConfig(
      apiBaseUrl: baseUrl,
      requestTimeout: const Duration(seconds: _defaultTimeoutSec),
      officeLatitude: runtimeOfficeLat ?? defaultLat,
      officeLongitude: runtimeOfficeLng ?? defaultLng,
      officeRadiusMeters: runtimeRadiusMeters ?? defaultRadius,
      companyTimezone: runtimeCompanyTimezone ?? _defaultCompanyTimezone,
      mockLatitude: mockLat,
      mockLongitude: mockLng,
    );
  }

  /// Returns a copy of [AppConfig] with updated fields.
  AppConfig copyWith({
    String? apiBaseUrl,
    Duration? requestTimeout,
    double? officeLatitude,
    double? officeLongitude,
    double? officeRadiusMeters,
    String? companyTimezone,
    double? mockLatitude,
    double? mockLongitude,
  }) {
    return AppConfig(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      officeLatitude: officeLatitude ?? this.officeLatitude,
      officeLongitude: officeLongitude ?? this.officeLongitude,
      officeRadiusMeters: officeRadiusMeters ?? this.officeRadiusMeters,
      companyTimezone: companyTimezone ?? this.companyTimezone,
      mockLatitude: mockLatitude ?? this.mockLatitude,
      mockLongitude: mockLongitude ?? this.mockLongitude,
    );
  }
}
