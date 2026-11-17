import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/attendance_notifier.dart';
import 'attendance_status_badge.dart';
import 'live_duration_counter.dart';

/// Central dashboard card managing today's attendance session and actions.
class TodayAttendanceCard extends ConsumerWidget {
  const TodayAttendanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceNotifierProvider);
    final notifier = ref.read(attendanceNotifierProvider.notifier);
    final timeFormat = DateFormat('hh:mm a');

    final rec = state.todayRecord;
    final checkInTimeStr = rec?.checkIn != null
        ? timeFormat.format(rec!.checkIn!.timestamp.toLocal())
        : '--:--';
    final checkOutTimeStr = rec?.checkOut != null
        ? timeFormat.format(rec!.checkOut!.timestamp.toLocal())
        : '--:--';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Attendance",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                AttendanceStatusBadge(attendanceStatus: state.todayStatus),
              ],
            ),
            const SizedBox(height: 16),

            // Live Duration Timer
            LiveDurationCounter(record: rec),
            const SizedBox(height: 16),

            // Timestamps Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login, size: 14, color: AppTheme.statusSuccess),
                            SizedBox(width: 4),
                            Text(
                              'Check In Time',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          checkInTimeStr,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        if (rec?.checkIn != null) ...[
                          const SizedBox(height: 2),
                          AttendanceStatusBadge(syncStatus: rec!.checkIn!.status),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, size: 14, color: AppTheme.primaryLight),
                            SizedBox(width: 4),
                            Text(
                              'Check Out Time',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          checkOutTimeStr,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        if (rec?.checkOut != null) ...[
                          const SizedBox(height: 2),
                          AttendanceStatusBadge(syncStatus: rec!.checkOut!.status),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Message Banner (Feedback / Outside Geofence / Offline Status)
            if (state.userMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: state.error != null
                      ? AppTheme.statusRejected.withValues(alpha: 0.1)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: state.error != null
                        ? AppTheme.statusRejected.withValues(alpha: 0.3)
                        : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.error != null ? Icons.warning_amber_rounded : Icons.info_outline,
                      color: state.error != null ? AppTheme.statusRejected : AppTheme.primaryLight,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.userMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: state.error != null
                              ? AppTheme.statusRejected
                              : AppTheme.primaryBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: notifier.dismissUserMessage,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Action Buttons Row (Check-In & Check-Out)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: state.canCheckIn
                        ? () async {
                            await notifier.checkIn();
                          }
                        : null,
                    icon: state.isActionInProgress && state.canCheckIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Check In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.statusSuccess,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: state.canCheckOut
                        ? () async {
                            await notifier.checkOut();
                          }
                        : null,
                    icon: state.isActionInProgress && state.canCheckOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.logout),
                    label: const Text('Check Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
