import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/features/jobs/data/config/job_sync_config.dart';

void main() {
  group('JobSyncConfig', () {
    test('should have the correct default values', () {
      // Verify the constants are set to their expected values
      expect(maxRetryAttempts, 5);
      expect(retryBackoffBase, const Duration(minutes: 1));
      expect(maxBackoffDuration, const Duration(hours: 1));
    });

    test('should calculate correct retry backoff durations', () {
      // Manual calculation of expected values for each retry count
      final expectedBackoffs = [
        const Duration(minutes: 1), // 1min * 2^0 = 1 minute (first retry)
        const Duration(minutes: 2), // 1min * 2^1 = 2 minutes (second retry)
        const Duration(minutes: 4), // 1min * 2^2 = 4 minutes (third retry)
        const Duration(minutes: 8), // 1min * 2^3 = 8 minutes (fourth retry)
        const Duration(minutes: 16), // 1min * 2^4 = 16 minutes (fifth retry)
        const Duration(minutes: 32), // 1min * 2^5 = 32 minutes (sixth retry)
      ];

      // Test for each retry count
      for (
        int retryCount = 0;
        retryCount < expectedBackoffs.length;
        retryCount++
      ) {
        final calculatedBackoff = calculateRetryBackoff(retryCount);
        expect(
          calculatedBackoff,
          expectedBackoffs[retryCount],
          reason:
              'Expected backoff for retry $retryCount to be ${expectedBackoffs[retryCount].inMinutes} minutes, '
              'but got ${calculatedBackoff.inMinutes} minutes',
        );
      }
    });

    test('should respect max backoff cap for high retry counts', () {
      // Test a retry count that would exceed the max backoff
      // 1min * 2^10 = 1,024 minutes, which is more than 1 hour (60 minutes)
      const highRetryCount = 10;
      final calculatedBackoff = calculateRetryBackoff(highRetryCount);

      expect(
        calculatedBackoff,
        maxBackoffDuration,
        reason:
            'Expected backoff to be capped at ${maxBackoffDuration.inMinutes} minutes, '
            'but got ${calculatedBackoff.inMinutes} minutes',
      );
    });
  });
}
