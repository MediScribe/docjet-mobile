/// Abstract interface for checking network connectivity.
abstract class NetworkInfo {
  /// Checks if the device is currently connected to the internet.
  /// Returns true if connected, false otherwise.
  Future<bool> get isConnected;

  /// Stream that emits the connectivity status whenever it changes.
  ///
  /// Emits `true` when connectivity is gained (online).
  /// Emits `false` when connectivity is lost (offline).
  /// Uses `distinct()` internally, so it only emits when the boolean state changes.
  Stream<bool> get onConnectivityChanged;

  // TODO: Implement concrete version using connectivity_plus or similar package.
}
