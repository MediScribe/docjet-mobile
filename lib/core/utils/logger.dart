import 'package:logger/logger.dart';

/// Controls whether logs are shown globally
///
/// ## Using Tags for Filtered Logging
///
/// To make debugging easier, especially in tests, it's recommended to prefix
/// log messages with a consistent tag:
///
/// ```dart
/// // For audio-related components
/// logger.d('[AUDIO] Processing file: $filename');
///
/// // For network-related components
/// logger.d('[NET] Request started: $url');
/// ```
///
/// This allows selective enabling of logs using [LogConfig.enableTag]:
///
/// ```dart
/// // Only show audio-related logs
/// LogConfig.enableLogging = false; // Disable all logs
/// LogConfig.enableTag('[AUDIO]');  // But allow those with [AUDIO] tag
/// ```
///
/// See test/utils/test_logger.dart for utilities to manage logging in tests.
class LogConfig {
  /// Set to false to disable all logging output
  static bool enableLogging = true;

  /// List of tag prefixes that should show logs even when logging is disabled
  static final Set<String> enabledTags = {};

  /// Enable logs for a specific tag
  static void enableTag(String tag) {
    enabledTags.add(tag);
  }

  /// Disable logs for a specific tag
  static void disableTag(String tag) {
    enabledTags.remove(tag);
  }

  /// Reset to default (all logs enabled)
  static void reset() {
    enableLogging = true;
    enabledTags.clear();
  }
}

/// Custom log filter that can be globally toggled
class ToggleableLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // If logging is enabled globally, allow all logs
    if (LogConfig.enableLogging) {
      return true;
    }

    // If logging is disabled, only allow logs with enabled tags
    if (LogConfig.enabledTags.isNotEmpty) {
      String message = event.message.toString();
      for (final tag in LogConfig.enabledTags) {
        if (message.startsWith(tag)) {
          return true;
        }
      }
    }

    // Otherwise, suppress the log
    return false;
  }
}

final logger = Logger(
  filter: ToggleableLogFilter(),
  printer: PrettyPrinter(
    methodCount: 1, // number of method calls to be displayed
    errorMethodCount: 8, // number of method calls if stacktrace is provided
    lineLength: 120, // width of the output
    colors: true, // Colorful log messages
    printEmojis: true, // Print an emoji for each log message
    dateTimeFormat: DateTimeFormat.none, // Hide timestamp
  ),
);

// You can create different loggers for different levels if needed,
// e.g., one for verbose debug, one for important info.
// final verboseLogger = Logger(printer: PrettyPrinter(methodCount: 2));
