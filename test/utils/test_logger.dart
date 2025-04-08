import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A utility class for controlling logging output during tests.
class TestLogger {
  // Store the original print function for later restoration
  static final _originalPrintCallback = debugPrint;
  static String? _enabledTag;
  static bool _isFiltering = false;
  static bool _isCompletelyDisabled = false;

  /// Completely suppresses all logging for tests
  static void disableLogging() {
    _isCompletelyDisabled = true;
    debugPrint = _filteredPrint;
  }

  /// Enables logging only for messages that start with the specified tag.
  static void enableLoggingForTag(String tag) {
    _enabledTag = tag;
    _isCompletelyDisabled = false;
    debugPrint = _filteredPrint;
  }

  /// Resets logging to default behavior (all logs enabled).
  static void resetLogging() {
    _enabledTag = null;
    _isCompletelyDisabled = false;
    debugPrint = _originalPrintCallback;
  }

  /// Setup for tests (disables logging and ensures Flutter binding).
  static void setupForTests() {
    TestWidgetsFlutterBinding.ensureInitialized();
    disableLogging();
  }

  /// Cleanup after tests.
  static void teardownAfterTests() {
    resetLogging();
  }

  /// Custom print function that filters based on tag.
  static void _filteredPrint(String? message, {int? wrapWidth}) {
    // Guard against infinite recursion
    if (_isFiltering) return;

    if (message == null) return;

    // If logging is completely disabled, just return
    if (_isCompletelyDisabled) return;

    _isFiltering = true;
    try {
      if (_enabledTag != null && message.startsWith(_enabledTag!)) {
        // Use print directly instead of calling debugPrint to avoid recursion
        print(message);
      }
      // If no tag specified or message doesn't match tag, suppress output
    } finally {
      _isFiltering = false;
    }
  }
}
