import 'package:test/test.dart';

import '../../scripts/list_failed_tests.dart' as script;
import './test_helpers.dart';

void main() {
  group('TestEventProcessor', () {
    test('should extract failed tests correctly', () {
      // Given
      final processor = script.TestEventProcessor();
      final events = [
        createTestStartEvent(
          1,
          'Test A1 Failed',
          'file:///test/file_a_test.dart',
          1000,
        ),
        createErrorEvent(
          1,
          'Error A1',
          'Stack A1\n  at file_a_test.dart:15',
          1010,
        ),
        createTestDoneEvent(1, 'error', time: 1020),
      ];

      // When
      final result = processor.extractFailedTests(events, false);

      // Then
      expect(result.totalTestsRun, 1);
      expect(result.totalTestsFailed, 1);
      expectFailedTest(
        result.failedTestsByFile,
        'test/file_a_test.dart',
        0,
        expectedId: 1,
        expectedName: 'Test A1 Failed',
        expectedError: 'Error A1',
        expectedStackTrace: 'Stack A1\n  at file_a_test.dart:15',
      );
    });

    test('should handle multiple failed tests in the same file', () {
      // Given
      final processor = script.TestEventProcessor();
      final events = [
        createTestStartEvent(
          1,
          'Test A1 Failed',
          'file:///test/file_a_test.dart',
          1000,
        ),
        createErrorEvent(
          1,
          'Error A1',
          'Stack A1\n  at file_a_test.dart:15',
          1010,
        ),
        createTestDoneEvent(1, 'error', time: 1020),
        createTestStartEvent(
          2,
          'Test A2 Failed',
          'file:///test/file_a_test.dart',
          1100,
        ),
        createErrorEvent(
          2,
          'Error A2',
          'Stack A2\n  at file_a_test.dart:20',
          1110,
        ),
        createTestDoneEvent(2, 'error', time: 1120),
      ];

      // When
      final result = processor.extractFailedTests(events, false);

      // Then
      expect(result.totalTestsRun, 2);
      expect(result.totalTestsFailed, 2);
      expectFailedTest(
        result.failedTestsByFile,
        'test/file_a_test.dart',
        0,
        expectedId: 1,
        expectedName: 'Test A1 Failed',
        expectedError: 'Error A1',
        expectedStackTrace: 'Stack A1\n  at file_a_test.dart:15',
      );
      expectFailedTest(
        result.failedTestsByFile,
        'test/file_a_test.dart',
        1,
        expectedId: 2,
        expectedName: 'Test A2 Failed',
        expectedError: 'Error A2',
        expectedStackTrace: 'Stack A2\n  at file_a_test.dart:20',
      );
    });

    test('should handle debug mode correctly', () {
      // Given
      final processor = script.TestEventProcessor();
      final events = [
        createTestStartEvent(
          1,
          'Test A1 Failed',
          'file:///test/file_a_test.dart',
          1000,
        ),
        createErrorEvent(
          1,
          'Error A1',
          'Stack A1\n  at file_a_test.dart:15',
          1010,
        ),
        createTestDoneEvent(1, 'error', time: 1020),
      ];

      // When
      final result = processor.extractFailedTests(events, true);

      // Then
      expect(result.totalTestsRun, 1);
      expect(result.totalTestsFailed, 1);
      expectFailedTest(
        result.failedTestsByFile,
        'test/file_a_test.dart',
        0,
        expectedId: 1,
        expectedName: 'Test A1 Failed',
        expectedError: 'Error A1',
        expectedStackTrace: 'Stack A1\n  at file_a_test.dart:15',
      );
    });

    test('should handle suppressDebugTests correctly', () {
      // Given
      final processor = script.TestEventProcessor();
      final events = [
        createTestStartEvent(
          1,
          'Test A1 Failed',
          'file:///test/debug_test.dart',
          1000,
        ),
        createErrorEvent(
          1,
          'Error A1',
          'Stack A1\n  at debug_test.dart:15',
          1010,
        ),
        createTestDoneEvent(1, 'error', time: 1020),
        createTestStartEvent(
          2,
          'Test B1 Failed',
          'file:///test/normal_test.dart',
          2000,
        ),
        createErrorEvent(
          2,
          'Error B1',
          'Stack B1\n  at normal_test.dart:25',
          2010,
        ),
        createTestDoneEvent(2, 'error', time: 2020),
      ];

      // When: Run with suppressDebugTests=true
      final result = processor.extractFailedTests(
        events,
        false,
        suppressDebugTests: true,
      );

      // Then: Only the normal test should be included
      expect(result.totalTestsRun, 2); // Counts all tests
      expect(result.totalTestsFailed, 1); // Only counts the non-debug test
      expect(result.failedTestsByFile.keys.length, 1);
      expect(
        result.failedTestsByFile.containsKey('test/normal_test.dart'),
        true,
      );
      expect(
        result.failedTestsByFile.containsKey('test/debug_test.dart'),
        false,
      );

      // When: Run with suppressDebugTests=false
      final resultWithDebug = processor.extractFailedTests(
        events,
        false,
        suppressDebugTests: false,
      );

      // Then: Both tests should be included
      expect(resultWithDebug.totalTestsRun, 2);
      expect(resultWithDebug.totalTestsFailed, 2);
      expect(resultWithDebug.failedTestsByFile.keys.length, 2);
      expect(
        resultWithDebug.failedTestsByFile.containsKey('test/normal_test.dart'),
        true,
      );
      expect(
        resultWithDebug.failedTestsByFile.containsKey('test/debug_test.dart'),
        true,
      );
    });
  });
}
