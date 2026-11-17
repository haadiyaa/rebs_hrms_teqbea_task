import '../../domain/entities/leave_balance.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/entities/leave_status.dart';
import '../../domain/entities/leave_type.dart';

/// DTO for LeaveBalance serialization to/from JSON and SQLite.
class LeaveBalanceModel extends LeaveBalance {
  const LeaveBalanceModel({
    required super.total,
    required super.used,
    required super.available,
    required super.casual,
    required super.sick,
  });

  factory LeaveBalanceModel.fromJson(Map<String, dynamic> json) {
    final breakdown = json['breakdown'] as Map<String, dynamic>? ?? {};
    final casualJson = breakdown['casual'] as Map<String, dynamic>? ?? {};
    final sickJson = breakdown['sick'] as Map<String, dynamic>? ?? {};

    return LeaveBalanceModel(
      total: (json['total'] as num?)?.toInt() ?? 0,
      used: (json['used'] as num?)?.toInt() ?? 0,
      available: (json['available'] as num?)?.toInt() ?? 0,
      casual: LeaveCategoryBalance(
        total: (casualJson['total'] as num?)?.toInt() ?? 0,
        used: (casualJson['used'] as num?)?.toInt() ?? 0,
        available: (casualJson['available'] as num?)?.toInt() ?? 0,
      ),
      sick: LeaveCategoryBalance(
        total: (sickJson['total'] as num?)?.toInt() ?? 0,
        used: (sickJson['used'] as num?)?.toInt() ?? 0,
        available: (sickJson['available'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  factory LeaveBalanceModel.fromDbMap(Map<String, dynamic> map) {
    return LeaveBalanceModel(
      total: (map['total'] as num?)?.toInt() ?? 0,
      used: (map['used'] as num?)?.toInt() ?? 0,
      available: (map['available'] as num?)?.toInt() ?? 0,
      casual: LeaveCategoryBalance(
        total: (map['casualTotal'] as num?)?.toInt() ?? 0,
        used: (map['casualUsed'] as num?)?.toInt() ?? 0,
        available: (map['casualAvailable'] as num?)?.toInt() ?? 0,
      ),
      sick: LeaveCategoryBalance(
        total: (map['sickTotal'] as num?)?.toInt() ?? 0,
        used: (map['sickUsed'] as num?)?.toInt() ?? 0,
        available: (map['sickAvailable'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': 1,
      'total': total,
      'used': used,
      'available': available,
      'casualTotal': casual.total,
      'casualUsed': casual.used,
      'casualAvailable': casual.available,
      'sickTotal': sick.total,
      'sickUsed': sick.used,
      'sickAvailable': sick.available,
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

/// DTO for LeaveRequest serialization to/from JSON and SQLite.
class LeaveRequestModel extends LeaveRequest {
  const LeaveRequestModel({
    required super.id,
    required super.type,
    required super.startDate,
    required super.endDate,
    required super.days,
    required super.reason,
    required super.status,
    required super.createdAt,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id']?.toString() ?? '',
      type: LeaveType.fromString(json['type']?.toString()),
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      days: (json['days'] as num?)?.toInt() ?? 1,
      reason: json['reason']?.toString() ?? '',
      status: LeaveStatus.fromString(json['status']?.toString()),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.label,
      'startDate': startDate,
      'endDate': endDate,
      'reason': reason,
    };
  }

  factory LeaveRequestModel.fromDbMap(Map<String, dynamic> map) {
    return LeaveRequestModel(
      id: map['id']?.toString() ?? '',
      type: LeaveType.fromString(map['type']?.toString()),
      startDate: map['startDate']?.toString() ?? '',
      endDate: map['endDate']?.toString() ?? '',
      days: (map['days'] as num?)?.toInt() ?? 1,
      reason: map['reason']?.toString() ?? '',
      status: LeaveStatus.fromString(map['status']?.toString()),
      createdAt: DateTime.parse(map['createdAt'].toString()),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'type': type.label,
      'startDate': startDate,
      'endDate': endDate,
      'days': days,
      'reason': reason,
      'status': status.label,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  factory LeaveRequestModel.fromEntity(LeaveRequest entity) {
    return LeaveRequestModel(
      id: entity.id,
      type: entity.type,
      startDate: entity.startDate,
      endDate: entity.endDate,
      days: entity.days,
      reason: entity.reason,
      status: entity.status,
      createdAt: entity.createdAt,
    );
  }
}
