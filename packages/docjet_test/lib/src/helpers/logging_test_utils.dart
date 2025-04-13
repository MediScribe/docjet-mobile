/// DOCJET LOGGING TEST UTILITIES
///
/// Test utilities for components that use the DocJet logging system.
/// These utilities help test code that uses LoggerFactory and loggers
/// from lib/core/utils/log_helpers.dart
///
/// These utilities help with:
/// - Capturing log output during tests
/// - Temporarily changing log levels for tests
/// - Asserting the presence or absence of specific log messages
///
/// RECOMMENDED USAGE:
/// ```dart
/// // In your test file:
/// import 'package:docjet_test/docjet_test.dart';
///
/// test('logs appropriate messages', () async {
///   final output = captureLogOutput();
///
///   await withDebugLogging(MyClass, () async {
///     // Test code here
///     myClass.doSomething();
///   });
///
///   expectLogContains(output, Level.debug, 'Expected message');
///   expectNoLogsAboveLevel(output, Level.warning);
/// });
/// ```

library;

import 'package:logger/logger.dart';
import 'package:flutter_test/flutter_test.dart';

// TODO: The following is a temporary solution until the package
// is properly configured. The proper solution is to add docjet_mobile
// as a dependency in the pubspec.yaml and then use the real LoggerFactory

/// A class that mimics the API of the DocJet LoggerFactory
/// This is a placeholder until proper package dependencies are established
class LoggerFactory {
  static Level getCurrentLevel(dynamic target) => Level.info;
  static void setLogLevel(dynamic target, Level level) {}
  static void resetLogLevels() {}
  static void setDefaultLogLevel(Level level) {}
}

/// Memory output to capture logs during tests
class TestLogOutput extends LogOutput {
  final List<OutputEvent> buffer = [];

  @override
  void output(OutputEvent event) {
    buffer.add(event);
  }

  /// Clear all captured logs
  void clear() {
    buffer.clear();
  }

  /// Check if logs contain a specific message at a specific level
  bool containsMessage(Level level, String messageSubstring) {
    return buffer.any(
      (event) =>
          event.level == level &&
          event.lines.any((line) => line.contains(messageSubstring)),
    );
  }

  /// Check if no logs have been captured
  bool isEmpty() => buffer.isEmpty;
}

/// Create and return a TestLogOutput instance for capturing logs
TestLogOutput captureLogOutput() {
  return TestLogOutput();
}

/// Reset all log levels to default before/after tests
/// Should be called in setUp or tearDown.
void resetLogLevels() {
  LoggerFactory.resetLogLevels();
  // Consider resetting the default level too if tests might change it
  LoggerFactory.setDefaultLogLevel(Level.info); // Or whatever your default is
}

/// Enable debug logs for a specific component during a test run.
/// Automatically resets the log level afterwards.
///
/// Usage:
/// ```dart
/// // With Type (class):
/// await withDebugLogging(MyComponent, () async {
///   // Test code here
/// });
///
/// // With String identifier:
/// await withDebugLogging("MyLoggerIdentifier", () async {
///   // Test code here
/// });
/// ```
Future<void> withDebugLogging(
    dynamic target, Future<void> Function() testFn) async {
  final originalLevel = LoggerFactory.getCurrentLevel(target);
  try {
    LoggerFactory.setLogLevel(target, Level.debug);
    await testFn();
  } finally {
    // Reset to original level specifically for this target,
    // or could use resetLogLevels() if that's the desired behavior.
    // Resetting to original is safer if multiple levels are manipulated.
    LoggerFactory.setLogLevel(target, originalLevel);
  }
}

/// Enable logs of a specific level or higher for a component during a test run.
/// Automatically resets the log level afterwards.
///
/// Accepts either:
/// - A Type (class): withLogLevel(MyClass, Level.debug, () async {...})
/// - A String: withLogLevel("MyLogger", Level.debug, () async {...})
Future<void> withLogLevel(
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

/// Asserts that the logs contain a specific message at a specific level
void expectLogContains(
    TestLogOutput output, Level level, String expectedSubstring,
    {String? reason}) {
  expect(output.containsMessage(level, expectedSubstring), isTrue,
      reason: reason ??
          'Expected log to contain "$expectedSubstring" at level ${level.name}');
}

/// Asserts that no logs above the specified level were emitted
void expectNoLogsAboveLevel(TestLogOutput output, Level level,
    {String? reason}) {
  final offendingLogs = output.buffer.where(
    (event) => event.level.index > level.index,
  );

  expect(offendingLogs.isEmpty, isTrue,
      reason: reason ?? 'Expected no logs above level ${level.name}');
}

/// Executes the test function ensuring no logs of the specified level (or higher)
/// are emitted by the given component type during its execution.
/// Fails the test if such logs are detected.
///
/// Works with both Type and String identifiers.
Future<void> expectNoLogsFrom(
  dynamic target,
  Level level,
  TestLogOutput output,
  Future<void> Function() testFn,
) async {
  output.clear(); // Clear previous logs
  final originalLevel = LoggerFactory.getCurrentLevel(target);
  try {
    // Set level temporarily to allow capturing all logs
    LoggerFactory.setLogLevel(target, Level.trace);
    await testFn();

    // Get the tag for log message filtering
    final tagValue = target is Type ? target.toString() : target.toString();

    final offendingLogs = output.buffer.where(
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
    output.clear(); // Clean up after check
  }
}
