import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/providers/core_providers.dart';
import 'package:rebs_hrms/features/attendance/domain/entities/attendance_status.dart';
import 'package:rebs_hrms/features/attendance/presentation/widgets/attendance_status_badge.dart';
import 'package:rebs_hrms/features/leave/domain/entities/leave_balance.dart';
import 'package:rebs_hrms/features/leave/presentation/widgets/leave_balance_card.dart';
import 'package:rebs_hrms/features/settings/presentation/screens/settings_screen.dart';
import 'package:rebs_hrms/features/sync/presentation/providers/sync_notifier.dart';
import 'package:rebs_hrms/features/sync/presentation/providers/sync_state.dart';
import 'package:rebs_hrms/features/sync/presentation/widgets/pending_sync_banner.dart';
import 'package:rebs_hrms/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestSyncNotifier extends SyncNotifier {
  final SyncState _fixedState;
  TestSyncNotifier(this._fixedState);

  @override
  SyncState build() {
    return _fixedState;
  }
}

void main() {
  group('Required Test 5: Widget Tests (Loading, Pending-Sync, Status Badges)', () {
    testWidgets('PendingSyncBanner shows pending count when offline items exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncNotifierProvider.overrideWith(
              () => TestSyncNotifier(const SyncState(pendingCount: 4, isSyncing: false)),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PendingSyncBanner(),
            ),
          ),
        ),
      );

      expect(find.text('4 action(s) pending sync'), findsOneWidget);
      expect(find.text('Saved locally offline. Will sync when reconnected.'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);
    });

    testWidgets('PendingSyncBanner is hidden when no items are pending', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncNotifierProvider.overrideWith(
              () => TestSyncNotifier(const SyncState(pendingCount: 0)),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PendingSyncBanner(),
            ),
          ),
        ),
      );

      expect(find.textContaining('pending sync'), findsNothing);
    });

    testWidgets('PendingSyncBanner displays loading indicator when syncing is in progress', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncNotifierProvider.overrideWith(
              () => TestSyncNotifier(const SyncState(pendingCount: 2, isSyncing: true)),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PendingSyncBanner(),
            ),
          ),
        ),
      );

      expect(find.text('2 action(s) pending sync'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AttendanceStatusBadge renders appropriate label and color per status', (tester) async {
      // 1. Not Checked In
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttendanceStatusBadge(attendanceStatus: AttendanceStatus.notCheckedIn),
          ),
        ),
      );
      expect(find.text('Not Checked In'), findsOneWidget);

      // 2. Checked In
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttendanceStatusBadge(attendanceStatus: AttendanceStatus.checkedIn),
          ),
        ),
      );
      expect(find.text('Checked In'), findsOneWidget);

      // 3. Checked Out
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttendanceStatusBadge(attendanceStatus: AttendanceStatus.checkedOut),
          ),
        ),
      );
      expect(find.text('Checked Out'), findsOneWidget);
    });

    testWidgets('LeaveBalanceCard displays loading state or balance counts correctly', (tester) async {
      // Loading state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LeaveBalanceCard(balance: null, isLoading: true),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Loaded state with balance data
      const sampleBalance = LeaveBalance(
        total: 20,
        used: 5,
        available: 15,
        casual: LeaveCategoryBalance(total: 12, used: 2, available: 10),
        sick: LeaveCategoryBalance(total: 8, used: 3, available: 5),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LeaveBalanceCard(balance: sampleBalance, isLoading: false),
          ),
        ),
      );

      expect(find.text('Available Leave Balance'), findsOneWidget);
      expect(find.text('15 Days Total'), findsOneWidget);
      expect(find.text('10 / 12 Left'), findsOneWidget); // Casual available / total
      expect(find.text('5 / 8 Left'), findsOneWidget);   // Sick available / total
      expect(find.text('Casual Leave'), findsOneWidget);
      expect(find.text('Sick Leave'), findsOneWidget);
    });

    testWidgets('SettingsScreen renders without error and displays base URL', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            syncNotifierProvider.overrideWith(
              () => TestSyncNotifier(const SyncState(pendingCount: 0)),
            ),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('Settings & Configuration'), findsOneWidget);
      expect(find.text('Backend API Base URL'), findsOneWidget);
      expect(find.text('Mock Server Scenarios'), findsOneWidget);
    });

    testWidgets('AppShell switches to Settings tab and renders content', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            syncNotifierProvider.overrideWith(
              () => TestSyncNotifier(const SyncState(pendingCount: 0)),
            ),
          ],
          child: const RebsHrmsApp(),
        ),
      );

      // Tap settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Backend API Base URL'), findsOneWidget);
    });
  });
}
