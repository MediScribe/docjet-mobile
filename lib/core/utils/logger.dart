/// DEPRECATED LOGGING SYSTEM
///
/// ⚠️ WARNING: This file is being phased out!
/// ⚠️ DO NOT USE for new code! Use log_helpers.dart instead.
///
/// This will be removed once all components are migrated
/// to the new logging system.
///
/// Migration Instructions:
///
/// 1. Replace imports:
///    - Remove: import 'package:docjet_mobile/core/utils/logger.dart';
///    - Add: import 'package:docjet_mobile/core/utils/log_helpers.dart';
///
/// 2. Replace global logger with class-specific logger:
///    - Old: logger.d('Some message');
///    - New:
///      final Logger _logger = LoggerFactory.getLogger(YourClass);
///      static final String _tag = logTag(YourClass);
///      _logger.d('$_tag Some message');
///
/// 3. Add debug helper (optional):
///    static void enableDebugLogs() {
///      LoggerFactory.setLogLevel(YourClass, Level.debug);
///    }
///
/// See examples/logging_example.dart for a complete migration example

library;

import 'package:flutter/foundation.dart'; // For kReleaseMode
import 'package:docjet_mobile/core/utils/logger.dart';
export 'package:logger/logger.dart'; // Export the Logger class

// DEPRECATED USAGE (DO NOT USE FOR NEW CODE):
// 1. Import this file and set the logger level to debug for detailed tracing
// import 'package:docjet_mobile/core/utils/logger.dart';
// final logger = Logger(level: Level.debug);
// 2. Set logger level to off if no longer needed
// final logger = Logger(level: Level.off);

// Create logger filter we can control
class CustomLogFilter extends LogFilter {
  Level _level = kReleaseMode ? Level.warning : Level.info;

  @override
  bool shouldLog(LogEvent event) {
    return event.level.index >= _level.index;
  }

  void setLevel(Level level) {
    _level = level;
  }
}

// Create our configurable filter
final logFilter = CustomLogFilter();

// Configure the logger instance with our controllable filter
final logger = Logger(
  filter: logFilter,
  printer: PrettyPrinter(
    methodCount: 1,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.none,
  ),
);

/// Sets the logger level - useful for tests
void setLogLevel(Level level) {
  logFilter.setLevel(level);
}
