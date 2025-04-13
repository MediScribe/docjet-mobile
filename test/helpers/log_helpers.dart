import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:logger/logger.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reset all log levels to default before/after tests
void resetLogLevels() {
  // Reset any specific levels set
  LoggerFactory.resetLogLevels();
  // Explicitly set default back to a known state (e.g., trace for debug)
  // Match the default used in log_helpers_test.dart setup
  LoggerFactory.setDefaultLogLevel(Level.trace);
}

/// Runs a test function with debug logs temporarily enabled for a specific type.
/// Ensures log levels are reset afterwards.
///
/// Example:
/// ```dart
/// testWidgets('My widget logs debug info', (tester) async {
///   await withDebugLogsFor(MyWidget, () async {
///     // Your test code here that expects debug logs from MyWidget
///   });
/// });
/// ```
Future<void> withDebugLogsFor(Type type, Future<void> Function() testFn) async {
  final originalLevel = LoggerFactory.getCurrentLevel(type);
  try {
    LoggerFactory.setLogLevel(type, Level.debug);
    await testFn();
  } finally {
    // Restore original level for the specific type,
    // rather than resetting all levels globally.
    LoggerFactory.setLogLevel(type, originalLevel);
  }
}

/// Runs a test function with a specific log level temporarily enabled for a type.
/// Ensures the log level for that type is reset afterwards.
Future<void> withLogLevelFor(
  Type type,
  Level level,
  Future<void> Function() testFn,
) async {
  final originalLevel = LoggerFactory.getCurrentLevel(type);
  try {
    LoggerFactory.setLogLevel(type, level);
    await testFn();
  } finally {
    LoggerFactory.setLogLevel(type, originalLevel);
  }
}
