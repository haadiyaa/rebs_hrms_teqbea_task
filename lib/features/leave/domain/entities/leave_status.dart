/// Approval status of a submitted leave application.
enum LeaveStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  final String label;
  const LeaveStatus(this.label);

  static LeaveStatus fromString(String? val) {
    if (val == null) return LeaveStatus.pending;
    for (final s in LeaveStatus.values) {
      if (s.name.toLowerCase() == val.toLowerCase() ||
          s.label.toLowerCase() == val.toLowerCase()) {
        return s;
      }
    }
    return LeaveStatus.pending;
  }
}
