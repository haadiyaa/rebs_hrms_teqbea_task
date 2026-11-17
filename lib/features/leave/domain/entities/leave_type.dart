/// Types of leave supported by REBS HRMS.
enum LeaveType {
  casual('Casual'),
  sick('Sick');

  final String label;
  const LeaveType(this.label);

  static LeaveType fromString(String? val) {
    if (val == null) return LeaveType.casual;
    for (final t in LeaveType.values) {
      if (t.name.toLowerCase() == val.toLowerCase() ||
          t.label.toLowerCase() == val.toLowerCase()) {
        return t;
      }
    }
    return LeaveType.casual;
  }
}
