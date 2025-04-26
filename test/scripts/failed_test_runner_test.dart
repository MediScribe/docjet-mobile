import 'dart:convert';

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../../scripts/list_failed_tests.dart' as script;
import './test_helpers.dart';

// Define mock classes manually instead of using @GenerateMocks
class MockProcessRunner extends Mock implements script.ProcessRunner {}

class MockTestEventProcessor extends Mock
    implements script.TestEventProcessor {}

class MockResultFormatter extends Mock implements script.ResultFormatter {}

// This is a custom implementation of TestEventProcessor for testing
class TestEventProcessorMock implements script.TestEventProcessor {
  final Map<String, List<script.FailedTest>> predefinedResult;
  final int predefinedTotalTests;

  TestEventProcessorMock(this.predefinedResult, this.predefinedTotalTests);

  @override
  script.ProcessedTestResult extractFailedTests(
    List<Map<String, dynamic>> allEvents,
    bool debugMode, {
    bool suppressDebugTests = true,
  }) {
    return script.ProcessedTestResult(
      failedTestsByFile: predefinedResult,
      totalTestsRun: predefinedTotalTests,
    );
  }
}

void main() {
  group('FailedTestRunner', () {
    test('should run test command with correct arguments', () async {
      // Given
      final fakeRunner = FakeProcessRunner(
        createMockProcessResult(exitCode: 0, stdout: '[]'),
      );
      final mockProcessor = TestEventProcessorMock({}, 0);

      final runner = script.FailedTestRunner(
        processRunner: fakeRunner,
        eventProcessor: mockProcessor,
        formatter: script.ResultFormatter(),
      );

      // When
      await runner.run(
        ['test/specific_test.dart'],
        debugMode: false,
        exceptMode: false,
      );

      // Then
      expect(fakeRunner.capturedArguments, [
        'test',
        '--machine',
        'test/specific_test.dart',
      ]);
    });

    test('should parse test events from stdout', () async {
      // Given
      final testEvents = [
        {'type': 'start', 'time': 1000},
        {'type': 'allDone', 'time': 2000, 'success': true},
      ];

      final fakeRunner = FakeProcessRunner(
        createMockProcessResult(exitCode: 0, stdout: jsonEncode(testEvents)),
      );
      final mockProcessor = TestEventProcessorMock({}, 2);

      final runner = script.FailedTestRunner(
        processRunner: fakeRunner,
        eventProcessor: mockProcessor,
        formatter: script.ResultFormatter(),
      );

      // When
      final result = await runner.run([], debugMode: false, exceptMode: false);

      // Then
      expect(result.allEvents.length, 2);
      expect(result.allEvents[0]['type'], 'start');
      expect(result.allEvents[1]['type'], 'allDone');
    });

    test(
      'should pass environment variable when targeting debug_test.dart',
      () async {
        // Given
        final fakeRunner = FakeProcessRunner(
          createMockProcessResult(exitCode: 0, stdout: '[]'),
        );
        final mockProcessor = TestEventProcessorMock({}, 0);
        final runner = script.FailedTestRunner(
          processRunner: fakeRunner,
          eventProcessor: mockProcessor,
          formatter: script.ResultFormatter(),
        );
        final target = 'test/scripts/debug_test.dart';

        // When
        await runner.run([target], debugMode: false, exceptMode: false);

        // Then
        // Check that runProcess was called with the environment variable
        expect(fakeRunner.capturedEnvironment, isNotNull);
        expect(
          fakeRunner.capturedEnvironment?['DEBUG_TEST_SHOULD_FAIL'],
          'true',
        );
      },
    );

    test(
      'should NOT pass environment variable when targeting other files',
      () async {
        // Given
        final fakeRunner = FakeProcessRunner(
          createMockProcessResult(exitCode: 0, stdout: '[]'),
        );
        final mockProcessor = TestEventProcessorMock({}, 0);
        final runner = script.FailedTestRunner(
          processRunner: fakeRunner,
          eventProcessor: mockProcessor,
          formatter: script.ResultFormatter(),
        );
        final target = 'test/some_other_test.dart';

        // When
        await runner.run([target], debugMode: false, exceptMode: false);

        // Then
        // Check that runProcess was called WITHOUT the environment variable
        expect(fakeRunner.capturedEnvironment, isNull);
      },
    );
  });
}
