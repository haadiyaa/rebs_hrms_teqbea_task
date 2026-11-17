import 'office_location.dart';

/// Preconfigured employee profile entity.
class Employee {
  final String id;
  final String name;
  final String department;
  final String designation;
  final OfficeLocation officeLocation;
  final String timezone;

  const Employee({
    required this.id,
    required this.name,
    required this.department,
    required this.designation,
    required this.officeLocation,
    this.timezone = 'Asia/Kolkata',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Employee &&
          other.id == id &&
          other.name == name &&
          other.department == department &&
          other.designation == designation &&
          other.officeLocation == officeLocation &&
          other.timezone == timezone);

  @override
  int get hashCode =>
      Object.hash(id, name, department, designation, officeLocation, timezone);

  @override
  String toString() => 'Employee($id, $name, $department)';
}
