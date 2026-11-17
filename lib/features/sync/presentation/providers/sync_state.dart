import '../../domain/sync_result.dart';

/// State of the background/manual sync engine.
class SyncState {
  final int pendingCount;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final SyncResult? lastSyncResult;
  final String? errorMessage;

  const SyncState({
    this.pendingCount = 0,
    this.isSyncing = false,
    this.lastSyncTime,
    this.lastSyncResult,
    this.errorMessage,
  });

  bool get hasPendingEvents => pendingCount > 0;

  SyncState copyWith({
    int? pendingCount,
    bool? isSyncing,
    DateTime? lastSyncTime,
    SyncResult? lastSyncResult,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastSyncResult: lastSyncResult ?? this.lastSyncResult,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
