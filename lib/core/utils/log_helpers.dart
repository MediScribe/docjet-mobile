/// DOCJET LOGGING SYSTEM
///
/// This is the primary logging implementation for the application.
/// Use this file for all application logging needs.
///
/// Features:
/// - Per-class log levels (can enable debug for just one component)
/// - Consistent log tag formatting
/// - Release mode safety (prevents debug logs in production)
/// - Factory pattern for logger instantiation
///
/// Basic usage:
/// ```dart
/// class MyClass {
///   // Get a logger for this specific class
///   final Logger _logger = LoggerFactory.getLogger(MyClass);
///
///   // Create a tag for consistent log messages
///   static final String _tag = logTag(MyClass);
///
///   void someMethod() {
///     _logger.i('$_tag Starting operation...');
///     // ... code ...
///     _logger.d('$_tag Debug details: $details');
///   }
///
///   // Optional: Add a static method to enable debug logging
///   static void enableDebugLogs() {
///     LoggerFactory.setLogLevel(MyClass, Level.debug);
///   }
/// }
/// ```
///
/// For testing:
/// ```dart
/// // In tests, you can use string identifiers directly:
/// final testLogger = LoggerFactory.getLogger("MyTestLogger");
/// final testTag = logTag("MyTestLogger");
///
/// // Set log level for test logs
/// LoggerFactory.setLogLevel("MyTestLogger", Level.info);
/// ```
///
/// For testing utilities and advanced logging info, see:
/// docs/logging_guide.md
///
/// See examples/logging_example.dart for a complete example

library;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

// Export the necessary Logger classes so consumers only need to import this file
export 'package:logger/logger.dart'
    show
        Logger,
        Level,
        LogFilter,
        LogEvent,
        LogOutput,
        ConsoleOutput,
        MultiOutput;

/// Helper function to debug log that is automatically stripped in release builds
///
/// The function is wrapped in an assert that makes it a no-op in release mode.
/// This provides stronger guarantees than just a runtime check with kDebugMode.
///
/// Usage:
/// ```dart
/// debugLog(_logger, _tag, 'This only logs in debug builds');
/// ```
void debugLog(Logger logger, String tag, String message) {
  assert(() {
    logger.d('$tag $message');
    return true;
  }());
}

// NEW CENTRAL LOGGING SYSTEM
// Use this file for all logging needs
// test/helpers/log_helpers.dart is for testing

/// Helper function to create a standardized log tag
String logTag(dynamic context) {
  return '[${_getLoggerId(context)}]';
}

/// Custom printer that handles our timestamp display preference
class CustomPrinter extends LogPrinter {
  final bool includeTimestamps;

  CustomPrinter({required this.includeTimestamps});

  @override
  List<String> log(LogEvent event) {
    final message = event.message.toString();

    if (includeTimestamps) {
      final now = DateTime.now();
      final formatter = DateFormat('HH:mm:ss.SSS');
      final timestamp = formatter.format(now);
      return ['$timestamp $message'];
    } else {
      return [message];
    }
  }
}

/// Factory for creating loggers with consistent configuration
class LoggerFactory {
  // Private constructor to prevent instantiation
  LoggerFactory._();

  // Default log levels
  static const Level _defaultReleaseLevel = Level.info;
  static const Level _defaultDebugLevel = Level.debug;

  // Get the default log level based on build mode
  static Level get _defaultLevel =>
      kReleaseMode ? _defaultReleaseLevel : _defaultDebugLevel;

  // Map of component types to their log levels
  static final Map<String, Level> _logLevels = {};

  // Registry of active loggers to update when settings change
  static final Map<String, Logger> _activeLoggers = {};

  // Global shared memory output that captures ALL logs
  static final _sharedMemoryOutput = MemoryOutput();
  static bool _outputsInitialized = false;

  // Flag to control timestamp printing globally
  static bool _printTimestamps = false;

  // Initialize outputs only once
  static void _ensureOutputsInitialized() {
    if (!_outputsInitialized) {
      // Hook into the Logger to capture all output events
      Logger.addOutputListener((event) {
        _sharedMemoryOutput.output(event);
      });
      _outputsInitialized = true;
    }
  }

  /// Creates a logger for the specified type
  static Logger getLogger(dynamic type, {Level? level}) {
    _ensureOutputsInitialized();

    final id = _getLoggerId(type);

    // Set initial log level if provided, BUT ONLY if not already set
    // This allows tests or other setup code to preempt the default level
    if (level != null && !_logLevels.containsKey(id)) {
      _logLevels[id] = level;
    }

    // The filter will dynamically use the level from _logLevels or the default
    final effectiveLevel = _logLevels[id] ?? _defaultLevel;

    // Create a new logger or reuse existing one
    if (!_activeLoggers.containsKey(id)) {
      _activeLoggers[id] = _createLogger(id, effectiveLevel);
    }

    return _activeLoggers[id]!;
  }

  /// Creates a new logger with current settings
  static Logger _createLogger(String id, Level effectiveLevel) {
    return Logger(
      filter: CustomLogFilter(id, effectiveLevel, _logLevels, _defaultLevel),
      printer: CustomPrinter(includeTimestamps: _printTimestamps),
      output: ConsoleOutput(),
    );
  }

  /// Sets whether timestamps should be printed in logs globally
  static void setPrintTimestamps(bool enabled) {
    if (_printTimestamps == enabled) return; // No change

    _printTimestamps = enabled;

    // Update all existing loggers with new settings
    _activeLoggers.forEach((id, logger) {
      final effectiveLevel = _logLevels[id] ?? _defaultLevel;
      _activeLoggers[id] = _createLogger(id, effectiveLevel);
    });
  }

  /// Gets the current timestamp setting
  static bool getTimestampSetting() {
    return _printTimestamps;
  }

  /// Sets the log level for a specific type
  static void setLogLevel(dynamic type, Level level) {
    final id = _getLoggerId(type);
    _logLevels[id] = level;

    // Update the logger if it exists
    if (_activeLoggers.containsKey(id)) {
      _activeLoggers[id] = _createLogger(id, level);
    }
  }

  /// Gets the current log level for a specific type
  static Level getCurrentLevel(dynamic type) {
    final id = _getLoggerId(type);
    return _logLevels[id] ?? _defaultLevel;
  }

  /// Resets all log levels to the default
  static void resetLogLevels() {
    _logLevels.clear();
  }

  /// Gets all captured logs
  static List<OutputEvent> getAllLogs() {
    return _sharedMemoryOutput.logs;
  }

  /// Gets logs for a specific type
  static List<OutputEvent> getLogsFor(dynamic type) {
    final id = _getLoggerId(type);
    return _sharedMemoryOutput.logs
        .where((log) => log.lines.any((line) => line.contains('[$id]')))
        .toList();
  }

  /// Clears all captured logs
  static void clearLogs() {
    _sharedMemoryOutput.clear();
  }

  /// Checks if logs contain a specific text
  static bool containsLog(String text, {dynamic forType}) {
    final logs = forType != null ? getLogsFor(forType) : getAllLogs();

    return logs.any((event) => event.lines.any((line) => line.contains(text)));
  }
}

/// Gets a standardized ID for a logger
String _getLoggerId(dynamic type) {
  if (type is String) return type;
  if (type is Type) return type.toString();
  return type.runtimeType.toString();
}

/// Custom log filter that filters based on log level
class CustomLogFilter extends LogFilter {
  final String id;
  final Map<String, Level> _logLevels;
  final Level _defaultLevel;

  CustomLogFilter(
    this.id,
    Level initialLevel,
    this._logLevels,
    this._defaultLevel,
  );

  @override
  bool shouldLog(LogEvent event) {
    // Get the current log level (dynamic lookup, not cached)
    final currentLevel = _logLevels[id] ?? _defaultLevel;
    return event.level.index >= currentLevel.index;
  }
}

/// Memory output that captures logs
class MemoryOutput extends LogOutput {
  final List<OutputEvent> logs = [];

  @override
  void output(OutputEvent event) {
    logs.add(event);
  }

  void clear() {
    logs.clear();
  }
}
