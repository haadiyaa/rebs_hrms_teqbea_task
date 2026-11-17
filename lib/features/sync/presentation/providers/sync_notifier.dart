import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/data_providers.dart';
import '../../../attendance/presentation/providers/attendance_notifier.dart';
import '../../data/sync_engine_impl.dart';
import '../../domain/sync_engine.dart';
import '../../domain/sync_result.dart';
import 'sync_state.dart';

/// Provider for SyncEngine instance.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final attendanceRepo = ref.watch(attendanceRepositoryProvider);
  return SyncEngineImpl(attendanceRepository: attendanceRepo);
});

/// Riverpod Notifier coordinating sync lifecycle, connectivity triggers, and UI state.
final syncNotifierProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);

class SyncNotifier extends Notifier<SyncState> {
  SyncEngine get _syncEngine => ref.read(syncEngineProvider);
  StreamSubscription? _connectivitySubscription;

  @override
  SyncState build() {
    _initConnectivityListener();
    Future.microtask(() => refreshPendingCount());

    ref.onDispose(() {
      _connectivitySubscription?.cancel();
    });

    return const SyncState();
  }

  /// Listens to network connectivity events and automatically triggers sync when online.
  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final bool isOnline =
            results.any((result) => result != ConnectivityResult.none);
        if (isOnline && state.pendingCount > 0 && !state.isSyncing) {
          triggerSync(trigger: 'connectivity_restored');
        }
      },
    );
  }

  /// Refreshes the pending queue count from SQLite.
  Future<void> refreshPendingCount() async {
    final count = await _syncEngine.getPendingCount();
    state = state.copyWith(pendingCount: count);
  }

  /// Convenience method to force trigger manual sync.
  Future<SyncResult> syncNow() => triggerSync(trigger: 'manual');

  /// Triggers a synchronization run.
  Future<SyncResult> triggerSync({String trigger = 'manual'}) async {
    if (state.isSyncing) {
      return SyncResult.inProgress();
    }

    state = state.copyWith(isSyncing: true, clearError: true);

    final result = await _syncEngine.synchronize(trigger: trigger);
    final remainingCount = await _syncEngine.getPendingCount();

    state = state.copyWith(
      isSyncing: false,
      pendingCount: remainingCount,
      lastSyncTime: DateTime.now(),
      lastSyncResult: result,
      errorMessage: result.wasInterrupted ? result.interruptionReason : null,
    );

    // If changes occurred, refresh dashboard attendance records so status chips update
    if (result.hasChanges) {
      await ref
          .read(attendanceNotifierProvider.notifier)
          .loadDashboardAttendance(forceRefresh: true);
    }

    return result;
  }
}
