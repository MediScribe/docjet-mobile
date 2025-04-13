/// LOGGING TEST UTILITIES
///
/// Helpers for testing logging functionality.
/// Only use in test files, never in application code.
///
/// Features:
/// - TestLogOutput to capture logs during tests
/// - Helper functions to manipulate log levels in tests
/// - Utilities to assert log content or absence

library;

import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:logger/logger.dart';
import 'package:flutter_test/flutter_test.dart';

// This is the NEW log helper file for testing

// Memory output to capture logs during tests
class TestLogOutput extends LogOutput {
  final List<OutputEvent> buffer = [];

  @override
  void output(OutputEvent event) {
    buffer.add(event);
  }

  void clear() {
    buffer.clear();
  }

  bool containsMessage(Level level, String messageSubstring) {
    return buffer.any(
      (event) =>
          event.level == level &&
          event.lines.any((line) => line.contains(messageSubstring)),
    );
  }

  bool isEmpty() => buffer.isEmpty;
}

/// Reset all log levels to default before/after tests
/// Should be called in setUp or tearDown.
void resetLogLevels() {
  LoggerFactory.resetLogLevels();
  // Consider resetting the default level too if tests might change it
  // LoggerFactory.setDefaultLogLevel(Level.info); // Or whatever your default is
}

/// Enable debug logs for a specific component during a test run.
/// Automatically resets the log level afterwards.
/// Usage: await withDebugLogsFor(MyComponent, () async { /* test code */ });
Future<void> withDebugLogsFor(Type type, Future<void> Function() testFn) async {
  final originalLevel = LoggerFactory.getCurrentLevel(type);
  try {
    LoggerFactory.setLogLevel(type, Level.debug);
    await testFn();
  } finally {
    // Reset to original level specifically for this type,
    // or could use resetLogLevels() if that's the desired behavior.
    // Resetting to original is safer if multiple levels are manipulated.
    LoggerFactory.setLogLevel(type, originalLevel);
  }
}

/// Enable logs of a specific level or higher for a component during a test run.
/// Automatically resets the log level afterwards.
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

/// Executes the test function ensuring no logs of the specified level (or higher)
/// are emitted by the given component type during its execution.
/// Fails the test if such logs are detected.
/// Note: This requires a TestLogOutput to be configured for the logger.
Future<void> expectNoLogsFrom(
  Type type,
  Level level,
  TestLogOutput logOutput, // Assumes a TestLogOutput is available
  Future<void> Function() testFn,
) async {
  logOutput.clear(); // Clear previous logs
  final originalLevel = LoggerFactory.getCurrentLevel(type);
  try {
    // Set level temporarily high to potentially catch lower level logs if needed,
    // though the primary check is on the output buffer.
    // Alternatively, keep the level as is and just check the buffer.
    await testFn();

    final offendingLogs = logOutput.buffer.where(
      (event) =>
          event.level.index >= level.index &&
          // This check assumes the logger tag includes the type name. Adjust if needed.
          event.lines.any((line) => line.contains(type.toString())),
    );

    if (offendingLogs.isNotEmpty) {
      final logMessages = offendingLogs
          .map((e) => e.lines.join('\\n')) // Join lines of a single event
          .join('\\n\\n'); // Separate different events with double newline
      throw TestFailure(
        'Expected no logs at level ${level.name} or higher from ${type.toString()}, '
        'but found:\\n$logMessages',
      );
    }
  } finally {
    LoggerFactory.setLogLevel(type, originalLevel);
    logOutput.clear(); // Clean up after check
  }
}
