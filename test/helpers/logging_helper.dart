import 'package:docjet_mobile/core/utils/test_logger.dart';
import 'package:flutter_test/flutter_test.dart';
export 'package:docjet_mobile/core/utils/test_logger.dart'; // Re-export TestLogger for convenience

/// Initializes test environment and disables all logging.
/// Call this at the beginning of your test file's main() function.
void setupLogging() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestLogger.disableLogging();
}

/// Call this in tearDownAll() to reset logging configuration.
void tearDownLogging() {
  TestLogger.resetLogging();
}
