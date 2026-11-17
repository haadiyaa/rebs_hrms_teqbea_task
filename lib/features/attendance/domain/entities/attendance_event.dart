import 'event_sync_status.dart';

/// Represents an individual check-in or check-out event.
class AttendanceEvent {
  /// Unique identifier (UUIDv4) generated at tap time.
  /// Used for strict server-side idempotency.
  final String eventId;

  /// Type of event: 'check_in' or 'check_out'.
  final String type;

  /// When the attendance event occurred in the real world.
  final DateTime timestamp;

  /// GPS latitude captured at tap time.
  final double latitude;

  /// GPS longitude captured at tap time.
  final double longitude;

  /// Sequence number for FIFO queue processing (persisted in SQLite).
  final int sequence;

  /// Synchronization status: pending, synced, or rejected.
  final EventSyncStatus status;

  /// Reason recorded if the event was rejected by the server or validation.
  final String? rejectionReason;

  /// Number of sync attempts performed so far.
  final int attempts;

  /// When this record was created locally.
  final DateTime createdAt;

  const AttendanceEvent({
    required this.eventId,
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.sequence = 0,
    this.status = EventSyncStatus.pending,
    this.rejectionReason,
    this.attempts = 0,
    required this.createdAt,
  });

  bool get isCheckIn => type == 'check_in';
  bool get isCheckOut => type == 'check_out';
  bool get isPending => status == EventSyncStatus.pending;
  bool get isSynced => status == EventSyncStatus.synced;
  bool get isRejected => status == EventSyncStatus.rejected;

  AttendanceEvent copyWith({
    String? eventId,
    String? type,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    int? sequence,
    EventSyncStatus? status,
    String? rejectionReason,
    int? attempts,
    DateTime? createdAt,
  }) {
    return AttendanceEvent(
      eventId: eventId ?? this.eventId,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      sequence: sequence ?? this.sequence,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceEvent &&
          other.eventId == eventId &&
          other.type == type &&
          other.timestamp == timestamp &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.sequence == sequence &&
          other.status == status &&
          other.rejectionReason == rejectionReason &&
          other.attempts == attempts &&
          other.createdAt == createdAt);

  @override
  int get hashCode => Object.hash(
        eventId,
        type,
        timestamp,
        latitude,
        longitude,
        sequence,
        status,
        rejectionReason,
        attempts,
        createdAt,
      );

  @override
  String toString() =>
      'AttendanceEvent($eventId, $type, seq: $sequence, status: ${status.name})';
}
