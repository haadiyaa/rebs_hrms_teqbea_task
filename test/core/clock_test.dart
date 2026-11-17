import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/utils/clock.dart';

void main() {
  group('Clock', () {
    test('TestClock maintains deterministic time and advances properly', () {
      final initial = DateTime.utc(2026, 11, 17, 9, 30);
      final clock = TestClock(initial);

      expect(clock.now(), equals(initial));

      clock.advance(const Duration(minutes: 45));
      expect(clock.now(), equals(DateTime.utc(2026, 11, 17, 10, 15)));

      clock.setTime(DateTime.utc(2026, 11, 18, 8, 0));
      expect(clock.now(), equals(DateTime.utc(2026, 11, 18, 8, 0)));
    });

    test('nowInZone converts UTC DateTime to company timezone', () {
      final utcTime = DateTime.utc(2026, 11, 17, 4, 30); // 10:00 AM IST
      final clock = TestClock(utcTime);

      final istTime = clock.nowInZone('Asia/Kolkata');
      expect(istTime.year, equals(2026));
      expect(istTime.month, equals(11));
      expect(istTime.day, equals(17));
      expect(istTime.hour, equals(10));
      expect(istTime.minute, equals(0));
    });
  });
}
