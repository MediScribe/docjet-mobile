import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';

/// Concrete implementation of [NetworkInfo] using the `connectivity_plus` package.
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;

  /// Creates an instance of [NetworkInfoImpl].
  ///
  /// Requires a [Connectivity] instance, typically obtained from the
  /// `connectivity_plus` package and registered in the DI container.
  NetworkInfoImpl(this.connectivity);

  /// Checks the current network connectivity status.
  ///
  /// Returns `true` if the device has any connection other than `none`,
  /// `false` otherwise.
  @override
  Future<bool> get isConnected async {
    final results = await connectivity.checkConnectivity();
    // Check against all possible results from connectivity_plus v6.0.0+
    // Any result other than 'none' indicates some form of connectivity.
    // If the list contains anything other than 'none', we are connected.
    // If the list is empty or only contains 'none', we are not connected.
    return results.any((result) => result != ConnectivityResult.none);
  }
}
