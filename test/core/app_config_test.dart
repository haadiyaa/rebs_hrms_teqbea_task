import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('default configuration parameters match assignment specification', () {
      final config = AppConfig.fromEnvironment();

      expect(config.officeRadiusMeters, equals(200.0));
      expect(config.officeLatitude, equals(12.971598));
      expect(config.officeLongitude, equals(77.594562));
      expect(config.companyTimezone, equals('Asia/Kolkata'));
      expect(config.requestTimeout, equals(const Duration(seconds: 10)));
      expect(config.apiBaseUrl, equals('http://localhost:3000'));
    });

    test('runtimeBaseUrlOverride takes precedence over default', () {
      const overrideUrl = 'https://custom-tunnel.ngrok-free.app';
      final config = AppConfig.fromEnvironment(
        runtimeBaseUrlOverride: overrideUrl,
      );

      expect(config.apiBaseUrl, equals(overrideUrl));
    });

    test('copyWith properly updates specific fields', () {
      final config = AppConfig.fromEnvironment();
      final updated = config.copyWith(
        officeLatitude: 13.0827,
        officeLongitude: 80.2707,
        officeRadiusMeters: 300.0,
      );

      expect(updated.officeLatitude, equals(13.0827));
      expect(updated.officeLongitude, equals(80.2707));
      expect(updated.officeRadiusMeters, equals(300.0));
      expect(updated.companyTimezone, equals(config.companyTimezone));
    });
  });
}
