import 'leave_type.dart';

/// Available and consumed leave days allocation.
class LeaveCategoryBalance {
  final int total;
  final int used;
  final int available;

  const LeaveCategoryBalance({
    required this.total,
    required this.used,
    required this.available,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LeaveCategoryBalance &&
          other.total == total &&
          other.used == used &&
          other.available == available);

  @override
  int get hashCode => Object.hash(total, used, available);
}

class LeaveBalance {
  final int total;
  final int used;
  final int available;
  final LeaveCategoryBalance casual;
  final LeaveCategoryBalance sick;

  const LeaveBalance({
    required this.total,
    required this.used,
    required this.available,
    required this.casual,
    required this.sick,
  });

  /// Returns available balance for the requested leave type.
  int getAvailableFor(LeaveType type) => switch (type) {
        LeaveType.casual => casual.available,
        LeaveType.sick => sick.available,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LeaveBalance &&
          other.total == total &&
          other.used == used &&
          other.available == available &&
          other.casual == casual &&
          other.sick == sick);

  @override
  int get hashCode => Object.hash(total, used, available, casual, sick);

  @override
  String toString() =>
      'LeaveBalance(total: $total, used: $used, available: $available)';
}
