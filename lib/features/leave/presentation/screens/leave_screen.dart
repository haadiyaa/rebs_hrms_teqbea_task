import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/leave_notifier.dart';
import '../widgets/leave_application_form.dart';
import '../widgets/leave_balance_card.dart';
import '../widgets/leave_request_card.dart';

/// Full screen for Leave Management with Application and History tabs.
class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaveState = ref.watch(leaveNotifierProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Leave Management',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: const TabBar(
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primaryBlue,
            tabs: [
              Tab(icon: Icon(Icons.edit_calendar, size: 20), text: 'Apply Leave'),
              Tab(icon: Icon(Icons.history, size: 20), text: 'My Requests'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: Apply for Leave
            RefreshIndicator(
              onRefresh: () => ref
                  .read(leaveNotifierProvider.notifier)
                  .loadLeaveData(forceRefresh: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    LeaveBalanceCard(
                      balance: leaveState.balance,
                      isLoading: leaveState.isLoading,
                    ),
                    const SizedBox(height: 16),
                    LeaveApplicationForm(
                      onSuccess: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Leave application submitted successfully!'),
                            backgroundColor: AppTheme.statusSuccess,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // TAB 2: Historical Leave Requests
            RefreshIndicator(
              onRefresh: () => ref
                  .read(leaveNotifierProvider.notifier)
                  .loadLeaveData(forceRefresh: true),
              child: leaveState.isLoading && leaveState.requests.isEmpty
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : leaveState.requests.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 64, color: AppTheme.textMuted),
                              SizedBox(height: 12),
                              Text(
                                'No leave requests found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16.0),
                          itemCount: leaveState.requests.length,
                          itemBuilder: (context, index) {
                            final request = leaveState.requests[index];
                            return LeaveRequestCard(request: request);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
