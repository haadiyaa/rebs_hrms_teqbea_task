import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/leave_request.dart';
import 'leave_status_badge.dart';

/// Card item presenting a historical leave application in the list.
class LeaveRequestCard extends StatelessWidget {
  final LeaveRequest request;

  const LeaveRequestCard({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      request.type.label == 'Casual'
                          ? Icons.beach_access
                          : Icons.medical_services_outlined,
                      size: 18,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${request.type.label} Leave',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                LeaveStatusBadge(status: request.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.date_range, size: 16, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(
                  '${request.startDate} to ${request.endDate}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const Spacer(),
                Text(
                  '${request.days} ${request.days == 1 ? 'day' : 'days'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request.reason,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
