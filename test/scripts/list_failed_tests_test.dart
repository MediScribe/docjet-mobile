import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../scripts/list_failed_tests.dart' as script;
import 'package:mocktail/mocktail.dart';

/// A fake ProcessRunner for testing
class FakeProcessRunner implements script.ProcessRunner {
  final ProcessResult result;
  List<String>? capturedArguments;
  Map<String, String>? capturedEnvironment;

  FakeProcessRunner(this.result);

  @override
  Future<ProcessResult> runProcess(
    List<String> arguments, {
    bool runInShell = true,
    Map<String, String>? environment,
  }) async {
    capturedArguments = arguments;
    capturedEnvironment = environment;
    return result;
  }
}

// Mock implementation of TestEventProcessor for tests without using the real implementation
class TestEventProcessorMock implements script.TestEventProcessor {
  final Map<String, List<script.FailedTest>> predefinedResult;
  final int predefinedTotalTests; // Add total tests count

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

// Helper to create realistic mock events
Map<String, dynamic> _createTestStartEvent(
  int id,
  String name,
  String? url,
  int time,
) {
  return {
    "type": "testStart",
    "time": time,
    "test": {
      "id": id,
      "name": name,
      "suiteID": 0,
      "groupIDs": [],
      "metadata": {"skip": false, "skipReason": null},
      "line": 10,
      "column": 5,
      "url": url,
      "root_line": 10,
      "root_column": 5,
    },
  };
}

Map<String, dynamic> _createErrorEvent(
  int id,
  String error,
  String stackTrace,
  int time,
) {
  return {
    "type": "error",
    "testID": id,
    "error": error,
    "stackTrace": stackTrace,
    "isFailure": true, // Treat errors as failures for simplicity here
    "time": time,
  };
}

Map<String, dynamic> _createTestDoneEvent(
  int id,
  String result, {
  int? time,
  bool hidden = false,
  bool skipped = false,
}) {
  return {
    "type": "testDone",
    "testID": id,
    "result": result, // "success", "failure", "error"
    "hidden": hidden,
    "skipped": skipped,
    "time":
        time ??
        (DateTime.now().millisecondsSinceEpoch +
            100), // Ensure done is after start/error
  };
}

Map<String, dynamic> _createPrintEvent(int testId, String message, int time) {
  return {"type": "print", "testID": testId, "message": message, "time": time};
}

class MockProcessRunner extends Mock implements script.ProcessRunner {}

class MockTestEventProcessor extends Mock
    implements script.TestEventProcessor {}

class MockResultFormatter extends Mock implements script.ResultFormatter {}

// We'll create a factory for ProcessResult instead
ProcessResult createMockProcessResult({
  required int exitCode,
  dynamic stdout = '',
  dynamic stderr = '',
}) {
  return ProcessResult(123, exitCode, stdout, stderr);
}

void main() {
  late MockProcessRunner mockProcessRunner;
  late MockTestEventProcessor mockEventProcessor;
  late MockResultFormatter mockResultFormatter;
  late script.FailedTestRunner runner;

  // Helper function to create a test event
  Map<String, dynamic> createTestEvent({
    required String type,
    int? testId,
    String? result,
    String? name,
    String? url,
    int? time,
    String? error,
    String? stackTrace,
    String? message,
  }) {
    final event = <String, dynamic>{
      'type': type,
      'time': time ?? DateTime.now().millisecondsSinceEpoch,
    };
    if (testId != null) event['testID'] = testId;
    if (result != null) event['result'] = result;
    if (error != null) event['error'] = error;
    if (stackTrace != null) event['stackTrace'] = stackTrace;
    if (message != null) event['message'] = message;
    if (type == 'testStart') {
      event['test'] = {
        'id': testId,
        'name': name ?? 'Test $testId',
        'url': url ?? 'file:///app/test/some_test.dart',
        'root_line': null,
        'root_column': null,
        'line': 10,
        'column': 5,
      };
    }
    return event;
  }

  setUp(() {
    mockProcessRunner = MockProcessRunner();
    mockEventProcessor = MockTestEventProcessor();
    mockResultFormatter = MockResultFormatter();

    // Register fallback values for any() matchers if needed
    registerFallbackValue(
      script.TestRunResult(
        failedTestsByFile: {},
        allEvents: [],
        exitCode: 0,
        totalTestsRun: 0,
        totalTestsFailed: 0,
      ),
    );
    registerFallbackValue(false); // for bool debugMode/exceptMode

    // Reset mocks for verify calls between tests
    reset(mockProcessRunner);
    reset(mockEventProcessor);
    reset(mockResultFormatter);

    runner = script.FailedTestRunner(
      processRunner: mockProcessRunner,
      eventProcessor: mockEventProcessor,
      formatter: mockResultFormatter,
    );
  });

  group('FailedTestRunner with Mocks', () {
    test('run successfully finds no failed tests', () async {
      final processResult = createMockProcessResult(exitCode: 0, stdout: '[]');
      final processedResult = script.ProcessedTestResult(
        failedTestsByFile: {},
        totalTestsRun: 5,
      ); // 5 tests run, 0 failed

      when(
        () => mockProcessRunner.runProcess(any()),
      ).thenAnswer((_) async => processResult);
      when(
        () => mockEventProcessor.extractFailedTests(
          any(),
          any(),
          suppressDebugTests: any(named: 'suppressDebugTests'),
        ),
      ).thenReturn(processedResult);
      // Use argThat to match the specific ProcessedTestResult content
      when(
        () => mockResultFormatter.printResults(
          any(
            that: predicate<script.TestRunResult>(
              (res) =>
                  res.totalTestsFailed == 0 &&
                  res.totalTestsRun == 5 &&
                  res.failedTestsByFile.isEmpty,
            ),
          ),
          any(),
          any(),
        ),
      ).thenAnswer((_) {}); // Mock the printResults call

      final result = await runner.run(
        [],
        debugMode: false,
        exceptMode: false,
        suppressDebugTests: true,
      );

      expect(result.exitCode, 0);
      expect(result.totalTestsFailed, 0);
      expect(result.totalTestsRun, 5);
      expect(result.failedTestsByFile, isEmpty);

      verifyNever(
        () => mockResultFormatter.printResults(
          any(
            that: predicate<script.TestRunResult>(
              (res) => res.totalTestsFailed != 0 || res.totalTestsRun != 5,
            ),
          ),
          any(),
          any(),
        ),
      );
    });
  });

  test('FailedTest class should store test information correctly', () {
    // Given
    final id = 1;
    final name = 'Test Name';
    final error = 'Error Message';
    final stackTrace = 'Stack Trace';
    final testDoneEvent = {'result': 'failure'};
    final errorEvent = {'error': error};

    // When
    final failedTest = script.FailedTest(
      id: id,
      name: name,
      error: error,
      stackTrace: stackTrace,
      testDoneEvent: testDoneEvent,
      errorEvent: errorEvent,
    );

    // Then
    expect(failedTest.id, id);
    expect(failedTest.name, name);
    expect(failedTest.error, error);
    expect(failedTest.stackTrace, stackTrace);
    expect(failedTest.testDoneEvent, testDoneEvent);
    expect(failedTest.errorEvent, errorEvent);
  });

  group('FailedTestRunner', () {
    test('should run test command with correct arguments', () async {
      // Given
      final fakeRunner = FakeProcessRunner(ProcessResult(0, 0, '[]', ''));
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
        ProcessResult(0, 0, jsonEncode(testEvents), ''),
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
        final fakeRunner = FakeProcessRunner(ProcessResult(0, 0, '[]', ''));
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
        final fakeRunner = FakeProcessRunner(ProcessResult(0, 0, '[]', ''));
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

  group('TestEventProcessor', () {
    test('should extract failed tests correctly', () {
      // Given
      final events = [
        _createTestStartEvent(
          1,
          'Test A1 Failed',
          'file:///test/file_a_test.dart',
          1000,
        ),
        _createErrorEvent(
          1,
          'Error A1',
          'Stack A1\n  at file_a_test.dart:15',
          1010,
        ),
        _createTestDoneEvent(1, 'error', time: 1020),
      ];
      final processor = TestEventProcessorMock({
        'file:///test/file_a_test.dart': [
          script.FailedTest(
            id: 1,
            name: 'Test A1 Failed',
            error: 'Error A1',
            stackTrace: 'Stack A1\n  at file_a_test.dart:15',
            testDoneEvent: {'result': 'error'},
            errorEvent: {'error': 'Error A1'},
          ),
        ],
      }, 1);

      // When
      final result = processor.extractFailedTests(events, false);

      // Then
      expect(result.totalTestsRun, 1);
      expect(result.totalTestsFailed, 1);
      expectFailedTest(
        result.failedTestsByFile,
        'file:///test/file_a_test.dart',
        0,
        expectedId: 1,
        expectedName: 'Test A1 Failed',
        expectedError: 'Error A1',
        expectedStackTrace: 'Stack A1\n  at file_a_test.dart:15',
      );
    });

    test('should handle multiple failed tests in the same file', () {
      // Given
      final events = [
        _createTestStartEvent(
          1,
          'Test A1 Failed',
          'file:///test/file_a_test.dart',
          1000,
        ),
        _createErrorEvent(
          1,
          'Error A1',
          'Stack A1\n  at file_a_test.dart:15',
          1010,
        ),
        _createTestDoneEvent(1, 'error', time: 1020),
        _createTestStartEvent(
          2,
          'Test A2 Failed',
          'file:///test/file_a_test.dart',
          1100,
        ),
        _createErrorEvent(
          2,
          'Error A2',
          'Stack A2\n  at file_a_test.dart:20',
          1110,
        ),
        _createTestDoneEvent(2, 'error', time: 1120),
      ];
      final processor = TestEventProcessorMock({
        'file:///test/file_a_test.dart': [
          script.FailedTest(
            id: 1,
            name: 'Test A1 Failed',
            error: 'Error A1',
            stackTrace: 'Stack A1\n  at file_a_test.dart:15',
            testDoneEvent: {'result': 'error'},
            errorEvent: {'error': 'Error A1'},
          ),
          script.FailedTest(
            id: 2,
            name: 'Test A2 Failed',
            error: 'Error A2',
            stackTrace: 'Stack A2\n  at file_a_test.dart:20',
            testDoneEvent: {'result': 'error'},
            errorEvent: {'error': 'Error A2'},
          ),
        ],
      }, 2);

      // When
      final result = processor.extractFailedTests(events, false);

      // Then
      expect(result.totalTestsRun, 2);
      expect(result.totalTestsFailed, 2);
      expectFailedTest(
        result.failedTestsByFile,
        'file:///test/file_a_test.dart',
        0,
        expectedId: 1,
        expectedName: 'Test A1 Failed',
        expectedError: 'Error A1',
        expectedStackTrace: 'Stack A1\n  at file_a_test.dart:15',
      );
      expectFailedTest(
        result.failedTestsByFile,
        'file:///test/file_a_test.dart',
        1,
        expectedId: 2,
        expectedName: 'Test A2 Failed',
        expectedError: 'Error A2',
        expectedStackTrace: 'Stack A2\n  at file_a_test.dart:20',
      );
    });

    test('should handle debug mode correctly', () {
      // Given
      final events = [
        _createTestStartEvent(
          1,
          'Test A1 Failed',
          'file:///test/file_a_test.dart',
          1000,
        ),
        _createErrorEvent(
          1,
          'Error A1',
          'Stack A1\n  at file_a_test.dart:15',
          1010,
        ),
        _createTestDoneEvent(1, 'error', time: 1020),
      ];
      final processor = TestEventProcessorMock({
        'file:///test/file_a_test.dart': [
          script.FailedTest(
            id: 1,
            name: 'Test A1 Failed',
            error: 'Error A1',
            stackTrace: 'Stack A1\n  at file_a_test.dart:15',
            testDoneEvent: {'result': 'error'},
            errorEvent: {'error': 'Error A1'},
          ),
        ],
      }, 1);

      // When
      final result = processor.extractFailedTests(events, true);

      // Then
      expect(result.totalTestsRun, 1);
      expect(result.totalTestsFailed, 1);
      expectFailedTest(
        result.failedTestsByFile,
        'file:///test/file_a_test.dart',
        0,
        expectedId: 1,
        expectedName: 'Test A1 Failed',
        expectedError: 'Error A1',
        expectedStackTrace: 'Stack A1\n  at file_a_test.dart:15',
      );
    });

    test('should handle suppressDebugTests correctly', () {
      // Given
      final events = [
        _createTestStartEvent(
          1,
          'Test A1 Failed',
          'file:///test/file_a_test.dart',
          1000,
        ),
        _createErrorEvent(
          1,
          'Error A1',
          'Stack A1\n  at file_a_test.dart:15',
          1010,
        ),
        _createTestDoneEvent(1, 'error', time: 1020),
      ];
      final processor = TestEventProcessorMock({
        'file:///test/file_a_test.dart': [
          script.FailedTest(
            id: 1,
            name: 'Test A1 Failed',
            error: 'Error A1',
            stackTrace: 'Stack A1\n  at file_a_test.dart:15',
            testDoneEvent: {'result': 'error'},
            errorEvent: {'error': 'Error A1'},
          ),
        ],
      }, 1);

      // When
      final result = processor.extractFailedTests(
        events,
        false,
        suppressDebugTests: true,
      );

      // Then
      expect(result.totalTestsRun, 1);
      expect(result.totalTestsFailed, 1);
      expectFailedTest(
        result.failedTestsByFile,
        'file:///test/file_a_test.dart',
        0,
        expectedId: 1,
        expectedName: 'Test A1 Failed',
        expectedError: 'Error A1',
        expectedStackTrace: 'Stack A1\n  at file_a_test.dart:15',
      );
    });
  });

  // --- Tests for ResultFormatter ---
  group('ResultFormatter', () {
    late script.ResultFormatter formatter;
    late script.TestEventProcessor processor; // Use the real processor

    setUp(() {
      formatter = script.ResultFormatter();
      processor = script.TestEventProcessor();
    });

    // Helper function to capture print output
    Future<String> capturePrint(Function() action) async {
      var printedMessages = <String>[];
      await runZoned(
        () async {
          action();
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            // DEBUG: Uncomment below to see captured output during test execution
            // parent.print(zone, "CAPTURED: $line");
            printedMessages.add(line);
          },
        ),
      );
      return printedMessages.join('\n');
    }

    test('printResults with no failed tests shows summary', () async {
      // Given
      final result = script.TestRunResult(
        failedTestsByFile: {},
        allEvents: [],
        exitCode: 0,
        totalTestsRun: 0,
        totalTestsFailed: 0,
      );

      // When
      final output = await capturePrint(
        () => formatter.printResults(result, false, false),
      );

      // Then
      expect(output, contains('No failed tests found.'));
      expect(output, contains('All 0 tests passed.'));
    });

    test('printResults with failed tests shows summary and details', () async {
      // Given
      final testId = 1;
      final startTime = DateTime.now().millisecondsSinceEpoch;
      final printTime1 = startTime + 50;
      final printTime2 = startTime + 60;
      final errorTime = startTime + 80;
      final endTime = startTime + 100;

      final allTestEvents = [
        _createTestStartEvent(
          testId,
          'My Failing Test',
          'file:///app/test/debug_and_error_test.dart',
          startTime,
        ),
        _createPrintEvent(testId, 'Console message one', printTime1),
        _createPrintEvent(testId, 'Console message two', printTime2),
        _createErrorEvent(
          testId,
          'Specific Error Message',
          'stack line 1\nstack line 2',
          errorTime,
        ),
        _createTestDoneEvent(testId, 'failure', time: endTime),
      ];

      final processed = processor.extractFailedTests(allTestEvents, false);
      final result = script.TestRunResult(
        failedTestsByFile: processed.failedTestsByFile,
        allEvents: allTestEvents,
        exitCode: 1,
        totalTestsRun: 1,
        totalTestsFailed: 1,
      );

      // When
      final output = await capturePrint(
        () => formatter.printResults(result, false, false),
      );

      // Then
      // Check file header
      expect(
        output,
        contains(
          '\x1B[31mFailed tests in: app/test/debug_and_error_test.dart\x1B[0m',
        ),
      );
      // Check test name
      expect(output, contains('• \x1B[31mTest: My Failing Test\x1B[0m'));

      // Check for Console Output section in default mode - should not be present
      expect(output, isNot(contains('\x1B[36m--- Console output ---\x1B[0m')));
      expect(output, isNot(contains('Console message one')));
      expect(output, isNot(contains('Console message two')));

      // Check for Exception Details section in default mode - should not be present
      expect(
        output,
        isNot(contains('\x1B[31mError:\x1B[0m Specific Error Message')),
      );
      expect(output, isNot(contains('\x1B[90mStack Trace:\x1B[0m')));
      expect(output, isNot(contains('stack line 1')));
      expect(output, isNot(contains('stack line 2')));

      // Check Summary
      expect(output, contains('Summary: 1/1 tests failed'));

      // Ensure the specific --except header/footer are NOT present
      expect(output, isNot(contains('--- Failed Test Exceptions')));
      expect(output, isNot(contains('--- End of Exceptions ---')));

      // Check for tips
      expect(
        output,
        contains(
          'Tip: Run with --debug to see both console output and exception details',
        ),
      );
      expect(
        output,
        contains('Tip: Run with --except to see exception details'),
      );
    });

    test(
      'printResults with exceptMode=true shows only exception details',
      () async {
        // Given
        final testId = 1;
        final startTime = DateTime.now().millisecondsSinceEpoch;
        final printTime1 = startTime + 50;
        final printTime2 = startTime + 60;
        final errorTime = startTime + 80;
        final endTime = startTime + 100;

        final allTestEvents = [
          _createTestStartEvent(
            testId,
            'My Failing Test',
            'file:///app/test/debug_and_error_test.dart',
            startTime,
          ),
          _createPrintEvent(testId, 'Console message one', printTime1),
          _createPrintEvent(testId, 'Console message two', printTime2),
          _createErrorEvent(
            testId,
            'Specific Error Message',
            'stack line 1\nstack line 2',
            errorTime,
          ),
          _createTestDoneEvent(testId, 'failure', time: endTime),
        ];

        final processed = processor.extractFailedTests(allTestEvents, false);
        final result = script.TestRunResult(
          failedTestsByFile: processed.failedTestsByFile,
          allEvents: allTestEvents,
          exitCode: 1,
          totalTestsRun: 1,
          totalTestsFailed: 1,
        );

        // When
        final output = await capturePrint(
          () => formatter.printResults(result, false, true),
        );

        // Then
        // Check file header
        expect(
          output,
          contains(
            '\x1B[31m--- Failed Test Exceptions (Grouped by File) ---\x1B[0m',
          ),
        );
        expect(
          output,
          contains(
            '\x1B[31mFailed tests in: app/test/debug_and_error_test.dart\x1B[0m',
          ),
        );
        // Check test name
        expect(output, contains('• \x1B[31mTest: My Failing Test\x1B[0m'));

        // Check for Console Output section - should NOT be present in except mode
        expect(
          output,
          isNot(contains('\x1B[36m--- Console output ---\x1B[0m')),
        );
        expect(output, isNot(contains('Console message one')));
        expect(output, isNot(contains('Console message two')));

        // Check for Exception Details section - SHOULD be present
        expect(
          output,
          contains('\x1B[31mError:\x1B[0m Specific Error Message'),
        );
        expect(output, contains('\x1B[90mStack Trace:\x1B[0m'));
        expect(output, contains('stack line 1'));
        expect(output, contains('stack line 2'));

        // Check footer and summary
        expect(output, contains('\x1B[31m--- End of Exceptions ---\x1B[0m'));
        expect(output, contains('Summary: 1/1 tests failed'));
      },
    );

    test('printResults handles loading errors correctly', () async {
      // Given
      final testId = 1;
      final startTime = DateTime.now().millisecondsSinceEpoch;
      final printTime1 = startTime + 50;
      final printTime2 = startTime + 60;
      final errorTime = startTime + 80;
      final endTime = startTime + 100;

      final allTestEvents = [
        _createTestStartEvent(
          testId,
          'My Failing Test',
          'file:///app/test/debug_and_error_test.dart',
          startTime,
        ),
        _createPrintEvent(testId, 'Console message one', printTime1),
        _createPrintEvent(testId, 'Console message two', printTime2),
        _createErrorEvent(
          testId,
          'Specific Error Message',
          'stack line 1\nstack line 2',
          errorTime,
        ),
        _createTestDoneEvent(testId, 'failure', time: endTime),
      ];

      final processed = processor.extractFailedTests(allTestEvents, false);
      final result = script.TestRunResult(
        failedTestsByFile: processed.failedTestsByFile,
        allEvents: allTestEvents,
        exitCode: 1,
        totalTestsRun: 1,
        totalTestsFailed: 1,
      );

      // When
      final output = await capturePrint(
        () => formatter.printResults(result, false, false),
      );

      // Then
      // Check file header
      expect(
        output,
        contains(
          '\x1B[31mFailed tests in: app/test/debug_and_error_test.dart\x1B[0m',
        ),
      );
      // Check test name
      expect(output, contains('• \x1B[31mTest: My Failing Test\x1B[0m'));

      // Check Summary
      expect(output, contains('Summary: 1/1 tests failed'));
    });

    test('printResults groups loading errors by actual file path', () async {
      // Given
      final testId = 1;
      final startTime = DateTime.now().millisecondsSinceEpoch;
      final printTime1 = startTime + 50;
      final printTime2 = startTime + 60;
      final errorTime = startTime + 80;
      final endTime = startTime + 100;

      final allTestEvents = [
        _createTestStartEvent(
          testId,
          'My Failing Test',
          'file:///app/test/debug_and_error_test.dart',
          startTime,
        ),
        _createPrintEvent(testId, 'Console message one', printTime1),
        _createPrintEvent(testId, 'Console message two', printTime2),
        _createErrorEvent(
          testId,
          'Specific Error Message',
          'stack line 1\nstack line 2',
          errorTime,
        ),
        _createTestDoneEvent(testId, 'failure', time: endTime),
      ];

      final processed = processor.extractFailedTests(allTestEvents, false);
      final result = script.TestRunResult(
        failedTestsByFile: processed.failedTestsByFile,
        allEvents: allTestEvents,
        exitCode: 1,
        totalTestsRun: 1,
        totalTestsFailed: 1,
      );

      // When
      final output = await capturePrint(
        () => formatter.printResults(result, false, false),
      );

      // Then
      // Check file header
      expect(
        output,
        contains(
          '\x1B[31mFailed tests in: app/test/debug_and_error_test.dart\x1B[0m',
        ),
      );
      // Check test name
      expect(output, contains('• \x1B[31mTest: My Failing Test\x1B[0m'));

      // Check Summary
      expect(output, contains('Summary: 1/1 tests failed'));
    });

    test('printResults with debugMode shows console output', () async {
      // Given
      final testId = 1;
      final startTime = DateTime.now().millisecondsSinceEpoch;
      final printTime1 = startTime + 50;
      final printTime2 = startTime + 60;
      final errorTime = startTime + 80;
      final endTime = startTime + 100;

      final allTestEvents = [
        _createTestStartEvent(
          testId,
          'My Failing Test',
          'file:///app/test/debug_and_error_test.dart',
          startTime,
        ),
        _createPrintEvent(testId, 'Console message one', printTime1),
        _createPrintEvent(testId, 'Console message two', printTime2),
        _createErrorEvent(
          testId,
          'Specific Error Message',
          'stack line 1\nstack line 2',
          errorTime,
        ),
        _createTestDoneEvent(testId, 'failure', time: endTime),
      ];

      final processed = processor.extractFailedTests(allTestEvents, true);
      final result = script.TestRunResult(
        failedTestsByFile: processed.failedTestsByFile,
        allEvents: allTestEvents,
        exitCode: 1,
        totalTestsRun: 1,
        totalTestsFailed: 1,
      );

      // When
      final output = await capturePrint(
        () => formatter.printResults(result, true, false),
      );

      // Then
      // Check file header
      expect(
        output,
        contains(
          '\x1B[31mFailed tests in: app/test/debug_and_error_test.dart\x1B[0m',
        ),
      );
      // Check test name
      expect(output, contains('• \x1B[31mTest: My Failing Test\x1B[0m'));

      // Check for both console output and exception details sections
      expect(output, contains('\x1B[36m--- Console output ---\x1B[0m'));
      expect(output, contains('Console message one'));
      expect(output, contains('Console message two'));
      expect(output, contains('(Showing console output captured between'));
      expect(output, contains('\x1B[36m--- End of output ---\x1B[0m'));

      expect(output, contains('\x1B[31mError:\x1B[0m Specific Error Message'));
      expect(output, contains('\x1B[90mStack Trace:\x1B[0m'));
      expect(output, contains('stack line 1'));
      expect(output, contains('stack line 2'));

      // Verify separator between error and console output
      expect(output, contains('    --- '));

      // Check Summary
      expect(output, contains('Summary: 1/1 tests failed'));
    });

    test(
      'printResults includes tips for debug/except when tests fail and flags are off',
      () async {
        // Given
        final testId = 1;
        final startTime = DateTime.now().millisecondsSinceEpoch;
        final printTime1 = startTime + 50;
        final printTime2 = startTime + 60;
        final errorTime = startTime + 80;
        final endTime = startTime + 100;

        final allTestEvents = [
          _createTestStartEvent(
            testId,
            'My Failing Test',
            'file:///app/test/debug_and_error_test.dart',
            startTime,
          ),
          _createPrintEvent(testId, 'Console message one', printTime1),
          _createPrintEvent(testId, 'Console message two', printTime2),
          _createErrorEvent(
            testId,
            'Specific Error Message',
            'stack line 1\nstack line 2',
            errorTime,
          ),
          _createTestDoneEvent(testId, 'failure', time: endTime),
        ];

        final processed = processor.extractFailedTests(allTestEvents, false);
        final result = script.TestRunResult(
          failedTestsByFile: processed.failedTestsByFile,
          allEvents: allTestEvents,
          exitCode: 1,
          totalTestsRun: 1,
          totalTestsFailed: 1,
        );

        // When
        final output = await capturePrint(
          () => formatter.printResults(result, false, false),
        );

        // Then
        // Check for tips
        expect(
          output,
          contains(
            'Tip: Run with --debug to see both console output and exception details from the failing tests',
          ),
        );
        expect(
          output,
          contains(
            'Tip: Run with --except to see exception details (grouped by file)',
          ),
        );

        // Check file path is correct
        expect(
          output,
          contains(
            '\x1B[31mFailed tests in: app/test/debug_and_error_test.dart\x1B[0m',
          ),
        );
        expect(output, contains('• \x1B[31mTest: My Failing Test\x1B[0m'));

        // Default mode should NOT show error details or console output
        expect(
          output,
          isNot(contains('\x1B[31mError:\x1B[0m Specific Error Message')),
        );
        expect(output, isNot(contains('\x1B[90mStack Trace:\x1B[0m')));
        expect(output, isNot(contains('stack line 1')));
        expect(
          output,
          isNot(contains('\x1B[36m--- Console output ---\x1B[0m')),
        );
        expect(output, isNot(contains('Console message one')));

        // Check Summary
        expect(output, contains('Summary: 1/1 tests failed'));
      },
    );

    test(
      'printResults includes tip for specific target when no target given',
      () async {
        // Given
        final failedTests = processor.extractFailedTests([
          _createTestStartEvent(
            1,
            'Test A1 Failed',
            'file:///test/file_a_test.dart',
            1000,
          ),
          _createErrorEvent(
            1,
            'Error A1',
            'Stack A1\n  at file_a_test.dart:15',
            1010,
          ),
          _createTestDoneEvent(1, 'error', time: 1020),
        ], false);
        final result = script.TestRunResult(
          failedTestsByFile: failedTests.failedTestsByFile,
          allEvents: [
            _createTestStartEvent(
              1,
              'Test A1 Failed',
              'file:///test/file_a_test.dart',
              1000,
            ),
            _createErrorEvent(
              1,
              'Error A1',
              'Stack A1\n  at file_a_test.dart:15',
              1010,
            ),
            _createTestDoneEvent(1, 'error', time: 1020),
          ],
          exitCode: 1,
          totalTestsRun: 1,
          totalTestsFailed: 1,
          testTargets: [], // Empty list - no target specified
        );

        // When
        final output = await capturePrint(
          () => formatter.printResults(result, false, false),
        );

        // Then
        // First verify basic test results are shown
        expect(
          output,
          contains('\x1B[31mFailed tests in: test/file_a_test.dart\x1B[0m'),
        );
        expect(output, contains('• \x1B[31mTest: Test A1 Failed\x1B[0m'));

        // Check that the tip for specific target paths is shown when no target is specified
        expect(
          output,
          contains(
            'Tip: You can run with a specific path or directory to test only a subset of tests:',
          ),
        );
        expect(
          output,
          contains('./scripts/list_failed_tests.dart path/to/test_file.dart'),
        );
        expect(
          output,
          contains('./scripts/list_failed_tests.dart path/to/test_directory'),
        );

        // If we provide a target, the tip shouldn't be shown
        final resultWithTarget = script.TestRunResult(
          failedTestsByFile: failedTests.failedTestsByFile,
          allEvents: result.allEvents,
          exitCode: 1,
          totalTestsRun: 1,
          totalTestsFailed: 1,
          testTargets: ['some/specific/target.dart'], // Target specified
        );

        final outputWithTarget = await capturePrint(
          () => formatter.printResults(resultWithTarget, false, false),
        );

        // Target tip should not be present when target is specified
        expect(
          outputWithTarget,
          isNot(
            contains(
              'Tip: You can run with a specific path or directory to test only a subset of tests:',
            ),
          ),
        );
      },
    );

    test('printResults does NOT include tips when tests pass', () async {
      // Given
      final result = script.TestRunResult(
        failedTestsByFile: {},
        allEvents: [],
        exitCode: 0,
        totalTestsRun: 0,
        totalTestsFailed: 0,
      );

      // When
      final output = await capturePrint(
        () => formatter.printResults(result, false, false),
      );

      // Then
      expect(output, contains('No failed tests found.'));
      expect(output, contains('All 0 tests passed.'));
    });

    // --- NEW TEST CASE ---
    test(
      'printResults with debugMode shows BOTH console output AND exception details',
      () async {
        // Given
        final testId = 1;
        final startTime = DateTime.now().millisecondsSinceEpoch;
        final printTime1 = startTime + 50;
        final printTime2 = startTime + 60;
        final errorTime = startTime + 80;
        final endTime = startTime + 100;

        final allTestEvents = [
          _createTestStartEvent(
            testId,
            'My Failing Test',
            'file:///app/test/debug_and_error_test.dart',
            startTime,
          ),
          _createPrintEvent(testId, 'Console message one', printTime1),
          _createPrintEvent(testId, 'Console message two', printTime2),
          _createErrorEvent(
            testId,
            'Specific Error Message',
            'stack line 1\nstack line 2',
            errorTime,
          ),
          _createTestDoneEvent(testId, 'failure', time: endTime),
        ];

        // Use the real processor to get the failed tests map
        final processed = processor.extractFailedTests(allTestEvents, true);
        final result = script.TestRunResult(
          failedTestsByFile: processed.failedTestsByFile,
          allEvents: allTestEvents,
          exitCode: 1,
          totalTestsRun: 1, // Manually determined for this test case
          totalTestsFailed: 1, // Manually determined for this test case
        );

        // When
        final output = await capturePrint(
          // Run with debugMode: true, exceptMode: false
          () => formatter.printResults(result, true, false),
        );

        // Then
        // Check file header
        expect(
          output,
          contains(
            '\x1B[31mFailed tests in: app/test/debug_and_error_test.dart\x1B[0m',
          ),
        );
        // Check test name
        expect(output, contains('• \x1B[31mTest: My Failing Test\x1B[0m'));

        // Check for Console Output section
        expect(output, contains('\x1B[36m--- Console output ---\x1B[0m'));
        expect(output, contains('Console message one'));
        expect(output, contains('Console message two'));
        expect(output, contains('(Showing console output captured between'));
        expect(output, contains('\x1B[36m--- End of output ---\x1B[0m'));

        // Check for Exception Details section (Error + Stack Trace)
        expect(
          output,
          contains('\x1B[31mError:\x1B[0m Specific Error Message'),
        );
        expect(output, contains('\x1B[90mStack Trace:\x1B[0m'));
        expect(output, contains('stack line 1'));
        expect(output, contains('stack line 2'));

        // Check Summary
        expect(output, contains('Summary: 1/1 tests failed'));

        // Ensure the specific --except header/footer are NOT present
        expect(output, isNot(contains('--- Failed Test Exceptions')));
        expect(output, isNot(contains('--- End of Exceptions ---')));

        // Ensure the tips for --debug and --except are NOT present (since --debug is on)
        expect(output, isNot(contains('Tip: Run with --debug')));
        // Tip for --except might still be shown depending on current logic
        // expect(output, isNot(contains('Tip: Run with --except')));
      },
    );

    test('printResults handles suppression of debug_test.dart', () async {
      // Given
      final testId = 1;
      final startTime = DateTime.now().millisecondsSinceEpoch;
      final errorTime = startTime + 80;
      final endTime = startTime + 100;

      final debugTestEvents = [
        _createTestStartEvent(
          testId,
          'Debug Test Failure',
          'file:///test/scripts/debug_test.dart',
          startTime,
        ),
        _createErrorEvent(
          testId,
          'Error from debug test',
          'Stack from debug test',
          errorTime,
        ),
        _createTestDoneEvent(testId, 'error', time: endTime),
      ];

      final normalTestEvents = [
        _createTestStartEvent(
          testId,
          'Normal Test Failure',
          'file:///test/some_other_test.dart',
          startTime,
        ),
        _createErrorEvent(
          testId,
          'Error from normal test',
          'Stack from normal test',
          errorTime,
        ),
        _createTestDoneEvent(testId, 'error', time: endTime),
      ];

      final combinedEvents = [...debugTestEvents, ...normalTestEvents];

      // When: Run with suppressDebugTests=true (default)
      final processed = processor.extractFailedTests(
        combinedEvents,
        false,
        suppressDebugTests: true,
      );

      final result = script.TestRunResult(
        failedTestsByFile: processed.failedTestsByFile,
        allEvents: combinedEvents,
        exitCode: 1,
        totalTestsRun: 2,
        totalTestsFailed:
            1, // Only 1 test should be reported as failing, the normal one
      );

      // When: Run with default mode (no flags)
      final output = await capturePrint(
        () => formatter.printResults(result, false, false),
      );

      // Then
      // Verify we only show the normal test, not the debug test
      expect(
        output,
        contains('\x1B[31mFailed tests in: test/some_other_test.dart\x1B[0m'),
      );
      expect(output, contains('• \x1B[31mTest: Normal Test Failure\x1B[0m'));
      expect(output, isNot(contains('Debug Test Failure')));

      // Run with debug mode to see the error details
      final outputWithDebug = await capturePrint(
        () => formatter.printResults(result, true, false),
      );

      // Verify we see the error details of the normal test
      expect(
        outputWithDebug,
        contains('\x1B[31mError:\x1B[0m Error from normal test'),
      );
      expect(outputWithDebug, contains('Stack from normal test'));
    });
  });
}

// Helper predicate for verifying TestRunResult in mocks
Matcher _isTestRunResultWith({
  int? totalTestsFailed,
  int? totalTestsRun,
  bool? hasFailedTests,
}) {
  return predicate<script.TestRunResult>((res) {
    bool match = true;
    if (totalTestsFailed != null) {
      match &= res.totalTestsFailed == totalTestsFailed;
    }
    if (totalTestsRun != null) {
      match &= res.totalTestsRun == totalTestsRun;
    }
    if (hasFailedTests != null) {
      match &= res.failedTestsByFile.isNotEmpty == hasFailedTests;
    }
    return match;
  }, 'is a TestRunResult with specified properties');
}

// Ensure TestRunResult is registered if using complex matchers or any() implicitly
void registerFallbackValues() {
  registerFallbackValue(
    script.TestRunResult(
      failedTestsByFile: {},
      allEvents: [],
      exitCode: 0,
      totalTestsRun: 0,
      totalTestsFailed: 0,
    ),
  );
}

/// Helper function to check failed test results safely with null checks
void expectFailedTest(
  Map<String, List<script.FailedTest>> failedTestsByFile,
  String filePath,
  int index, {
  required int expectedId,
  required String expectedName,
  required String expectedError,
  required String expectedStackTrace,
}) {
  // Check if the file path exists in the map
  expect(
    failedTestsByFile.containsKey(filePath),
    isTrue,
    reason: 'File path $filePath should exist in failedTestsByFile',
  );

  // Check if the list for the file path is not null
  final fileTests = failedTestsByFile[filePath];
  expect(fileTests, isNotNull, reason: 'List for $filePath should not be null');

  // Check if the list has enough elements
  expect(
    fileTests!.length > index,
    isTrue,
    reason: 'List for $filePath should have at least ${index + 1} elements',
  );

  // Check the properties of the test at the given index
  final test = fileTests[index];
  expect(test.id, expectedId, reason: 'ID should match');
  expect(test.name, expectedName, reason: 'Name should match');
  expect(test.error, expectedError, reason: 'Error should match');
  expect(
    test.stackTrace,
    expectedStackTrace,
    reason: 'Stack trace should match',
  );
}
