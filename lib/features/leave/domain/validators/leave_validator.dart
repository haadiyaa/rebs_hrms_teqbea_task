import 'package:intl/intl.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/clock.dart';
import '../entities/leave_balance.dart';
import '../entities/leave_request.dart';
import '../entities/leave_type.dart';

/// Pure Dart leave validation engine.
/// Enforces all business rules and returns structured field-level errors.
abstract final class LeaveValidator {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Calculates inclusive calendar days between two YYYY-MM-DD dates.
  /// Rule: For this assignment, all calendar days count as leave days.
  static int calculateInclusiveDays(String startDateStr, String endDateStr) {
    try {
      final start = _dateFormat.parseStrict(startDateStr);
      final end = _dateFormat.parseStrict(endDateStr);
      if (end.isBefore(start)) return 0;
      return end.difference(start).inDays + 1;
    } catch (_) {
      return 0;
    }
  }

  /// Formats a DateTime into YYYY-MM-DD in the company timezone.
  static String formatCompanyDate(DateTime dateTime, Clock clock, String companyTimezone) {
    final tzDate = clock.nowInZone(companyTimezone);
    return _dateFormat.format(tzDate);
  }

  /// Validates a leave application against all domain business rules.
  static Result<int> validate({
    required LeaveType type,
    required String startDateStr,
    required String endDateStr,
    required String reason,
    required LeaveBalance? balance,
    required List<LeaveRequest> existingRequests,
    required Clock clock,
    required String companyTimezone,
  }) {
    final fieldErrors = <String, String>{};

    // 1. Reason validation: at least 10 non-whitespace characters
    final nonWhitespaceCharCount = reason.replaceAll(RegExp(r'\s+'), '').length;
    if (nonWhitespaceCharCount < 10) {
      fieldErrors['reason'] =
          'Reason must contain at least 10 non-whitespace characters (currently $nonWhitespaceCharCount).';
    }

    // 2. Date format validation
    DateTime? startDate;
    DateTime? endDate;

    try {
      startDate = _dateFormat.parseStrict(startDateStr);
    } catch (_) {
      fieldErrors['startDate'] = 'Invalid start date format (must be YYYY-MM-DD).';
    }

    try {
      endDate = _dateFormat.parseStrict(endDateStr);
    } catch (_) {
      fieldErrors['endDate'] = 'Invalid end date format (must be YYYY-MM-DD).';
    }

    if (fieldErrors.isNotEmpty) {
      return Failure(
        ValidationError('Please fix the errors below.', fieldErrors: fieldErrors),
      );
    }

    // 3. Start date cannot be before today in company timezone
    final todayInZone = clock.nowInZone(companyTimezone);
    final todayDate = DateTime.utc(todayInZone.year, todayInZone.month, todayInZone.day);
    final startUtc = DateTime.utc(startDate!.year, startDate.month, startDate.day);
    final endUtc = DateTime.utc(endDate!.year, endDate.month, endDate.day);

    if (startUtc.isBefore(todayDate)) {
      final todayStr = _dateFormat.format(todayDate);
      fieldErrors['startDate'] =
          'Start date cannot be before today ($todayStr) in company timezone.';
    }

    // 4. End date cannot be before start date
    if (endUtc.isBefore(startUtc)) {
      fieldErrors['endDate'] = 'End date cannot be earlier than start date.';
    }

    if (fieldErrors.isNotEmpty) {
      return Failure(
        ValidationError('Please fix the errors below.', fieldErrors: fieldErrors),
      );
    }

    // 5. Calculate inclusive days
    final requestedDays = endUtc.difference(startUtc).inDays + 1;

    // 6. Available balance validation
    if (balance != null) {
      final available = balance.getAvailableFor(type);
      if (requestedDays > available) {
        fieldErrors['days'] =
            'Requested $requestedDays days exceeds your available ${type.label} balance ($available days).';
      }
    }

    // 7. Overlap validation: cannot overlap with existing Pending or Approved requests
    for (final existing in existingRequests) {
      if (existing.isRejected) continue; // Rejected leaves do not block dates

      try {
        final exStart = _dateFormat.parseStrict(existing.startDate);
        final exEnd = _dateFormat.parseStrict(existing.endDate);
        final exStartUtc = DateTime.utc(exStart.year, exStart.month, exStart.day);
        final exEndUtc = DateTime.utc(exEnd.year, exEnd.month, exEnd.day);

        // Two intervals [A, B] and [C, D] overlap if not (B < C or A > D)
        final overlaps = !(endUtc.isBefore(exStartUtc) || startUtc.isAfter(exEndUtc));
        if (overlaps) {
          fieldErrors['dates'] =
              'Selected dates overlap with an existing ${existing.status.label} leave (${existing.startDate} to ${existing.endDate}).';
          break;
        }
      } catch (_) {
        // Skip malformed legacy records if any
      }
    }

    if (fieldErrors.isNotEmpty) {
      return Failure(
        ValidationError('Please fix the errors below.', fieldErrors: fieldErrors),
      );
    }

    return Success(requestedDays);
  }
}
