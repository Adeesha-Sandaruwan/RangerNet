abstract interface class PatrolNetworkStatusProvider {
  Future<bool> get isOnline;

  Stream<bool> get onlineChanges;
}
