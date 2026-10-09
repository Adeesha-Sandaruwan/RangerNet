import 'package:connectivity_plus/connectivity_plus.dart';

import '../domain/patrol_network_status.dart';

/// Adapts connectivity_plus network signals to the patrol status port. DIP/LSP: callers consume PatrolNetworkStatusProvider rather than the plugin.
class ConnectivityPatrolNetworkStatusProvider
    implements PatrolNetworkStatusProvider {
  /// Creates the adapter with an injectable connectivity source.
  ConnectivityPatrolNetworkStatusProvider({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  /// Platform connectivity source for current and changing status.
  final Connectivity _connectivity;

  /// Whether the plugin currently reports any network transport.
  @override
  Future<bool> get isOnline async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  /// Emits whether any network transport is reported when connectivity changes.
  @override
  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_hasNetwork);

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
