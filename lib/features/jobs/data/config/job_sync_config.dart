/// Configuration constants for job synchronization behavior.
library;

import 'dart:math' show pow;

/// Maximum number of retry attempts for a failed sync operation.
const int maxRetryAttempts = 5;

/// Base duration for exponential backoff calculation between retries.
/// The actual delay will be: min(base * 2^(retryCount), maxBackoffDuration).
const Duration retryBackoffBase = Duration(minutes: 1);

/// Maximum backoff duration, to cap exponential growth for high retry counts.
const Duration maxBackoffDuration = Duration(hours: 1);

/// Interval at which the periodic sync trigger attempts to run.
const Duration syncInterval = Duration(seconds: 15);

/// Calculates the backoff duration for a specific retry count.
///
/// Uses an exponential backoff formula: min(base * 2^retryCount, maxBackoff)
///
/// Examples:
/// - For retry 0: 1 min * 2^0 = 1 min
/// - For retry 1: 1 min * 2^1 = 2 min
/// - For retry 2: 1 min * 2^2 = 4 min
/// - For retry 3: 1 min * 2^3 = 8 min
/// - For retry 4: 1 min * 2^4 = 16 min
///
/// For high retry counts, the duration is capped at maxBackoffDuration (1 hour).
Duration calculateRetryBackoff(int retryCount) {
  final backoffMultiplier = pow(2, retryCount).toInt();
  final calculatedBackoff = Duration(
    microseconds: retryBackoffBase.inMicroseconds * backoffMultiplier,
  );

  // Apply cap to prevent excessive waiting
  return calculatedBackoff.inMicroseconds > maxBackoffDuration.inMicroseconds
      ? maxBackoffDuration
      : calculatedBackoff;
}
