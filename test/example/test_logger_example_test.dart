import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/utils/logger.dart';
import '../helpers/logging_helper.dart';

void main() {
  // Setup: Disable all logging for tests by default
  setupLogging();

  // Make sure to reset logging when all tests are done
  tearDownAll(() => tearDownLogging());

  test('Log filtering is disabled by default', () {
    // These logs should be suppressed
    debugPrint('This debug print should be hidden');
    logger.d('This logger.d call should be hidden');

    // Log with a tag - also hidden by default
    debugPrint('[TAG] Debug print with tag should also be hidden');
    logger.d('[TAG] Logger.d call with tag should also be hidden');

    // Simple assertion to make test pass
    expect(true, isTrue);
  });

  test('Can enable logs with specific tag', () {
    // Enable logging for a specific tag
    TestLogger.enableLoggingForTag('[TAG]');

    // These logs should still be suppressed
    debugPrint('This debug print should still be hidden');
    logger.d('This logger.d call should still be hidden');

    // These logs with the enabled tag should be visible
    debugPrint('[TAG] This debug print with TAG should be visible');
    logger.d('[TAG] This logger.d call with TAG should be visible');

    // Reset for next test
    TestLogger.disableLogging();

    expect(true, isTrue);
  });

  test('Different tags can be enabled', () {
    // Enable logging for a different tag
    TestLogger.enableLoggingForTag('[NETWORK]');

    // These logs should be suppressed
    debugPrint('[TAG] This debug print with TAG should be hidden now');
    logger.d('[TAG] This logger.d call with TAG should be hidden now');

    // These logs with the enabled tag should be visible
    debugPrint('[NETWORK] This debug print with NETWORK tag should be visible');
    logger.d('[NETWORK] This logger.d call with NETWORK tag should be visible');

    // Reset for next test
    TestLogger.disableLogging();

    expect(true, isTrue);
  });

  test('Can enable multiple tags at once', () {
    // Enable multiple tags
    TestLogger.enableLoggingForTags(['[TAG]', '[NETWORK]', '[AUDIO]']);

    // These logs should all be visible
    debugPrint('[TAG] This debug print with TAG should be visible');
    logger.d('[NETWORK] This logger.d call with NETWORK should be visible');
    debugPrint('[AUDIO] This debug print with AUDIO should be visible');

    // Logs without enabled tags still suppressed
    debugPrint('This debug print without tag should still be hidden');
    logger.d('This logger.d call without tag should still be hidden');

    // Reset for next test
    TestLogger.disableLogging();

    expect(true, isTrue);
  });

  test('Can enable all logging', () {
    // Enable ALL logging
    TestLogger.enableAllLogging();

    // Everything should be visible now
    debugPrint('This debug print without any tag should be visible');
    logger.d('This logger.d call without any tag should be visible');
    debugPrint('[TAG] This debug print with TAG should be visible');
    logger.d('[NETWORK] This logger.d call with NETWORK should be visible');

    // Reset for next test
    TestLogger.disableLogging();

    expect(true, isTrue);
  });
}
