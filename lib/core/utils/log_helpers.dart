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
/// For testing utilities, use the docjet_test package:
/// import 'package:docjet_test/docjet_test.dart';
///
/// See examples/logging_example.dart for a complete example

library;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';

// Export the necessary Logger classes so consumers only need to import this file
export 'package:logger/logger.dart'
    show Logger, Level, LogFilter, LogEvent, LogOutput;

// NEW CENTRAL LOGGING SYSTEM
// Use this file for all logging needs
// test/helpers/log_helpers.dart is for testing

// Define PlaybackState - Placeholder needed for formatPlaybackState
// TODO: Replace with actual PlaybackState import once available
enum PlaybackStatePlaceholder {
  initial,
  loading,
  playing,
  paused,
  stopped,
  completed,
  error,
}

/// Default release mode level
Level _defaultReleaseLevel = Level.warning;

/// Default debug mode level
Level _defaultDebugLevel = Level.info;

/// Map to store file-specific log levels
final Map<String, Level> _logLevels = {};

/// Converts a Type or String to a consistent string identifier
String _getLogId(dynamic target) {
  if (target is Type) {
    return target.toString();
  } else if (target is String) {
    return target;
  }
  throw ArgumentError(
    'Logger target must be Type or String, but was ${target.runtimeType}',
  );
}

/// LoggerFactory for creating loggers with appropriate tags and levels
class LoggerFactory {
  /// Get a logger for a specific class or string identifier with optional custom level
  ///
  /// Accepts either:
  /// - A Type (class): LoggerFactory.getLogger(MyClass)
  /// - A String: LoggerFactory.getLogger("TestLogger")
  static Logger getLogger(dynamic target, {Level? level}) {
    final tag = _getLogId(target);
    final logLevel =
        level ??
        _logLevels[tag] ??
        (kReleaseMode ? _defaultReleaseLevel : _defaultDebugLevel);

    return Logger(
      filter: CustomLogFilter(logLevel),
      printer: PrettyPrinter(
        methodCount: 1,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.none,
      ),
    );
  }

  /// Set log level for a specific class or string identifier
  static void setLogLevel(dynamic target, Level level) {
    _logLevels[_getLogId(target)] = level;
  }

  /// Reset all custom log levels
  static void resetLogLevels() {
    _logLevels.clear();
  }

  /// Set global default log level
  static void setDefaultLogLevel(Level level) {
    if (kReleaseMode) {
      // Prevent setting levels below warning in release mode
      if (level.index < Level.warning.index) {
        level = Level.warning;
      }
    }

    if (!kReleaseMode) {
      _defaultDebugLevel = level;
    } else {
      _defaultReleaseLevel = level;
    }
  }

  /// Get the current effective log level for a type or string identifier
  static Level getCurrentLevel(dynamic target) {
    final tag = _getLogId(target);
    return _logLevels[tag] ??
        (kReleaseMode ? _defaultReleaseLevel : _defaultDebugLevel);
  }
}

/// Custom log filter with per-instance level control
class CustomLogFilter extends LogFilter {
  @override
  final Level level;

  CustomLogFilter(this.level);

  @override
  bool shouldLog(LogEvent event) {
    // Handle Level.off explicitly
    if (level == Level.off) {
      return false;
    }
    // Original logic for other levels
    return event.level.index >= level.index;
  }
}

/// Generate a consistent tag for a class or string identifier
///
/// Accepts either:
/// - A Type (class): logTag(MyClass)
/// - A String: logTag("TestLogger")
String logTag(dynamic target) => _getLogId(target);

/// Format PlaybackState for logging - USING PLACEHOLDER
/// TODO: Update this function when the actual PlaybackState is available
String formatPlaybackState(PlaybackStatePlaceholder state) {
  // Simplified placeholder implementation
  return state.toString().split('.').last;
}

// Example of how the real function might look
/*
String formatPlaybackState(PlaybackState state) {
  return state.when(
    initial: () => 'initial',
    loading: () => 'loading',
    playing: (pos, dur) => 'playing(${pos.inMilliseconds}ms/${dur?.inMilliseconds ?? 'N/A'}ms)',
    paused: (pos, dur) => 'paused(${pos.inMilliseconds}ms/${dur?.inMilliseconds ?? 'N/A'}ms)',
    stopped: () => 'stopped',
    completed: () => 'completed',
    error: (msg, pos, dur) => 'error($msg)',
  );
}
*/
