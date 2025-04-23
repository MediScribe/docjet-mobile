import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../scripts/list_failed_tests.dart';

/// A fake ProcessRunner for testing
class FakeProcessRunner implements ProcessRunner {
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
class TestEventProcessorMock implements TestEventProcessor {
  final Map<String, List<FailedTest>> predefinedResult;

  TestEventProcessorMock(this.predefinedResult);

  @override
  Map<String, List<FailedTest>> extractFailedTests(
    List<Map<String, dynamic>> allEvents,
    bool debugMode, {
    bool suppressDebugTests = true,
  }) {
    return predefinedResult;
  }
}

// Helper to create realistic mock events
Map<String, dynamic> _createTestStartEvent(
  int id,
  String name,
  String url,
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

void main() {
  test('FailedTest class should store test information correctly', () {
    // Given
    final id = 1;
    final name = 'Test Name';
    final error = 'Error Message';
    final stackTrace = 'Stack Trace';
    final testDoneEvent = {'result': 'failure'};
    final errorEvent = {'error': error};

    // When
    final failedTest = FailedTest(
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
      final mockProcessor = TestEventProcessorMock({});

      final runner = FailedTestRunner(
        processRunner: fakeRunner,
        eventProcessor: mockProcessor,
        formatter: ResultFormatter(),
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
      final mockProcessor = TestEventProcessorMock({});

      final runner = FailedTestRunner(
        processRunner: fakeRunner,
        eventProcessor: mockProcessor,
        formatter: ResultFormatter(),
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
        final mockProcessor = TestEventProcessorMock({});
        final runner = FailedTestRunner(
          processRunner: fakeRunner,
          eventProcessor: mockProcessor,
          formatter: ResultFormatter(),
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
        final mockProcessor = TestEventProcessorMock({});
        final runner = FailedTestRunner(
          processRunner: fakeRunner,
          eventProcessor: mockProcessor,
          formatter: ResultFormatter(),
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

  // --- New Tests for ResultFormatter ---
  group('ResultFormatter', () {
    late ResultFormatter formatter;
    late TestEventProcessor processor; // Use the real processor

    setUp(() {
      formatter = ResultFormatter();
      processor = TestEventProcessor();
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
            printedMessages.add(line);
          },
        ),
      );
      return printedMessages.join('\n');
    }

    // Test Data Setup
    final eventsFileATest1 = [
      _createTestStartEvent(
        1,
        "Test A1 Failed",
        "file:///test/file_a_test.dart",
        1000,
      ),
      _createErrorEvent(
        1,
        "Error A1",
        "Stack A1\n  at file_a_test.dart:15",
        1010,
      ),
      _createTestDoneEvent(1, "error", time: 1020),
    ];
    final eventsFileATest2 = [
      _createTestStartEvent(
        2,
        "Test A2 Failed (No Details)",
        "file:///test/file_a_test.dart",
        1100,
      ),
      _createTestDoneEvent(2, "failure", time: 1110), // No error event
    ];
    final eventsFileATest3Debug = [
      _createTestStartEvent(
        3,
        "Test A3 Failed with Debug",
        "file:///test/file_a_test.dart",
        1200,
      ),
      _createPrintEvent(3, "Debug line 1", 1205),
      _createPrintEvent(3, "Debug line 2", 1210),
      _createErrorEvent(3, "Error A3", "Stack A3", 1215),
      _createTestDoneEvent(3, "error", time: 1220),
    ];
    final eventsFileBTest1 = [
      _createTestStartEvent(
        10,
        "Test B1 Failed",
        "file:///test/file_b_test.dart",
        2000,
      ),
      _createErrorEvent(
        10,
        "Error B1",
        "Stack B1\n  at file_b_test.dart:25",
        2010,
      ),
      _createTestDoneEvent(10, "error", time: 2020),
    ];
    final allTestEvents = [
      ...eventsFileATest1,
      ...eventsFileATest2,
      ...eventsFileATest3Debug,
      ...eventsFileBTest1,
      // Add a passing test to ensure it's ignored
      _createTestStartEvent(
        100,
        "Test C1 Passed",
        "file:///test/file_c_test.dart",
        3000,
      ),
      _createTestDoneEvent(100, "success", time: 3010),
      // Add a suiteDone event (often present in real output)
      {
        "type": "done",
        "success": false,
        "time": 4000,
      }, // success: false because of failures
    ];

    test(
      'printResults --except mode should group by file and show exceptions',
      () async {
        // Given
        final failedTests = processor.extractFailedTests(allTestEvents, false);
        final result = TestRunResult(
          failedTestsByFile: failedTests,
          allEvents: allTestEvents,
          exitCode: 1,
        );

        // When
        final output = await capturePrint(
          () => formatter.printResults(result, false, true),
        ); // exceptMode = true

        // Then
        // File A
        expect(
          output,
          contains(
            '\x1B[31m--- Failed Test Exceptions (Grouped by File) ---\x1B[0m',
          ),
        );
        expect(
          output,
          contains('\x1B[31mFailed tests in: test/file_a_test.dart\x1B[0m'),
        );
        expect(output, contains('  • \x1B[31mTest: Test A1 Failed\x1B[0m'));
        expect(output, contains('    \x1B[31mError:\x1B[0m Error A1'));
        expect(output, contains('    \x1B[90mStack Trace:\x1B[0m'));
        expect(output, contains('      Stack A1'));
        expect(output, contains('        at file_a_test.dart:15'));

        // File A - Test 2 (No Details)
        expect(
          output,
          contains('  • \x1B[31mTest: Test A2 Failed (No Details)\x1B[0m'),
        );
        expect(
          output,
          contains(
            '    \x1B[33m(No exception details found in test event data)\x1B[0m',
          ),
        );

        // File A - Test 3 (Should show exception even if debug logs exist)
        expect(
          output,
          contains('  • \x1B[31mTest: Test A3 Failed with Debug\x1B[0m'),
        );
        expect(output, contains('    \x1B[31mError:\x1B[0m Error A3'));
        expect(output, contains('    \x1B[90mStack Trace:\x1B[0m'));
        expect(output, contains('      Stack A3'));

        // File B
        expect(
          output,
          contains('\x1B[31mFailed tests in: test/file_b_test.dart\x1B[0m'),
        );
        expect(output, contains('  • \x1B[31mTest: Test B1 Failed\x1B[0m'));
        expect(output, contains('    \x1B[31mError:\x1B[0m Error B1'));
        expect(output, contains('    \x1B[90mStack Trace:\x1B[0m'));
        expect(output, contains('      Stack B1'));
        expect(output, contains('        at file_b_test.dart:25'));

        expect(output, contains('\x1B[31m--- End of Exceptions ---\x1B[0m'));

        // Ensure no default/debug formatting appears
        expect(output, isNot(contains('Failed tests grouped by source file')));
        expect(output, isNot(contains('--- Console output ---')));
      },
    );

    test(
      'printResults default mode should group by file and show only test names',
      () async {
        // Given
        final failedTests = processor.extractFailedTests(allTestEvents, false);
        final result = TestRunResult(
          failedTestsByFile: failedTests,
          allEvents: allTestEvents,
          exitCode: 1,
        );

        // When
        final output = await capturePrint(
          () => formatter.printResults(result, false, false),
        ); // default mode

        // Then
        expect(output, contains('Failed tests grouped by source file'));
        // File A
        expect(
          output,
          contains('[31mFailed tests in: test/file_a_test.dart[0m'),
        );
        expect(output, contains('  • \x1B[31mTest: Test A1 Failed\x1B[0m'));
        expect(
          output,
          contains('  • \x1B[31mTest: Test A2 Failed (No Details)\x1B[0m'),
        );
        expect(
          output,
          contains('  • \x1B[31mTest: Test A3 Failed with Debug\x1B[0m'),
        );
        // File B
        expect(
          output,
          contains('[31mFailed tests in: test/file_b_test.dart[0m'),
        );
        expect(output, contains('  • \x1B[31mTest: Test B1 Failed\x1B[0m'));

        // Ensure no exception/debug details
        expect(output, isNot(contains('Error A1')));
        expect(output, isNot(contains('Stack A1')));
        expect(output, isNot(contains('--- Console output ---')));
        expect(output, isNot(contains('--- Failed Test Exceptions ---')));

        // Check for Tips
        expect(output, contains('Tip: Run with --debug'));
        expect(output, contains('Tip: Run with --except'));
      },
    );

    test(
      'printResults --debug mode should group by file and show console output',
      () async {
        // Given
        final failedTests = processor.extractFailedTests(
          allTestEvents,
          true,
        ); // Need debug true for processor potentially
        final result = TestRunResult(
          failedTestsByFile: failedTests,
          allEvents: allTestEvents,
          exitCode: 1,
        );

        // When
        final output = await capturePrint(
          () => formatter.printResults(result, true, false),
        ); // debugMode = true

        // Then
        expect(output, contains('Failed tests grouped by source file'));
        // File A
        expect(
          output,
          contains('[31mFailed tests in: test/file_a_test.dart[0m'),
        );
        expect(output, contains('  • \x1B[31mTest: Test A1 Failed\x1B[0m'));
        // Check A1 has NO debug output
        expect(
          output,
          contains('    [36m--- Console output ---[0m'),
        ); // Header appears for A1
        expect(
          output,
          contains('(No console output captured between'),
        ); // No output message for A1
        expect(
          output,
          contains('    [36m--- End of output ---[0m'),
        ); // Footer appears for A1

        expect(
          output,
          contains('  • \x1B[31mTest: Test A2 Failed (No Details)\x1B[0m'),
        );
        // Check A2 has NO debug output
        expect(
          output,
          contains('    [36m--- Console output ---[0m'),
        ); // Header appears for A2
        expect(
          output,
          contains('(No console output captured between'),
        ); // No output message for A2
        expect(
          output,
          contains('    [36m--- End of output ---[0m'),
        ); // Footer appears for A2

        expect(
          output,
          contains('  • \x1B[31mTest: Test A3 Failed with Debug\x1B[0m'),
        );
        // Check A3 HAS debug output
        expect(
          output,
          contains('    [36m--- Console output ---[0m'),
        ); // Header appears for A3
        expect(
          output,
          contains('(Showing console output captured between'),
        ); // Has output message for A3
        expect(output, contains('      Debug line 1')); // Indented debug line
        expect(output, contains('      Debug line 2')); // Indented debug line
        expect(
          output,
          contains('    [36m--- End of output ---[0m'),
        ); // Footer appears for A3

        // File B
        expect(
          output,
          contains('[31mFailed tests in: test/file_b_test.dart[0m'),
        );
        expect(output, contains('  • \x1B[31mTest: Test B1 Failed\x1B[0m'));
        // Check B1 has NO debug output
        expect(
          output,
          contains('    [36m--- Console output ---[0m'),
        ); // Header appears for B1
        expect(
          output,
          contains('(No console output captured between'),
        ); // No output message for B1
        expect(
          output,
          contains('    [36m--- End of output ---[0m'),
        ); // Footer appears for B1

        // Ensure no exception details
        expect(output, isNot(contains('Error A1')));
        expect(output, isNot(contains('Stack A1')));
        expect(output, isNot(contains('--- Failed Test Exceptions ---')));

        // Check for Tips (only except tip should show in debug mode)
        expect(output, isNot(contains('Tip: Run with --debug')));
        expect(output, contains('Tip: Run with --except'));
      },
    );

    // Add test for debug_test.dart suppression
    test(
      'should suppress output from debug_test.dart unless specifically targeted',
      () async {
        // Given
        final debugTestEvents = [
          _createTestStartEvent(
            50,
            "Debug Test Failure",
            "file:///test/scripts/debug_test.dart",
            5000,
          ),
          _createErrorEvent(
            50,
            "Error from debug test",
            "Stack from debug test",
            5010,
          ),
          _createTestDoneEvent(50, "error", time: 5020),
        ];

        final normalTestEvents = [
          _createTestStartEvent(
            60,
            "Normal Test Failure",
            "file:///test/some_other_test.dart",
            6000,
          ),
          _createErrorEvent(
            60,
            "Error from normal test",
            "Stack from normal test",
            6010,
          ),
          _createTestDoneEvent(60, "error", time: 6020),
        ];

        final combinedEvents = [...debugTestEvents, ...normalTestEvents];

        // When - Test default behavior (suppress debug_test.dart)
        final failedTestsDefault = processor.extractFailedTests(
          combinedEvents,
          false,
          suppressDebugTests: true,
        );
        final resultDefault = TestRunResult(
          failedTestsByFile: failedTestsDefault,
          allEvents: combinedEvents,
          exitCode: 1,
        );

        final outputDefault = await capturePrint(
          () => formatter.printResults(resultDefault, false, true),
        );

        // When - Test when specifically targeting debug_test (don't suppress)
        final failedTestsTargeted = processor.extractFailedTests(
          combinedEvents,
          false,
          suppressDebugTests: false,
        );
        final resultTargeted = TestRunResult(
          failedTestsByFile: failedTestsTargeted,
          allEvents: combinedEvents,
          exitCode: 1,
        );

        final outputTargeted = await capturePrint(
          () => formatter.printResults(resultTargeted, false, true),
        );

        // Then
        // Default output should not contain debug test
        expect(outputDefault, isNot(contains('Debug Test Failure')));
        expect(outputDefault, isNot(contains('Error from debug test')));
        expect(outputDefault, contains('Normal Test Failure'));
        expect(outputDefault, contains('Error from normal test'));

        // Targeted output should contain both
        expect(outputTargeted, contains('Normal Test Failure'));
        expect(outputTargeted, contains('Debug Test Failure'));
        expect(outputTargeted, contains('Error from debug test'));
      },
    );
  });
}
