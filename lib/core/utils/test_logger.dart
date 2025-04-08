import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'logger.dart';

/// A utility class for controlling logging output during tests.
///
/// Usage:
/// ```dart
/// void main() {
///   // Disable all logging at the beginning of your test
///   TestLogger.disableLogging();
///
///   // Enable logging for a specific tag in a specific test
///   test('Test with logging', () {
///     TestLogger.enableLoggingForTag('[AUDIO]');
///     // Now only logs with the [AUDIO] tag will be visible
///     // Other logs remain suppressed
///   });
///
///   // Make sure to reset logging at the end of tests
///   tearDownAll(() => TestLogger.resetLogging());
/// }
/// ```
class TestLogger {
  // Store the original print function for later restoration
  static final _originalPrintCallback = debugPrint;
  static bool _isFiltering = false;

  /// Completely disables all logging for tests
  static void disableLogging() {
    // Disable the main app logger
    LogConfig.enableLogging = false;
    LogConfig.enabledTags.clear();

    // Also capture and filter debugPrint calls
    debugPrint = _filteredPrint;
  }

  /// Enables logging only for messages that start with the specified tag.
  /// This works for both the logger.d() calls and debugPrint() calls.
  static void enableLoggingForTag(String tag) {
    // Enable this tag in the main app logger
    LogConfig.enableLogging = false; // Disable all logs
    LogConfig.enabledTags.add(tag); // But allow those with the specified tag

    // Also enable for debugPrint calls
    debugPrint = _filteredPrint;
  }

  /// Enables logging for multiple tags at once.
  /// Only logs with these tags will be visible.
  static void enableLoggingForTags(List<String> tags) {
    LogConfig.enableLogging = false;
    LogConfig.enabledTags.addAll(tags);

    debugPrint = _filteredPrint;
  }

  /// Enables ALL logging, regardless of tags.
  /// This is useful when you need to see everything.
  static void enableAllLogging() {
    LogConfig.enableLogging = true;
    LogConfig.enabledTags.clear();

    // Restore original debugPrint to show all logs
    debugPrint = _originalPrintCallback;
  }

  /// Resets logging to default behavior (all logs enabled).
  static void resetLogging() {
    // Reset the app logger
    LogConfig.reset();

    // Restore the original debugPrint
    debugPrint = _originalPrintCallback;
  }

  /// Custom print function that filters based on tag.
  static void _filteredPrint(String? message, {int? wrapWidth}) {
    // Guard against infinite recursion
    if (_isFiltering) return;
    if (message == null) return;

    _isFiltering = true;
    try {
      // Check if the message starts with any of the enabled tags
      if (LogConfig.enabledTags.isNotEmpty) {
        for (final tag in LogConfig.enabledTags) {
          if (message.startsWith(tag)) {
            // Use print directly to avoid recursion
            print(message);
            break;
          }
        }
      }
      // If no tags are enabled or message doesn't match any, suppress output
    } finally {
      _isFiltering = false;
    }
  }
}
