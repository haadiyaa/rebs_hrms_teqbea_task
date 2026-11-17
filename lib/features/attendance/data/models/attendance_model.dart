import 'dart:convert';
import '../../domain/entities/attendance_event.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/attendance_status.dart';
import '../../domain/entities/event_sync_status.dart';

/// DTO for AttendanceEvent serialization.
class AttendanceEventModel extends AttendanceEvent {
  const AttendanceEventModel({
    required super.eventId,
    required super.type,
    required super.timestamp,
    required super.latitude,
    required super.longitude,
    super.sequence = 0,
    super.status = EventSyncStatus.pending,
    super.rejectionReason,
    super.attempts = 0,
    required super.createdAt,
  });

  factory AttendanceEventModel.fromJson(Map<String, dynamic> json) {
    return AttendanceEventModel(
      eventId: json['eventId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'check_in',
      timestamp: DateTime.parse(json['timestamp'].toString()),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      status: EventSyncStatus.fromString(json['status']?.toString()),
      rejectionReason: json['rejectionReason']?.toString(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'type': type,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory AttendanceEventModel.fromDbMap(Map<String, dynamic> map) {
    return AttendanceEventModel(
      eventId: map['eventId']?.toString() ?? '',
      type: map['type']?.toString() ?? 'check_in',
      timestamp: DateTime.parse(map['timestamp'].toString()),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      sequence: (map['sequence'] as num?)?.toInt() ?? 0,
      status: EventSyncStatus.fromString(map['status']?.toString()),
      rejectionReason: map['rejectionReason']?.toString(),
      attempts: (map['attempts'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['createdAt'].toString()),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'eventId': eventId,
      'type': type,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'sequence': sequence,
      'status': status.name,
      'rejectionReason': rejectionReason,
      'attempts': attempts,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory AttendanceEventModel.fromEntity(AttendanceEvent entity) {
    return AttendanceEventModel(
      eventId: entity.eventId,
      type: entity.type,
      timestamp: entity.timestamp,
      latitude: entity.latitude,
      longitude: entity.longitude,
      sequence: entity.sequence,
      status: entity.status,
      rejectionReason: entity.rejectionReason,
      attempts: entity.attempts,
      createdAt: entity.createdAt,
    );
  }
}

/// DTO for AttendanceRecord serialization.
class AttendanceRecordModel extends AttendanceRecord {
  const AttendanceRecordModel({
    required super.date,
    super.checkIn,
    super.checkOut,
    super.status = AttendanceStatus.notCheckedIn,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    final checkInJson = json['checkIn'] as Map<String, dynamic>?;
    final checkOutJson = json['checkOut'] as Map<String, dynamic>?;

    return AttendanceRecordModel(
      date: json['date']?.toString() ?? '',
      checkIn: checkInJson != null ? AttendanceEventModel.fromJson(checkInJson) : null,
      checkOut: checkOutJson != null ? AttendanceEventModel.fromJson(checkOutJson) : null,
      status: AttendanceStatus.fromString(json['status']?.toString()),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'date': date,
      'checkInJson': checkIn != null
          ? jsonEncode((AttendanceEventModel.fromEntity(checkIn!)).toJson())
          : null,
      'checkOutJson': checkOut != null
          ? jsonEncode((AttendanceEventModel.fromEntity(checkOut!)).toJson())
          : null,
      'status': status.name,
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  factory AttendanceRecordModel.fromDbMap(Map<String, dynamic> map) {
    AttendanceEvent? inEvent;
    AttendanceEvent? outEvent;

    if (map['checkInJson'] != null) {
      try {
        final decoded = jsonDecode(map['checkInJson'] as String) as Map<String, dynamic>;
        inEvent = AttendanceEventModel.fromJson(decoded);
      } catch (_) {}
    }

    if (map['checkOutJson'] != null) {
      try {
        final decoded = jsonDecode(map['checkOutJson'] as String) as Map<String, dynamic>;
        outEvent = AttendanceEventModel.fromJson(decoded);
      } catch (_) {}
    }

    return AttendanceRecordModel(
      date: map['date']?.toString() ?? '',
      checkIn: inEvent,
      checkOut: outEvent,
      status: AttendanceStatus.fromString(map['status']?.toString()),
    );
  }
}
