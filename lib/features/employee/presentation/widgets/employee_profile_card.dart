import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/office_location.dart';

/// Card displaying the configured employee's name, ID, department, and designation.
class EmployeeProfileCard extends StatelessWidget {
  final Employee? employee;
  final bool isLoading;

  const EmployeeProfileCard({
    super.key,
    required this.employee,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && employee == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      );
    }

    final emp = employee ??
        const Employee(
          id: 'EMP-1042',
          name: 'Alex Mercer',
          department: 'Engineering',
          designation: 'Senior Mobile Engineer',
          officeLocation: OfficeLocation(
            latitude: 12.971598,
            longitude: 77.594562,
            radiusMeters: 200,
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
              child: Text(
                emp.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                style: const TextStyle(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        emp.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          emp.id,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${emp.designation} • ${emp.department}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.secondaryTeal),
                      const SizedBox(width: 4),
                      Text(
                        'Office Geofence: ${emp.officeLocation.radiusMeters.toStringAsFixed(0)}m radius',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.secondaryTeal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
