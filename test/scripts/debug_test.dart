// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

void main() {
  // Get a logger for this test
  final Logger logger = LoggerFactory.getLogger('DebugTest');
  final String tag = logTag('DebugTest');

  // Optionally set log level for this test if needed (defaults should work)
  // LoggerFactory.setLogLevel('DebugTest', Level.debug);

  test(
    'Simple failing test with logs (only fails when DEBUG_TEST_SHOULD_FAIL=true)',
    () {
      logger.i('$tag This is an INFO message.');
      logger.d('$tag This is a DEBUG message.');
      logger.w('$tag This is a WARNING message.');
      logger.e('$tag This is an ERROR message.');
      print(
        '$tag This is a standard print message.',
      ); // Also test standard print

      // Intentionally fail the test only if the environment variable is set
      final shouldFail =
          Platform.environment['DEBUG_TEST_SHOULD_FAIL'] == 'true';
      expect(
        true,
        !shouldFail,
        reason: 'Intentional failure activated by DEBUG_TEST_SHOULD_FAIL=true',
      );
    },
  );
}
