import 'sync_result.dart';

/// Contract for the background/foreground offline synchronization engine.
abstract interface class SyncEngine {
  /// Processes all pending events in SQLite sequentially.
  /// Guarded by a concurrency lock.
  Future<SyncResult> synchronize({String trigger = 'manual'});

  /// Returns the current count of pending events waiting to sync.
  Future<int> getPendingCount();

  /// Whether a synchronization run is actively in progress.
  bool get isSyncing;
}
