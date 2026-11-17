/// Represents the overall daily attendance state of an employee.
enum AttendanceStatus {
  notCheckedIn('Not Checked In'),
  checkedIn('Checked In'),
  checkedOut('Checked Out');

  final String label;
  const AttendanceStatus(this.label);

  static AttendanceStatus fromString(String? val) {
    if (val == null) return AttendanceStatus.notCheckedIn;
    for (final s in AttendanceStatus.values) {
      if (s.name.toLowerCase() == val.toLowerCase() ||
          s.label.toLowerCase() == val.toLowerCase()) {
        return s;
      }
    }
    return AttendanceStatus.notCheckedIn;
  }
}
