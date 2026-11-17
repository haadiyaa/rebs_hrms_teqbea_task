import 'package:flutter/material.dart';
import '../../domain/entities/attendance_status.dart';
import '../../domain/entities/event_sync_status.dart';

/// Status chip badge for daily attendance or sync states.
class AttendanceStatusBadge extends StatelessWidget {
  final AttendanceStatus? attendanceStatus;
  final EventSyncStatus? syncStatus;

  const AttendanceStatusBadge({
    super.key,
    this.attendanceStatus,
    this.syncStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (syncStatus != null) {
      final (Color bg, Color fg, IconData icon) = switch (syncStatus!) {
        EventSyncStatus.synced => (
            const Color(0xFFDCFCE7),
            const Color(0xFF15803D),
            Icons.cloud_done,
          ),
        EventSyncStatus.pending => (
            const Color(0xFFFEF3C7),
            const Color(0xFFB45309),
            Icons.cloud_upload_outlined,
          ),
        EventSyncStatus.rejected => (
            const Color(0xFFFEE2E2),
            const Color(0xFFB91C1C),
            Icons.error_outline,
          ),
      };

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              syncStatus!.label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (attendanceStatus != null) {
      final (Color bg, Color fg, IconData icon) = switch (attendanceStatus!) {
        AttendanceStatus.checkedIn => (
            const Color(0xFFDCFCE7),
            const Color(0xFF15803D),
            Icons.login,
          ),
        AttendanceStatus.checkedOut => (
            const Color(0xFFEFF6FF),
            const Color(0xFF1D4ED8),
            Icons.logout,
          ),
        AttendanceStatus.notCheckedIn => (
            const Color(0xFFF1F5F9),
            const Color(0xFF64748B),
            Icons.schedule,
          ),
      };

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              attendanceStatus!.label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
