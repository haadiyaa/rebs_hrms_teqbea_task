import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs_hrms/core/config/app_config.dart';
import 'package:rebs_hrms/core/errors/app_error.dart';
import 'package:rebs_hrms/core/providers/core_providers.dart';
import 'package:rebs_hrms/core/providers/data_providers.dart';
import 'package:rebs_hrms/core/result/result.dart';
import 'package:rebs_hrms/core/utils/clock.dart';
import 'package:rebs_hrms/features/leave/domain/entities/leave_balance.dart';
import 'package:rebs_hrms/features/leave/domain/entities/leave_request.dart';
import 'package:rebs_hrms/features/leave/domain/entities/leave_status.dart';
import 'package:rebs_hrms/features/leave/domain/entities/leave_type.dart';
import 'package:rebs_hrms/features/leave/domain/repositories/leave_repository.dart';
import 'package:rebs_hrms/features/leave/presentation/providers/leave_notifier.dart';

class MockLeaveRepository extends Mock implements LeaveRepository {}

class MockAppConfigNotifier extends AppConfigNotifier {
  final AppConfig _mockConfig;
  MockAppConfigNotifier(this._mockConfig);

  @override
  AppConfig build() => _mockConfig;
}

void main() {
  setUpAll(() {
    registerFallbackValue(LeaveType.casual);
  });

  group('LeaveNotifier', () {
    late MockLeaveRepository mockLeaveRepo;
    late TestClock testClock;
    late ProviderContainer container;

    // Fixed time: 2026-11-17 10:00 AM IST
    final currentTime = DateTime.utc(2026, 11, 17, 4, 30);

    const testBalance = LeaveBalance(
      total: 18,
      used: 4,
      available: 14,
      casual: LeaveCategoryBalance(total: 10, used: 2, available: 8),
      sick: LeaveCategoryBalance(total: 8, used: 2, available: 6),
    );

    setUp(() {
      mockLeaveRepo = MockLeaveRepository();
      testClock = TestClock(currentTime);

      when(() => mockLeaveRepo.getLeaveBalance(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => const Success(testBalance));

      when(() => mockLeaveRepo.getLeaveRequests(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => const Success([]));

      container = ProviderContainer(
        overrides: [
          leaveRepositoryProvider.overrideWithValue(mockLeaveRepo),
          clockProvider.overrideWithValue(testClock),
          appConfigProvider.overrideWith(
            () => MockAppConfigNotifier(
              const AppConfig(
                apiBaseUrl: 'http://localhost:3000',
                companyTimezone: 'Asia/Kolkata',
              ),
            ),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('loadLeaveData loads balance and requests into state', () async {
      final notifier = container.read(leaveNotifierProvider.notifier);
      await notifier.loadLeaveData();

      final state = container.read(leaveNotifierProvider);
      expect(state.balance, equals(testBalance));
      expect(state.isLoading, isFalse);
    });

    test('submitLeave offline returns clear network error message', () async {
      final notifier = container.read(leaveNotifierProvider.notifier);
      await notifier.loadLeaveData();

      when(
        () => mockLeaveRepo.submitLeaveRequest(
          type: any(named: 'type'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => const Failure(NetworkError()));

      final success = await notifier.submitLeave(
        type: LeaveType.casual,
        startDateStr: '2026-11-20',
        endDateStr: '2026-11-21',
        reason: 'Personal family trip out of state',
      );

      expect(success, isFalse);
      final state = container.read(leaveNotifierProvider);
      expect(state.error, isA<NetworkError>());
      expect(state.error!.message, contains('requires an active network connection'));
    });

    test('submitLeave captures server 422 field errors and updates form fieldErrors map', () async {
      final notifier = container.read(leaveNotifierProvider.notifier);
      await notifier.loadLeaveData();

      when(
        () => mockLeaveRepo.submitLeaveRequest(
          type: any(named: 'type'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer(
        (_) async => const Failure(
          ValidationError(
            'Validation Failed',
            fieldErrors: {'dates': 'Department quota exceeded for selected dates.'},
          ),
        ),
      );

      final success = await notifier.submitLeave(
        type: LeaveType.casual,
        startDateStr: '2026-11-20',
        endDateStr: '2026-11-21',
        reason: 'Personal family trip out of state',
      );

      expect(success, isFalse);
      final state = container.read(leaveNotifierProvider);
      expect(state.fieldErrors.containsKey('dates'), isTrue);
      expect(state.fieldErrors['dates'], contains('Department quota exceeded'));
    });

    test('submitLeave on success updates requests list and balance', () async {
      final notifier = container.read(leaveNotifierProvider.notifier);
      await notifier.loadLeaveData();

      final submitted = LeaveRequest(
        id: 'LR-105',
        type: LeaveType.casual,
        startDate: '2026-11-20',
        endDate: '2026-11-21',
        days: 2,
        reason: 'Personal family trip out of state',
        status: LeaveStatus.pending,
        createdAt: currentTime,
      );

      when(
        () => mockLeaveRepo.submitLeaveRequest(
          type: any(named: 'type'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => Success(submitted));

      when(() => mockLeaveRepo.getLeaveBalance(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => const Success(testBalance));

      final success = await notifier.submitLeave(
        type: LeaveType.casual,
        startDateStr: '2026-11-20',
        endDateStr: '2026-11-21',
        reason: 'Personal family trip out of state',
      );

      expect(success, isTrue);
      final state = container.read(leaveNotifierProvider);
      expect(state.requests.length, equals(1));
      expect(state.requests.first.id, equals('LR-105'));
      expect(state.successMessage, contains('submitted successfully'));
    });
  });
}
