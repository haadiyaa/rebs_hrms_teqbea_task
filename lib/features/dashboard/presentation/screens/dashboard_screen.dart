import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../attendance/presentation/providers/attendance_notifier.dart';
import '../../../attendance/presentation/widgets/recent_attendance_list.dart';
import '../../../attendance/presentation/widgets/today_attendance_card.dart';
import '../../../employee/presentation/providers/employee_notifier.dart';
import '../../../employee/presentation/widgets/employee_profile_card.dart';
import '../../../leave/presentation/providers/leave_notifier.dart';
import '../../../leave/presentation/widgets/leave_balance_card.dart';
import '../../../sync/presentation/widgets/pending_sync_banner.dart';

/// Central Employee Dashboard uniting Employee profile, Today's attendance session,
/// Live Duration, Quick Leave Balance, and Recent History with pull-to-refresh.
class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToLeave;

  const DashboardScreen({
    super.key,
    this.onNavigateToLeave,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Initial fetch of employee, attendance, and leave data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  Future<void> _refreshAllData() async {
    await Future.wait([
      ref.read(employeeNotifierProvider.notifier).loadEmployee(),
      ref.read(attendanceNotifierProvider.notifier).loadDashboardAttendance(),
      ref.read(leaveNotifierProvider.notifier).loadLeaveData(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final employeeState = ref.watch(employeeNotifierProvider);
    final attendanceState = ref.watch(attendanceNotifierProvider);
    final leaveState = ref.watch(leaveNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'REBS HRMS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Dashboard',
            onPressed: () {
              ref.read(employeeNotifierProvider.notifier).loadEmployee(forceRefresh: true);
              ref.read(attendanceNotifierProvider.notifier).loadDashboardAttendance(forceRefresh: true);
              ref.read(leaveNotifierProvider.notifier).loadLeaveData(forceRefresh: true);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(employeeNotifierProvider.notifier).loadEmployee(forceRefresh: true);
          await ref.read(attendanceNotifierProvider.notifier).loadDashboardAttendance(forceRefresh: true);
          await ref.read(leaveNotifierProvider.notifier).loadLeaveData(forceRefresh: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Offline Sync Banner (visible when pending count > 0)
              const PendingSyncBanner(),

              // Employee Profile Summary Card
              EmployeeProfileCard(
                employee: employeeState.employee,
                isLoading: employeeState.isLoading,
              ),
              const SizedBox(height: 16),

              // Today's Attendance & Action Card
              const TodayAttendanceCard(),
              const SizedBox(height: 16),

              // Quick Leave Balance with action to view/apply
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Leave Balances',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  if (widget.onNavigateToLeave != null)
                    TextButton.icon(
                      onPressed: widget.onNavigateToLeave,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Apply / History'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              LeaveBalanceCard(
                balance: leaveState.balance,
                isLoading: leaveState.isLoading,
              ),
              const SizedBox(height: 20),

              // Recent Attendance Records
              RecentAttendanceList(
                records: attendanceState.recentHistory,
                isLoading: attendanceState.isLoading && attendanceState.recentHistory.isEmpty,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
