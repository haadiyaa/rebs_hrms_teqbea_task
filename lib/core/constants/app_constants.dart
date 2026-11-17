/// System-wide constants for REBS HRMS
abstract final class AppConstants {
  /// Header required by ngrok to bypass its intermediate browser warning page
  static const String ngrokWarningHeader = 'ngrok-skip-browser-warning';
  static const String ngrokWarningValue = 'true';

  /// Standard JSON Content-Type
  static const String headerContentType = 'Content-Type';
  static const String contentTypeJson = 'application/json';

  /// SharedPreferences key for runtime base URL override
  static const String prefsBaseUrlKey = 'rebs_api_base_url_override';

  /// SQLite database configuration
  static const String databaseName = 'rebs_hrms.db';
  static const int databaseVersion = 1;

  /// Table names in SQLite
  static const String tablePendingEvents = 'pending_events';
  static const String tableCachedAttendance = 'cached_attendance';
  static const String tableCachedEmployee = 'cached_employee';
  static const String tableCachedLeaveRequests = 'cached_leave_requests';
  static const String tableCachedLeaveBalance = 'cached_leave_balance';
}
