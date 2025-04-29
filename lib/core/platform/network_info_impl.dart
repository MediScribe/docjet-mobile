import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:meta/meta.dart'; // For @visibleForTesting
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logger

/// Concrete implementation of [NetworkInfo] using the `connectivity_plus` package.
class NetworkInfoImpl implements NetworkInfo {
  // Logger setup
  static final String _tag = logTag(NetworkInfoImpl);
  final Logger _logger = LoggerFactory.getLogger(NetworkInfoImpl);

  final Connectivity connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool? _lastKnownStatus; // Store the last known status
  // Controller to broadcast the distinct boolean status
  final StreamController<bool> _statusStreamController =
      StreamController<bool>.broadcast();

  /// Creates an instance of [NetworkInfoImpl].
  ///
  /// Requires a [Connectivity] instance, typically obtained from the
  /// `connectivity_plus` package and registered in the DI container.
  /// Immediately starts checking and listening for connectivity changes.
  NetworkInfoImpl(this.connectivity) {
    // Call initialize but don't await it in the constructor
    _initialize();
  }

  /// Initializes the network info service by checking the initial state
  /// and setting up the listener for changes.
  Future<void> _initialize() async {
    try {
      final initialResults = await connectivity.checkConnectivity();
      _lastKnownStatus = initialResults.any(
        (result) => result != ConnectivityResult.none,
      );
      // Emit the initial status if the stream has listeners
      if (_statusStreamController.hasListener) {
        _statusStreamController.add(_lastKnownStatus!);
      }

      // Start listening to changes *after* the initial check
      _connectivitySubscription = connectivity.onConnectivityChanged.listen(
        (results) {
          final currentStatus = results.any(
            (result) => result != ConnectivityResult.none,
          );
          // Only add to stream if status changed
          if (currentStatus != _lastKnownStatus) {
            _lastKnownStatus = currentStatus;
            _statusStreamController.add(currentStatus);
          }
        },
        onError: (error) {
          // Handle potential errors from the connectivity stream
          _statusStreamController.addError(error);
          _logger.e('$_tag Error in connectivity stream: $error');
        },
      );
    } catch (e, stackTrace) {
      // Handle errors during initial check
      _lastKnownStatus = false; // Indicate false state on error
      _statusStreamController.addError(e);
      _logger.e(
        '$_tag Error during NetworkInfoImpl initialization: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Checks the current network connectivity status.
  ///
  /// Returns the last known status if initialized, otherwise performs an async check.
  /// Returns `null` if initialization failed and no status is known.
  @override
  Future<bool> get isConnected async {
    // Return last known status if available (most common case after init)
    if (_lastKnownStatus != null) {
      return _lastKnownStatus!;
    }
    // Fallback to live check if init hasn't completed or failed
    try {
      final results = await connectivity.checkConnectivity();
      final currentStatus = results.any(
        (result) => result != ConnectivityResult.none,
      );
      _lastKnownStatus = currentStatus; // Update last known status
      return currentStatus;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Error during isConnected check: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return false; // Or rethrow / return null depending on desired behavior on error
    }
  }

  /// Stream that emits the connectivity status (`true` for online, `false` for offline)
  /// whenever it changes.
  ///
  /// Only emits distinct values (when the status actually changes).
  @override
  Stream<bool> get onConnectivityChanged {
    // Return the stream from our broadcast controller
    // It handles distinct emissions internally now via the _initialize listener logic
    return _statusStreamController.stream;
  }

  /// Disposes resources used by the [NetworkInfoImpl].
  ///
  /// This should be called when the service is no longer needed, typically
  /// managed by the DI container's disposal mechanism.
  @visibleForTesting // Allow calling in tests
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _statusStreamController.close();
    _logger.i('$_tag NetworkInfoImpl disposed.');
  }
}
