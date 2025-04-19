/// Abstract interface for checking network connectivity.
abstract class NetworkInfo {
  /// Checks if the device is currently connected to the internet.
  /// Returns true if connected, false otherwise.
  Future<bool> get isConnected;

  // TODO: Implement concrete version using connectivity_plus or similar package.
}
