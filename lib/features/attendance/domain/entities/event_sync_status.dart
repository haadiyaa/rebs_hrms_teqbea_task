/// Synchronization state of an attendance event.
enum EventSyncStatus {
  pending('Pending Sync'),
  synced('Synced'),
  rejected('Rejected');

  final String label;
  const EventSyncStatus(this.label);

  static EventSyncStatus fromString(String? val) {
    if (val == null) return EventSyncStatus.pending;
    for (final s in EventSyncStatus.values) {
      if (s.name.toLowerCase() == val.toLowerCase() ||
          s.label.toLowerCase() == val.toLowerCase()) {
        return s;
      }
    }
    return EventSyncStatus.pending;
  }
}
