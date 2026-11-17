import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/attendance_record.dart';
import 'attendance_status_badge.dart';

/// Widget rendering the latest 5 attendance records.
class RecentAttendanceList extends StatelessWidget {
  final List<AttendanceRecord> records;
  final bool isLoading;

  const RecentAttendanceList({
    super.key,
    required this.records,
    this.isLoading = false,
  });

  String _formatDuration(Duration? d) {
    if (d == null) return '--';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('hh:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Attendance (Latest 5)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  '${records.length} records',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading && records.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator.adaptive(),
                ),
              )
            else if (records.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off, size: 40, color: AppTheme.textMuted),
                      SizedBox(height: 8),
                      Text(
                        'No attendance history recorded yet.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length,
                separatorBuilder: (context, index) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final rec = records[index];
                  final checkInStr = rec.checkIn != null
                      ? timeFormat.format(rec.checkIn!.timestamp.toLocal())
                      : '--';
                  final checkOutStr = rec.checkOut != null
                      ? timeFormat.format(rec.checkOut!.timestamp.toLocal())
                      : '--';

                  // Determine sync status to show
                  final syncStatus = rec.checkOut?.status ?? rec.checkIn?.status;

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.date,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'In: $checkInStr • Out: $checkOutStr (${_formatDuration(rec.completedWorkingDuration)})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (syncStatus != null)
                        AttendanceStatusBadge(syncStatus: syncStatus)
                      else
                        AttendanceStatusBadge(attendanceStatus: rec.status),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
