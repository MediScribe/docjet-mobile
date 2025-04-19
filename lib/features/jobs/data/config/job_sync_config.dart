/// Configuration constants for job synchronization behavior.
library;

/// Maximum number of retry attempts for a failed sync operation.
const int maxRetryAttempts = 5;

/// Base duration for exponential backoff calculation between retries.
/// The actual delay will be: base * 2^(retryCount).
const Duration retryBackoffBase = Duration(minutes: 1);

/// Interval at which the periodic sync trigger attempts to run.
const Duration syncInterval = Duration(seconds: 15);
