/// DOCJET LOGGING SYSTEM EXAMPLE
///
/// This file demonstrates the proper usage of the new logging system.
/// Use this as a reference for implementing logging in your components.
///
/// Features demonstrated:
/// - Getting class-specific loggers
/// - Setting log levels per component
/// - Using log tags consistently
/// - Enabling/disabling debug for specific classes
/// - Using string-based loggers (for testing and special cases)
///
/// For tests, import test utilities from:
/// import 'package:docjet_test/docjet_test.dart';

library;

import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Provides all logging functionality
import 'package:flutter/foundation.dart'; // Import for debugPrint

// Example class 1
class ExampleService {
  // Get a logger specific to this class
  final Logger _logger = LoggerFactory.getLogger(ExampleService);
  static final String _tag = logTag(
    ExampleService,
  ); // Use logTag for consistency

  void doSomethingImportant() {
    _logger.i('$_tag Starting important operation...');
    try {
      // Simulate work
      _performWork();
      _logger.i('$_tag Important operation completed successfully.');
    } catch (e, s) {
      _logger.e('$_tag Important operation failed!', error: e, stackTrace: s);
    }
  }

  void _performWork() {
    _logger.d('$_tag Performing sub-step 1.');
    // Simulate potential issue
    if (DateTime.now().second % 2 == 0) {
      _logger.w(
        '$_tag Potential issue detected in sub-step 1, but continuing.',
      );
    }
    _logger.d('$_tag Performing sub-step 2.');
    // Simulate a failure sometimes
    if (DateTime.now().millisecond % 5 == 0) {
      throw Exception('Something went wrong in sub-step 2');
    }
  }

  static void enableDebug() {
    LoggerFactory.setLogLevel(ExampleService, Level.debug);
    debugPrint('--> Debug logs ENABLED for ExampleService');
  }

  static void disableDebug() {
    // Reset to default (or could set to info/warning)
    LoggerFactory.setDefaultLogLevel(Level.info);
    debugPrint(
      '--> Debug logs DISABLED for ExampleService (back to default Info)',
    );
  }
}

// Example class 2
class AnotherComponent {
  final Logger _logger = LoggerFactory.getLogger(AnotherComponent);
  static final String _tag = logTag(AnotherComponent);

  void doLessImportantThing() {
    _logger.t('$_tag Starting less important thing.'); // Trace level
    // ... work ...
    _logger.d('$_tag Less important thing finished.');
  }

  static void setLevel(Level level) {
    LoggerFactory.setLogLevel(AnotherComponent, level);
    debugPrint('--> Log level for AnotherComponent set to: ${level.name}');
  }
}

// Example of string-based logger (useful for testing or specific modules)
class StringBasedLoggerExample {
  // Fixed string identifier - good for tests and special modules
  static const String identifier = "FeatureX.Logger";

  // Get a logger using string identifier
  final Logger _logger = LoggerFactory.getLogger(identifier);
  static final String _tag = logTag(identifier); // Use logTag for consistency

  void runExample() {
    _logger.i('$_tag Starting string-based logger example...');
    _logger.d('$_tag This is a debug message from string-based logger.');
    _logger.i('$_tag String-based logger example completed.');
  }

  static void enableDebug() {
    LoggerFactory.setLogLevel(identifier, Level.debug);
    debugPrint('--> Debug logs ENABLED for string logger: $identifier');
  }

  static void disableDebug() {
    LoggerFactory.setLogLevel(identifier, Level.info);
    debugPrint('--> Debug logs DISABLED for string logger: $identifier');
  }
}

void main() {
  debugPrint('--- Running Logging Example ---');

  // Default behavior (assuming debug mode, default level is Info)
  LoggerFactory.setDefaultLogLevel(Level.info);
  debugPrint('\n[Default Level: Info]');
  final service1 = ExampleService();
  final component1 = AnotherComponent();
  service1.doSomethingImportant();
  component1.doLessImportantThing(); // Trace/Debug won't show

  // Enable debug for ExampleService specifically
  debugPrint('\n[Enabling Debug for ExampleService]');
  ExampleService.enableDebug();
  service1.doSomethingImportant(); // Now shows debug logs
  component1.doLessImportantThing(); // Still only shows info+

  // Set AnotherComponent to Trace
  debugPrint('\n[Setting AnotherComponent to Trace]');
  AnotherComponent.setLevel(Level.trace);
  component1.doLessImportantThing(); // Now shows trace and debug
  service1.doSomethingImportant(); // ExampleService still at Debug

  // Set global level lower (e.g., Warning)
  debugPrint('\n[Setting Global Default to Warning]');
  LoggerFactory.setDefaultLogLevel(Level.warning);
  // Note: Specific levels still override the default
  debugPrint(
    '  (ExampleService is still Debug, AnotherComponent is still Trace)',
  );
  service1.doSomethingImportant(); // Shows Debug, Info, Warning, Error
  component1.doLessImportantThing(); // Shows Trace, Debug

  // Reset specific levels - they will now use the global default (Warning)
  debugPrint('\n[Resetting Specific Levels - Default is Warning]');
  LoggerFactory.resetLogLevels();
  service1.doSomethingImportant(); // Only shows Warning/Error
  component1.doLessImportantThing(); // Shows nothing (Trace/Debug < Warning)

  // Set specific level to OFF
  debugPrint('\n[Setting ExampleService Level to OFF]');
  LoggerFactory.setLogLevel(ExampleService, Level.off);
  service1.doSomethingImportant(); // Shows nothing
  component1.doLessImportantThing(); // Still shows nothing (Default Warning)

  // Demonstrate string-based logger
  debugPrint('\n[String-Based Logger Example]');
  final stringLogger = StringBasedLoggerExample();
  // First with default level (Info)
  stringLogger.runExample(); // Debug won't show

  // Then with debug enabled
  debugPrint('\n[Enabling Debug for String Logger]');
  StringBasedLoggerExample.enableDebug();
  stringLogger.runExample(); // Now shows debug logs

  // Disable debug
  debugPrint('\n[Disabling Debug for String Logger]');
  StringBasedLoggerExample.disableDebug();
  stringLogger.runExample(); // Debug won't show again

  debugPrint('\n--- Logging Example Complete ---');
}
