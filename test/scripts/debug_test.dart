// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

void main() {
  // Get a logger for this test
  final Logger logger = LoggerFactory.getLogger('DebugTest');
  final String tag = logTag('DebugTest');

  // Optionally set log level for this test if needed (defaults should work)
  // LoggerFactory.setLogLevel('DebugTest', Level.debug);

  test('Simple failing test with logs', () {
    logger.i('$tag This is an INFO message.');
    logger.d('$tag This is a DEBUG message.');
    logger.w('$tag This is a WARNING message.');
    logger.e('$tag This is an ERROR message.');
    print('$tag This is a standard print message.'); // Also test standard print

    // Intentionally fail the test
    expect(true, false, reason: 'Intentional failure to test logging');
  });
}
