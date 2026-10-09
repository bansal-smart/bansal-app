import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { online, offline }

/// Emits [ConnectivityStatus] in real-time by listening to connectivity_plus.
class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;

  Stream<ConnectivityStatus> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_toStatus);

  Future<ConnectivityStatus> get currentStatus =>
      _connectivity.checkConnectivity().then(_toStatus);

  static ConnectivityStatus _toStatus(List<ConnectivityResult> results) {
    if (results.isEmpty) return ConnectivityStatus.offline;
    return results.any((r) => r != ConnectivityResult.none)
        ? ConnectivityStatus.online
        : ConnectivityStatus.offline;
  }
}

// ── Riverpod providers ─────────────────────────────────────────────────────────

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(Connectivity());
});

/// StreamProvider — auto-updates on every network change.
final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((
  ref,
) async* {
  final service = ref.read(connectivityServiceProvider);
  // Emit current status immediately before streaming changes
  yield await service.currentStatus;
  yield* service.onStatusChange;
});

/// Convenience bool: true when online (or status unknown).
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider);
  return status.when(
    data: (s) => s == ConnectivityStatus.online,
    loading: () => true, // assume online until we know
    error: (_, _) => true,
  );
});
