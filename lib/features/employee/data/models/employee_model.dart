import '../../domain/entities/employee.dart';
import '../../domain/entities/office_location.dart';

/// DTO for Employee profile serialization to/from JSON and SQLite.
class EmployeeModel extends Employee {
  const EmployeeModel({
    required super.id,
    required super.name,
    required super.department,
    required super.designation,
    required super.officeLocation,
    super.timezone = 'Asia/Kolkata',
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final officeJson = json['officeLocation'] as Map<String, dynamic>? ?? {};

    return EmployeeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      officeLocation: OfficeLocation(
        latitude: (officeJson['latitude'] as num?)?.toDouble() ?? 12.971598,
        longitude: (officeJson['longitude'] as num?)?.toDouble() ?? 77.594562,
        radiusMeters: (officeJson['radiusMeters'] as num?)?.toDouble() ?? 200.0,
      ),
      timezone: json['timezone']?.toString() ?? 'Asia/Kolkata',
    );
  }

  factory EmployeeModel.fromDbMap(Map<String, dynamic> map) {
    return EmployeeModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      department: map['department']?.toString() ?? '',
      designation: map['designation']?.toString() ?? '',
      officeLocation: OfficeLocation(
        latitude: (map['latitude'] as num?)?.toDouble() ?? 12.971598,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 77.594562,
        radiusMeters: (map['radiusMeters'] as num?)?.toDouble() ?? 200.0,
      ),
      timezone: map['timezone']?.toString() ?? 'Asia/Kolkata',
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'department': department,
      'designation': designation,
      'latitude': officeLocation.latitude,
      'longitude': officeLocation.longitude,
      'radiusMeters': officeLocation.radiusMeters,
      'timezone': timezone,
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  factory EmployeeModel.fromEntity(Employee entity) {
    return EmployeeModel(
      id: entity.id,
      name: entity.name,
      department: entity.department,
      designation: entity.designation,
      officeLocation: entity.officeLocation,
      timezone: entity.timezone,
    );
  }
}
