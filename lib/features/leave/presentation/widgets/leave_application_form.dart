import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/leave_type.dart';
import '../../domain/validators/leave_validator.dart';
import '../providers/leave_notifier.dart';

/// Interactive Leave Application Form with live field-level validation
/// and inline server 422 error display.
class LeaveApplicationForm extends ConsumerStatefulWidget {
  final VoidCallback? onSuccess;

  const LeaveApplicationForm({super.key, this.onSuccess});

  @override
  ConsumerState<LeaveApplicationForm> createState() => _LeaveApplicationFormState();
}

class _LeaveApplicationFormState extends ConsumerState<LeaveApplicationForm> {
  LeaveType _selectedType = LeaveType.casual;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _reasonController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get _calculatedDays {
    if (_startDate == null || _endDate == null) return 0;
    if (_endDate!.isBefore(_startDate!)) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)), // Allow picking today
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      });
      _validateLive();
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final initial = _endDate ?? _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
      _validateLive();
    }
  }

  void _validateLive() {
    if (_startDate == null || _endDate == null) return;
    ref.read(leaveNotifierProvider.notifier).validateForm(
          type: _selectedType,
          startDateStr: _dateFormat.format(_startDate!),
          endDateStr: _dateFormat.format(_endDate!),
          reason: _reasonController.text,
        );
  }

  Future<void> _handleSubmit() async {
    final startDateStr = _startDate != null ? _dateFormat.format(_startDate!) : '';
    final endDateStr = _endDate != null ? _dateFormat.format(_endDate!) : '';
    final reason = _reasonController.text;

    final success = await ref.read(leaveNotifierProvider.notifier).submitLeave(
          type: _selectedType,
          startDateStr: startDateStr,
          endDateStr: endDateStr,
          reason: reason,
        );

    if (success && mounted) {
      _reasonController.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
      });
      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaveState = ref.watch(leaveNotifierProvider);
    final fieldErrors = leaveState.fieldErrors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apply for Leave',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 16),

            // Leave Type Selector
            const Text(
              'Leave Type',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 6),
            SegmentedButton<LeaveType>(
              segments: const [
                ButtonSegment(
                  value: LeaveType.casual,
                  label: Text('Casual Leave'),
                  icon: Icon(Icons.beach_access),
                ),
                ButtonSegment(
                  value: LeaveType.sick,
                  label: Text('Sick Leave'),
                  icon: Icon(Icons.medical_services_outlined),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<LeaveType> selected) {
                setState(() {
                  _selectedType = selected.first;
                });
                _validateLive();
              },
            ),
            if (fieldErrors.containsKey('type')) ...[
              const SizedBox(height: 4),
              Text(
                fieldErrors['type']!,
                style: const TextStyle(color: AppTheme.statusRejected, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),

            // Date Pickers Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Start Date',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectStartDate(context),
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            errorText: fieldErrors['startDate'],
                            prefixIcon: const Icon(Icons.calendar_today, size: 18),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          child: Text(
                            _startDate != null
                                ? _dateFormat.format(_startDate!)
                                : 'Select date',
                            style: TextStyle(
                              color: _startDate != null
                                  ? AppTheme.textDark
                                  : AppTheme.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'End Date',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectEndDate(context),
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            errorText: fieldErrors['endDate'],
                            prefixIcon: const Icon(Icons.event, size: 18),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          child: Text(
                            _endDate != null
                                ? _dateFormat.format(_endDate!)
                                : 'Select date',
                            style: TextStyle(
                              color: _endDate != null
                                  ? AppTheme.textDark
                                  : AppTheme.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Date range overlap or general date error
            if (fieldErrors.containsKey('dates')) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.statusRejected.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.statusRejected, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fieldErrors['dates']!,
                        style: const TextStyle(
                            color: AppTheme.statusRejected,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Days balance error
            if (fieldErrors.containsKey('days')) ...[
              const SizedBox(height: 6),
              Text(
                fieldErrors['days']!,
                style: const TextStyle(color: AppTheme.statusRejected, fontSize: 12),
              ),
            ],

            // Computed Duration Badge
            if (_calculatedDays > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Duration: $_calculatedDays calendar ${LeaveValidator.calculateInclusiveDays(_dateFormat.format(_startDate!), _dateFormat.format(_endDate!)) == 1 ? 'day' : 'days'}',
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Reason Text Field
            const Text(
              'Reason (Minimum 10 non-whitespace characters)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              onChanged: (_) => _validateLive(),
              decoration: InputDecoration(
                hintText: 'Enter specific reason for taking leave...',
                errorText: fieldErrors['reason'],
              ),
            ),

            // Submission Success Banner
            if (leaveState.successMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF15803D), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        leaveState.successMessage!,
                        style: const TextStyle(
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Submission Error Banner
            if (leaveState.error != null && !leaveState.hasFieldErrors) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        leaveState.error!.message,
                        style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w500,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: leaveState.isSubmitting ? null : _handleSubmit,
              child: leaveState.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Application'),
            ),
          ],
        ),
      ),
    );
  }
}
