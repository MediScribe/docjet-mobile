import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:flutter/foundation.dart'; // Import for kDebugMode and @visibleForTesting
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logger

/// Concrete implementation of [NetworkInfo] using the `connectivity_plus` package.
///
/// This implementation also integrates with [AuthEventBus] to fire
/// [AuthEvent.offlineDetected] and [AuthEvent.onlineRestored] events upon
/// connectivity transitions.
class NetworkInfoImpl implements NetworkInfo {
  // Logger setup
  static final String _tag = logTag(NetworkInfoImpl);
  final Logger _logger = LoggerFactory.getLogger(NetworkInfoImpl);

  final Connectivity connectivity;
  final AuthEventBus authEventBus;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool? _lastKnownStatus; // Store the last known status
  // Controller to broadcast the distinct boolean status
  final StreamController<bool> _statusStreamController =
      StreamController<bool>.broadcast();

  // --- TEMP DEBUG PROBE --------------------------------------------------
  // Logs every raw event with a precise timestamp to hunt simulator-only
  // NWPathMonitor glitches. Remove once the issue is understood.
  // TODO(HARD-BOB): Delete _debugRawEvent before shipping to prod.
  void _debugRawEvent(List<ConnectivityResult> results) {
    if (!kDebugMode) return; // Only in debug mode
    final stamp = DateTime.now().toIso8601String();
    _logger.f('$_tag [TMP-RAW] $stamp -> $results');
  }
  // -----------------------------------------------------------------------

  /// Creates an instance of [NetworkInfoImpl].
  ///
  /// Requires a [Connectivity] instance and an [AuthEventBus].
  /// Immediately starts checking and listening for connectivity changes.
  NetworkInfoImpl(this.connectivity, this.authEventBus) {
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
      _logger.i('$_tag Initial connectivity status: $_lastKnownStatus');

      // NEW: If the app starts without connectivity, immediately propagate the
      // offline state. This ensures features like the OfflineBanner are shown
      // right away after a cold-start in airplane mode.
      if (_lastKnownStatus == false) {
        _logger.i(
          '$_tag Initial status is OFFLINE → firing AuthEvent.offlineDetected',
        );
        authEventBus.add(AuthEvent.offlineDetected);

        // Emit the value on our broadcast stream. NOTE: because this is a
        // `broadcast()` controller the value is **not** replayed to
        // subscribers that attach later; those consumers should instead call
        // `isConnected` to obtain the snapshot after subscription.
        _statusStreamController.add(false);
      }

      // Start listening to changes *after* the initial check
      _connectivitySubscription = connectivity.onConnectivityChanged.listen(
        (results) {
          // --- HARDCORE DEBUG LOG ---
          _debugRawEvent(results); // Temp probe (see method)
          _logger.f('$_tag Raw connectivity event received: $results');
          // --- END HARDCORE DEBUG LOG ---
          final currentStatus = results.any(
            (result) => result != ConnectivityResult.none,
          );

          // Only process if status actually changed
          if (currentStatus != _lastKnownStatus) {
            _logger.i(
              '$_tag Connectivity changed: $_lastKnownStatus -> $currentStatus',
            );
            // Fire event BEFORE updating state and BEFORE emitting to stream
            if (_lastKnownStatus != null) {
              // Avoid firing on first determination
              if (!currentStatus) {
                // --- HARDCORE DEBUG LOG ---
                _logger.f('$_tag !!! FIRING AuthEvent.offlineDetected !!!');
                // --- END HARDCORE DEBUG LOG ---
                _logger.i('$_tag Firing AuthEvent.offlineDetected');
                authEventBus.add(AuthEvent.offlineDetected);
              } else {
                // --- HARDCORE DEBUG LOG ---
                _logger.f('$_tag !!! FIRING AuthEvent.onlineRestored !!!');
                // --- END HARDCORE DEBUG LOG ---
                _logger.i('$_tag Firing AuthEvent.onlineRestored');
                authEventBus.add(AuthEvent.onlineRestored);
              }
            }

            // Update the internal state
            _lastKnownStatus = currentStatus;
            // Emit the change to the status stream
            _statusStreamController.add(currentStatus);
          } else {
            // Log ignored event if needed for debugging
            if (kDebugMode) {
              _logger.t('$_tag Connectivity status unchanged: $currentStatus');
            }
          }
        },
        onError: (error, stackTrace) {
          // Add stack trace for better logging
          // Handle potential errors from the connectivity stream
          _statusStreamController.addError(error, stackTrace);
          _logger.e(
            '$_tag Error in connectivity stream: $error',
            error: error,
            stackTrace: stackTrace,
          );
        },
      );
    } catch (e, stackTrace) {
      // Handle errors during initial check
      _lastKnownStatus = false; // Indicate false state on error
      _statusStreamController.addError(e, stackTrace);
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
  /// Returns `false` if an error occurs during the check.
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
      // Keep stacktrace for logging
      _logger.e(
        // Use logger, not print
        '$_tag Error during isConnected check: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // In debug mode, rethrow to make errors more visible
      if (kDebugMode) {
        rethrow;
      }
      return false; // Return false on error
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
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _statusStreamController.close();
    _logger.i('$_tag NetworkInfoImpl disposed.'); // Use logger, not print
  }
}
