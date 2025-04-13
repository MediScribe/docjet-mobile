/// LOGGING TEST UTILITIES
///
/// Helpers for testing logging functionality.
/// Only use in test files, never in application code.
///
/// Features:
/// - TestLogOutput to capture logs during tests
/// - Helper functions to manipulate log levels in tests
/// - Utilities to assert log content or absence
/// - Support for both class-based and string-based loggers

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

/// Creates and returns a TestLogOutput instance for capturing logs
TestLogOutput captureLogOutput() {
  return TestLogOutput();
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
///
/// Works with both Type and String identifiers:
/// ```dart
/// // With a class:
/// await withDebugLogsFor(MyComponent, () async { /* test code */ });
///
/// // With a string identifier:
/// await withDebugLogsFor("Feature.Logger", () async { /* test code */ });
/// ```
Future<void> withDebugLogsFor(
  dynamic target,
  Future<void> Function() testFn,
) async {
  final originalLevel = LoggerFactory.getCurrentLevel(target);
  try {
    LoggerFactory.setLogLevel(target, Level.debug);
    await testFn();
  } finally {
    // Reset to original level specifically for this target
    LoggerFactory.setLogLevel(target, originalLevel);
  }
}

/// Enable logs of a specific level or higher for a component during a test run.
/// Automatically resets the log level afterwards.
///
/// Works with both Type and String identifiers:
/// ```dart
/// // With a class:
/// await withLogLevelFor(MyComponent, Level.warning, () async { /* test code */ });
///
/// // With a string identifier:
/// await withLogLevelFor("Feature.Logger", Level.warning, () async { /* test code */ });
/// ```
Future<void> withLogLevelFor(
  dynamic target,
  Level level,
  Future<void> Function() testFn,
) async {
  final originalLevel = LoggerFactory.getCurrentLevel(target);
  try {
    LoggerFactory.setLogLevel(target, level);
    await testFn();
  } finally {
    LoggerFactory.setLogLevel(target, originalLevel);
  }
}

/// Executes the test function ensuring no logs of the specified level (or higher)
/// are emitted by the given component during its execution.
/// Fails the test if such logs are detected.
/// Note: This requires a TestLogOutput to be configured for the logger.
///
/// Works with both Type and String identifiers:
/// ```dart
/// // With a class:
/// await expectNoLogsFrom(MyComponent, Level.warning, logOutput, () async { /* test code */ });
///
/// // With a string identifier:
/// await expectNoLogsFrom("Feature.Logger", Level.warning, logOutput, () async { /* test code */ });
/// ```
Future<void> expectNoLogsFrom(
  dynamic target,
  Level level,
  TestLogOutput logOutput, // Assumes a TestLogOutput is available
  Future<void> Function() testFn,
) async {
  logOutput.clear(); // Clear previous logs
  final originalLevel = LoggerFactory.getCurrentLevel(target);
  try {
    // Set level temporarily to trace to capture all logs
    LoggerFactory.setLogLevel(target, Level.trace);
    await testFn();

    // Get the tag for log message filtering
    final tagValue = target is Type ? target.toString() : target.toString();

    final offendingLogs = logOutput.buffer.where(
      (event) =>
          event.level.index >= level.index &&
          // Check if log lines contain the tag (assuming proper tag usage)
          event.lines.any((line) => line.contains(tagValue)),
    );

    if (offendingLogs.isNotEmpty) {
      final logMessages = offendingLogs
          .map((e) => e.lines.join('\n')) // Join lines of a single event
          .join('\n\n'); // Separate different events with double newline
      throw TestFailure(
        'Expected no logs at level ${level.name} or higher from $tagValue, '
        'but found:\n$logMessages',
      );
    }
  } finally {
    LoggerFactory.setLogLevel(target, originalLevel);
    logOutput.clear(); // Clean up after check
  }
}

/// Assert that the logs contain a specific message at a specific level
void expectLogContains(
  TestLogOutput output,
  Level level,
  String expectedSubstring, {
  String? reason,
}) {
  expect(
    output.containsMessage(level, expectedSubstring),
    isTrue,
    reason:
        reason ??
        'Expected log to contain "$expectedSubstring" at level ${level.name}',
  );
}

/// Assert that no logs above the specified level were emitted
void expectNoLogsAboveLevel(
  TestLogOutput output,
  Level level, {
  String? reason,
}) {
  final offendingLogs = output.buffer.where(
    (event) => event.level.index > level.index,
  );

  expect(
    offendingLogs.isEmpty,
    isTrue,
    reason: reason ?? 'Expected no logs above level ${level.name}',
  );
}
