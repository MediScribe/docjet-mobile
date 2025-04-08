import 'dart:async';
import 'package:docjet_mobile/core/utils/test_logger.dart';
import 'package:flutter_test/flutter_test.dart';

/// Global test configuration that runs before any test file.
///
/// This file is automatically loaded by Flutter's test framework.
/// Uncomment the desired logging configuration to apply it globally.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =================================================================
  // LOGGING CONFIGURATION - Uncomment the desired option
  // =================================================================

  // OPTION 1: Default - Disable all logs for cleaner test output
  // TestLogger.disableLogging();

  // OPTION 2: Enable ALL logging (verbose, use for debugging)
  // TestLogger.enableAllLogging();

  // OPTION 3: Enable specific tags only (good for focused debugging)
  // TestLogger.enableLoggingForTags(['[AUDIO]', '[NETWORK]']);

  // OPTION 4: Enable a single tag
  // TestLogger.enableLoggingForTag('[TAG]');

  // =================================================================

  // Run the tests
  await testMain();

  // Reset logging at the end
  TestLogger.resetLogging();
}
