import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1, // number of method calls to be displayed
    errorMethodCount: 8, // number of method calls if stacktrace is provided
    lineLength: 120, // width of the output
    colors: true, // Colorful log messages
    printEmojis: true, // Print an emoji for each log message
    dateTimeFormat: DateTimeFormat.none, // Hide timestamp
  ),
);

// You can create different loggers for different levels if needed,
// e.g., one for verbose debug, one for important info.
// final verboseLogger = Logger(printer: PrettyPrinter(methodCount: 2));
