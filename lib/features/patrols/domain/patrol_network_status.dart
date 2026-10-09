/// ISP: small abstraction exposing current connectivity and connectivity changes to sync coordination.
abstract interface class PatrolNetworkStatusProvider {
  /// Whether the device currently has network connectivity.
  Future<bool> get isOnline;

  /// Emits connectivity changes for consumers that monitor network state.
  Stream<bool> get onlineChanges;
}
