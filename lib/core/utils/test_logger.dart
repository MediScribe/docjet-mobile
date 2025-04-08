import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'logger.dart';

/// Log levels for filtering test output
enum LogLevel {
  none, // No logs
  error, // Only errors
  warn, // Errors and warnings
  info, // Standard info level
  debug, // Debug information
  all, // Everything
}

/// A utility class for controlling logging output during tests.
///
/// Usage:
/// ```dart
/// void main() {
///   // Use environment variables for global control:
///   // TEST_LOG_LEVEL=error flutter test
///   // TEST_LOG_TAGS=AUDIO,NETWORK flutter test
///
///   // Or control directly in test:
///   test('Test with logging', () {
///     TestLogger.enableLoggingForTag('[AUDIO]');
///     // Now only logs with the [AUDIO] tag will be visible
///     // Other logs remain suppressed
///   });
/// }
/// ```
class TestLogger {
  // Store the original print function for later restoration
  static final _originalPrintCallback = debugPrint;
  static bool _isFiltering = false;

  // Current log level
  static LogLevel _logLevel = LogLevel.none;

  /// Get the current log level
  static LogLevel get logLevel => _logLevel;

  /// Check if an environment variable is set and return its value
  static String? _getEnv(String name) {
    return Platform.environment[name];
  }

  /// Initialize logging based on environment variables
  /// TEST_LOG_LEVEL=none|error|warn|info|debug|all
  /// TEST_LOG_TAGS=TAG1,TAG2,TAG3
  static void initFromEnvironment() {
    // Start with clean state
    disableLogging();

    // Get tags from environment (tags take precedence over level)
    final tagsStr = _getEnv('TEST_LOG_TAGS');
    if (tagsStr != null && tagsStr.isNotEmpty) {
      final tags =
          tagsStr
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList();

      if (tags.isNotEmpty) {
        // Reset any previous log level settings
        _logLevel = LogLevel.none;
        // Use the tag filtering instead
        enableLoggingForTags(tags);
        return; // Tags take precedence over level
      }
    }

    // Get log level from environment
    final levelStr = _getEnv('TEST_LOG_LEVEL')?.toLowerCase();
    if (levelStr != null) {
      switch (levelStr) {
        case 'none':
          _logLevel = LogLevel.none;
          break;
        case 'error':
          _logLevel = LogLevel.error;
          break;
        case 'warn':
          _logLevel = LogLevel.warn;
          break;
        case 'info':
          _logLevel = LogLevel.info;
          break;
        case 'debug':
          _logLevel = LogLevel.debug;
          break;
        case 'all':
          _logLevel = LogLevel.all;
          break;
      }
    }

    // Apply the log level
    if (_logLevel == LogLevel.none) {
      disableLogging();
    } else if (_logLevel == LogLevel.all) {
      enableAllLogging();
    } else {
      // Set up filtering based on log level
      LogConfig.enableLogging = false;
      LogConfig.enabledTags.clear();
      debugPrint = _filteredPrint;

      // For logger.d calls, configure the LogConfig based on level
      switch (_logLevel) {
        case LogLevel.error:
          LogConfig.enabledTags.addAll(['[ERROR]', 'ERROR']);
          break;
        case LogLevel.warn:
          LogConfig.enabledTags.addAll(['[ERROR]', 'ERROR', '[WARN]', 'WARN']);
          break;
        case LogLevel.info:
          LogConfig.enabledTags.addAll([
            '[ERROR]',
            'ERROR',
            '[WARN]',
            'WARN',
            '[INFO]',
            'INFO',
          ]);
          break;
        case LogLevel.debug:
          LogConfig.enabledTags.addAll([
            '[ERROR]',
            'ERROR',
            '[WARN]',
            'WARN',
            '[INFO]',
            'INFO',
            '[DEBUG]',
            'DEBUG',
          ]);
          break;
        default:
          break;
      }
    }
  }

  /// Completely disables all logging for tests
  static void disableLogging() {
    // Disable the main app logger
    LogConfig.enableLogging = false;
    LogConfig.enabledTags.clear();
    _logLevel = LogLevel.none;

    // Also capture and filter debugPrint calls
    debugPrint = _filteredPrint;
  }

  /// Enables logging only for messages that start with the specified tag.
  /// This works for both the logger.d() calls and debugPrint() calls.
  static void enableLoggingForTag(String tag) {
    // Normalize the tag format
    final normalizedTag = tag.startsWith('[') ? tag : '[$tag]';
    final unbracketed = normalizedTag.substring(1, normalizedTag.length - 1);

    // Enable this tag in the main app logger
    LogConfig.enableLogging = false; // Disable all logs
    LogConfig.enabledTags.clear();
    LogConfig.enabledTags.add(normalizedTag); // Add bracketed version
    LogConfig.enabledTags.add(unbracketed); // Add unbracketed version

    // Also enable for debugPrint calls
    debugPrint = _filteredPrint;
  }

  /// Enables logging for multiple tags at once.
  /// Only logs with these tags will be visible.
  static void enableLoggingForTags(List<String> tags) {
    LogConfig.enableLogging = false;
    LogConfig.enabledTags.clear();

    // Process each tag to add both bracketed and unbracketed versions
    for (final tag in tags) {
      final normalizedTag = tag.startsWith('[') ? tag : '[$tag]';
      final unbracketed = normalizedTag.substring(1, normalizedTag.length - 1);

      LogConfig.enabledTags.add(normalizedTag);
      LogConfig.enabledTags.add(unbracketed);
    }

    debugPrint = _filteredPrint;
  }

  /// Sets the log level to filter messages by severity
  static void setLogLevel(LogLevel level) {
    _logLevel = level;

    if (level == LogLevel.none) {
      disableLogging();
    } else if (level == LogLevel.all) {
      enableAllLogging();
    } else {
      LogConfig.enableLogging = false;
      LogConfig.enabledTags.clear();

      // Add tags based on level
      switch (level) {
        case LogLevel.error:
          LogConfig.enabledTags.addAll(['[ERROR]', 'ERROR']);
          break;
        case LogLevel.warn:
          LogConfig.enabledTags.addAll(['[ERROR]', 'ERROR', '[WARN]', 'WARN']);
          break;
        case LogLevel.info:
          LogConfig.enabledTags.addAll([
            '[ERROR]',
            'ERROR',
            '[WARN]',
            'WARN',
            '[INFO]',
            'INFO',
          ]);
          break;
        case LogLevel.debug:
          LogConfig.enabledTags.addAll([
            '[ERROR]',
            'ERROR',
            '[WARN]',
            'WARN',
            '[INFO]',
            'INFO',
            '[DEBUG]',
            'DEBUG',
          ]);
          break;
        default:
          break;
      }

      debugPrint = _filteredPrint;
    }
  }

  /// Enables ALL logging, regardless of tags.
  /// This is useful when you need to see everything.
  static void enableAllLogging() {
    LogConfig.enableLogging = true;
    LogConfig.enabledTags.clear();
    _logLevel = LogLevel.all;

    // Restore original debugPrint to show all logs
    debugPrint = _originalPrintCallback;
  }

  /// Resets logging to default behavior (all logs enabled).
  static void resetLogging() {
    // Reset the app logger
    LogConfig.reset();
    _logLevel = LogLevel.all;

    // Restore the original debugPrint
    debugPrint = _originalPrintCallback;
  }

  /// Convenience method for setting up logging in test files.
  /// Use this with setUpAll() in your test files.
  ///
  /// ```dart
  /// void main() {
  ///   setUpAll(TestLogger.setupTestFile); // Default error level
  ///   // OR with custom level:
  ///   // setUpAll(() => TestLogger.setupTestFile(LogLevel.debug));
  ///
  ///   // Your tests...
  ///
  ///   tearDownAll(TestLogger.tearDownTestFile);
  /// }
  /// ```
  static void setupTestFile([LogLevel level = LogLevel.error]) {
    setLogLevel(level);
  }

  /// Convenience method for cleaning up logging after tests.
  /// Use this with tearDownAll() in your test files.
  ///
  /// ```dart
  /// void main() {
  ///   setUpAll(TestLogger.setupTestFile);
  ///
  ///   // Your tests...
  ///
  ///   tearDownAll(TestLogger.tearDownTestFile);
  /// }
  /// ```
  static void tearDownTestFile() {
    resetLogging();
  }

  /// Custom print function that filters based on tag.
  static void _filteredPrint(String? message, {int? wrapWidth}) {
    // Guard against infinite recursion
    if (_isFiltering) return;
    if (message == null) return;

    _isFiltering = true;
    try {
      bool shouldPrint = false;

      // Rule 1: If all logging is enabled, print everything
      if (LogConfig.enableLogging) {
        shouldPrint = true;
      }
      // Rule 2: If specific tags are enabled, only print those
      else if (LogConfig.enabledTags.isNotEmpty) {
        for (final tag in LogConfig.enabledTags) {
          if (message.contains(tag)) {
            shouldPrint = true;
            break;
          }
        }
      }

      // Only print if we should
      if (shouldPrint) {
        // Use print directly to avoid recursion
        print(message);
      }
    } finally {
      _isFiltering = false;
    }
  }
}
