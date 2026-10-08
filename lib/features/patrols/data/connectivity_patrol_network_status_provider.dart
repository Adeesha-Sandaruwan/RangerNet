import 'package:connectivity_plus/connectivity_plus.dart';

import '../domain/patrol_network_status.dart';

class ConnectivityPatrolNetworkStatusProvider
    implements PatrolNetworkStatusProvider {
  ConnectivityPatrolNetworkStatusProvider({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isOnline async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_hasNetwork);

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
