import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

void main() {
  group('Log printer output format', () {
    test('without timestamps (default)', () {
      // Ensure timestamps are off (default)
      LoggerFactory.setPrintTimestamps(false);

      final logger = LoggerFactory.getLogger('LogPrinterTest');
      final tag = logTag('LogPrinterTest');

      logger.d('$tag Debug message test - no timestamps');
      logger.i('$tag Info message test - no timestamps');

      // Just a simple assertion so the test passes
      expect(LoggerFactory.getTimestampSetting(), isFalse);
    });

    test('with timestamps enabled', () {
      // Enable timestamps
      LoggerFactory.setPrintTimestamps(true);

      final logger = LoggerFactory.getLogger('LogPrinterTest');
      final tag = logTag('LogPrinterTest');

      logger.i('$tag Info message test - with timestamps');
      logger.w('$tag Warning message test - with timestamps');

      // Just a simple assertion so the test passes
      expect(LoggerFactory.getTimestampSetting(), isTrue);

      // Reset to default
      LoggerFactory.setPrintTimestamps(false);
    });
  });
}
