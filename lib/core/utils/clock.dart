import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Abstract clock interface allowing deterministic time mocking in unit tests.
/// Rule: Never call DateTime.now() directly in business logic.
abstract class Clock {
  const Clock();

  /// Returns the current UTC or local DateTime according to this clock.
  DateTime now();

  /// Returns the current DateTime converted to the specified company timezone.
  tz.TZDateTime nowInZone(String timezoneName) {
    Clock.ensureTimezoneInitialized();
    final tz.Location location = tz.getLocation(timezoneName);
    return tz.TZDateTime.from(now(), location);
  }

  /// Global flag to ensure timezone database is initialized once.
  static bool _timezoneInitialized = false;

  /// Ensures the IANA timezone database is loaded into memory.
  static void ensureTimezoneInitialized() {
    if (!_timezoneInitialized) {
      tz_data.initializeTimeZones();
      _timezoneInitialized = true;
    }
  }
}

/// Standard system clock using host system time.
class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Settable and advanceable clock for reproducible unit and integration tests.
class TestClock extends Clock {
  DateTime _current;

  TestClock(this._current);

  @override
  DateTime now() => _current;

  /// Sets the clock to an exact time.
  void setTime(DateTime time) {
    _current = time;
  }

  /// Advances the clock forward by [duration].
  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}
