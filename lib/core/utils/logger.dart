import 'package:flutter/foundation.dart'; // For kReleaseMode
import 'package:docjet_mobile/core/utils/logger.dart';
export 'package:logger/logger.dart'; // Export the Logger class

// How to use:
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
