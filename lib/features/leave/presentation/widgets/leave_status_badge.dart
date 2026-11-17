import 'package:flutter/material.dart';
import '../../domain/entities/leave_status.dart';

/// Status chip badge for Leave Requests (Pending, Approved, Rejected).
class LeaveStatusBadge extends StatelessWidget {
  final LeaveStatus status;

  const LeaveStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      LeaveStatus.approved => (
          const Color(0xFFDCFCE7),
          const Color(0xFF15803D),
        ),
      LeaveStatus.pending => (
          const Color(0xFFFEF3C7),
          const Color(0xFFB45309),
        ),
      LeaveStatus.rejected => (
          const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
