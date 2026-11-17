import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/errors/app_error.dart';
import 'package:rebs_hrms/core/utils/clock.dart';
import 'package:rebs_hrms/features/leave/domain/entities/leave_balance.dart';
import 'package:rebs_hrms/features/leave/domain/entities/leave_request.dart';
import 'package:rebs_hrms/features/leave/domain/entities/leave_status.dart';
import 'package:rebs_hrms/features/leave/domain/entities/leave_type.dart';
import 'package:rebs_hrms/features/leave/domain/validators/leave_validator.dart';

void main() {
  group('LeaveValidator', () {
    const companyTimezone = 'Asia/Kolkata';
    late TestClock clock;
    // Current time: 2026-11-17 10:00 AM IST
    final currentTime = DateTime.utc(2026, 11, 17, 4, 30);

    const testBalance = LeaveBalance(
      total: 18,
      used: 4,
      available: 14,
      casual: LeaveCategoryBalance(total: 10, used: 2, available: 8),
      sick: LeaveCategoryBalance(total: 8, used: 2, available: 6),
    );

    final existingApproved = LeaveRequest(
      id: 'LR-101',
      type: LeaveType.casual,
      startDate: '2026-11-24',
      endDate: '2026-11-26',
      days: 3,
      reason: 'Family gathering event out of state',
      status: LeaveStatus.approved,
      createdAt: DateTime.utc(2026, 11, 10),
    );

    final existingRejected = LeaveRequest(
      id: 'LR-102',
      type: LeaveType.casual,
      startDate: '2026-11-20',
      endDate: '2026-11-21',
      days: 2,
      reason: 'Declined request for vacation',
      status: LeaveStatus.rejected,
      createdAt: DateTime.utc(2026, 11, 11),
    );

    setUp(() {
      clock = TestClock(currentTime);
    });

    test('valid leave request with sufficient balance passes validation', () {
      final result = LeaveValidator.validate(
        type: LeaveType.casual,
        startDateStr: '2026-11-18',
        endDateStr: '2026-11-19',
        reason: 'Personal family errands and commitments',
        balance: testBalance,
        existingRequests: [existingApproved],
        clock: clock,
        companyTimezone: companyTimezone,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, equals(2)); // 2 inclusive calendar days
    });

    test('start date before today in company timezone is rejected', () {
      final result = LeaveValidator.validate(
        type: LeaveType.casual,
        startDateStr: '2026-11-16', // Yesterday
        endDateStr: '2026-11-18',
        reason: 'Personal family errands and commitments',
        balance: testBalance,
        existingRequests: [],
        clock: clock,
        companyTimezone: companyTimezone,
      );

      expect(result.isFailure, isTrue);
      final error = result.errorOrNull as ValidationError;
      expect(error.fieldErrors.containsKey('startDate'), isTrue);
      expect(error.fieldErrors['startDate'], contains('cannot be before today'));
    });

    test('end date earlier than start date is rejected', () {
      final result = LeaveValidator.validate(
        type: LeaveType.sick,
        startDateStr: '2026-11-20',
        endDateStr: '2026-11-19', // Earlier than start
        reason: 'Severe migraine headache treatment',
        balance: testBalance,
        existingRequests: [],
        clock: clock,
        companyTimezone: companyTimezone,
      );

      expect(result.isFailure, isTrue);
      final error = result.errorOrNull as ValidationError;
      expect(error.fieldErrors.containsKey('endDate'), isTrue);
      expect(error.fieldErrors['endDate'], contains('cannot be earlier than start date'));
    });

    test('reason with less than 10 non-whitespace characters is rejected', () {
      final result = LeaveValidator.validate(
        type: LeaveType.casual,
        startDateStr: '2026-11-18',
        endDateStr: '2026-11-18',
        reason: '  Sick  ', // Only 4 non-whitespace chars
        balance: testBalance,
        existingRequests: [],
        clock: clock,
        companyTimezone: companyTimezone,
      );

      expect(result.isFailure, isTrue);
      final error = result.errorOrNull as ValidationError;
      expect(error.fieldErrors.containsKey('reason'), isTrue);
      expect(error.fieldErrors['reason'], contains('at least 10 non-whitespace characters'));
    });

    test('requested days exceeding available balance is rejected', () {
      // Available casual balance is 8 days; requesting 10 days
      final result = LeaveValidator.validate(
        type: LeaveType.casual,
        startDateStr: '2026-12-01',
        endDateStr: '2026-12-10', // 10 days
        reason: 'Long annual vacation with extended family',
        balance: testBalance,
        existingRequests: [],
        clock: clock,
        companyTimezone: companyTimezone,
      );

      expect(result.isFailure, isTrue);
      final error = result.errorOrNull as ValidationError;
      expect(error.fieldErrors.containsKey('days'), isTrue);
      expect(error.fieldErrors['days'], contains('exceeds your available Casual balance'));
    });

    // REQUIRED TEST 4: Overlapping leave dates are rejected
    test('Required Test 4: Overlapping leave dates are rejected with ValidationError', () {
      // Existing approved is 2026-11-24 to 2026-11-26
      // Attempting to apply for 2026-11-25 to 2026-11-28 (overlaps on 25th & 26th)
      final result = LeaveValidator.validate(
        type: LeaveType.casual,
        startDateStr: '2026-11-25',
        endDateStr: '2026-11-28',
        reason: 'Attending friend wedding celebration',
        balance: testBalance,
        existingRequests: [existingApproved],
        clock: clock,
        companyTimezone: companyTimezone,
      );

      expect(result.isFailure, isTrue);
      final error = result.errorOrNull as ValidationError;
      expect(error.fieldErrors.containsKey('dates'), isTrue);
      expect(error.fieldErrors['dates'], contains('overlap with an existing Approved leave'));
    });

    test('overlapping with a Rejected leave request is permitted', () {
      // Existing rejected was 2026-11-20 to 2026-11-21
      final result = LeaveValidator.validate(
        type: LeaveType.casual,
        startDateStr: '2026-11-20',
        endDateStr: '2026-11-21',
        reason: 'Re-applying with detailed manager approval',
        balance: testBalance,
        existingRequests: [existingRejected],
        clock: clock,
        companyTimezone: companyTimezone,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, equals(2));
    });
  });
}
