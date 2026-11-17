/// Result summary returned by a sync engine run.
class SyncResult {
  final int totalPending;
  final int syncedCount;
  final int rejectedCount;
  final bool wasInterrupted;
  final String? interruptionReason;
  final bool alreadyInProgress;

  const SyncResult({
    this.totalPending = 0,
    this.syncedCount = 0,
    this.rejectedCount = 0,
    this.wasInterrupted = false,
    this.interruptionReason,
    this.alreadyInProgress = false,
  });

  factory SyncResult.inProgress() => const SyncResult(alreadyInProgress: true);

  bool get hasChanges => syncedCount > 0 || rejectedCount > 0;

  @override
  String toString() =>
      'SyncResult(synced: $syncedCount, rejected: $rejectedCount, pendingLeft: ${totalPending - syncedCount - rejectedCount}, interrupted: $wasInterrupted)';
}
