import 'dart:async';

import 'package:test/test.dart';

import '../../scripts/list_failed_tests.dart' as script;
import './test_helpers.dart';

void main() {
  group('ResultFormatter', () {
    late script.ResultFormatter formatter;
    late script.TestEventProcessor processor;

    setUp(() {
      formatter = script.ResultFormatter();
      processor = script.TestEventProcessor();
    });

    // Helper function to capture print output
    Future<String> capturePrint(Function() action) async {
      final printedMessages = <String>[];
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
      const testId = 1;
      final startTime = DateTime.now().millisecondsSinceEpoch;
      final printTime1 = startTime + 50;
      final printTime2 = startTime + 60;
      final errorTime = startTime + 80;
      final endTime = startTime + 100;

      final allTestEvents = [
        createTestStartEvent(
          testId,
          'My Failing Test',
          'file:///app/test/debug_and_error_test.dart',
          startTime,
        ),
        createPrintEvent(testId, 'Console message one', printTime1),
        createPrintEvent(testId, 'Console message two', printTime2),
        createErrorEvent(
          testId,
          'Specific Error Message',
          'stack line 1\nstack line 2',
          errorTime,
        ),
        createTestDoneEvent(testId, 'failure', time: endTime),
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
        contains('Failed tests in: app/test/debug_and_error_test.dart'),
      );
      // Check test name
      expect(output, contains('Test: My Failing Test'));

      // Check for Console Output section in default mode - should not be present
      expect(output, isNot(contains('--- Console output ---')));
      expect(output, isNot(contains('Console message one')));
      expect(output, isNot(contains('Console message two')));

      // Check for Exception Details section in default mode - should not be present
      // The error message should NOT be shown in default mode (no debug, no except)
      expect(output, isNot(contains('Error: Specific Error Message')));
      expect(output, isNot(contains('Stack Trace:')));
      expect(output, isNot(contains('stack line 1')));
      expect(output, isNot(contains('stack line 2')));

      // Check Summary
      expect(output, contains('Summary: 1/1 tests failed'));

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
        const testId = 1;
        final startTime = DateTime.now().millisecondsSinceEpoch;
        final printTime1 = startTime + 50;
        final printTime2 = startTime + 60;
        final errorTime = startTime + 80;
        final endTime = startTime + 100;

        final allTestEvents = [
          createTestStartEvent(
            testId,
            'My Failing Test',
            'file:///app/test/debug_and_error_test.dart',
            startTime,
          ),
          createPrintEvent(testId, 'Console message one', printTime1),
          createPrintEvent(testId, 'Console message two', printTime2),
          createErrorEvent(
            testId,
            'Specific Error Message',
            'stack line 1\nstack line 2',
            errorTime,
          ),
          createTestDoneEvent(testId, 'failure', time: endTime),
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
          contains('--- Failed Test Exceptions (Grouped by File) ---'),
        );
        expect(
          output,
          contains('Failed tests in: app/test/debug_and_error_test.dart'),
        );
        // Check test name
        expect(output, contains('Test: My Failing Test'));

        // Check for Console Output section - should NOT be present in except mode
        expect(output, isNot(contains('--- Console output ---')));
        expect(output, isNot(contains('Console message one')));
        expect(output, isNot(contains('Console message two')));

        // Check for Exception Details section - SHOULD be present
        // ANSI color codes might be present in the output, making exact matching difficult
        // Use substring matching to avoid issues with color codes
        expect(output, contains('Error:'));
        expect(output, contains('Specific Error Message'));
        expect(output, contains('Stack Trace:'));
        expect(output, contains('stack line 1'));
        expect(output, contains('stack line 2'));

        // Check footer and summary
        expect(output, contains('--- End of Exceptions ---'));
        expect(output, contains('Summary: 1/1 tests failed'));
      },
    );

    test('printResults with debugMode shows console output and errors', () async {
      // Given
      const testId = 1;
      final startTime = DateTime.now().millisecondsSinceEpoch;
      final printTime1 = startTime + 50;
      final printTime2 = startTime + 60;
      final errorTime = startTime + 80;
      final endTime = startTime + 100;

      final allTestEvents = [
        createTestStartEvent(
          testId,
          'My Failing Test',
          'file:///app/test/debug_and_error_test.dart',
          startTime,
        ),
        createPrintEvent(testId, 'Console message one', printTime1),
        createPrintEvent(testId, 'Console message two', printTime2),
        createErrorEvent(
          testId,
          'Specific Error Message',
          'stack line 1\nstack line 2',
          errorTime,
        ),
        createTestDoneEvent(testId, 'failure', time: endTime),
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
        contains('Failed tests in: app/test/debug_and_error_test.dart'),
      );
      // Check test name
      expect(output, contains('Test: My Failing Test'));

      // Check for both console output and exception details sections
      expect(output, contains('--- Console output ---'));
      expect(output, contains('Console message one'));
      expect(output, contains('Console message two'));
      expect(output, contains('(Showing console output captured between'));
      expect(output, contains('--- End of output ---'));

      // Check for error details - use substring matching to avoid color code issues
      expect(output, contains('Error:'));
      expect(output, contains('Specific Error Message'));
      expect(output, contains('Stack Trace:'));
      expect(output, contains('stack line 1'));
      expect(output, contains('stack line 2'));

      // Check Summary
      expect(output, contains('Summary: 1/1 tests failed'));
    });

    test('printResults handles suppressDebugTests correctly', () async {
      // Given
      const testId1 = 1;
      const testId2 = 2;
      final startTime = DateTime.now().millisecondsSinceEpoch;
      final errorTime = startTime + 80;
      final endTime = startTime + 100;

      final allTestEvents = [
        createTestStartEvent(
          testId1,
          'Debug Test Failure',
          'file:///test/scripts/debug_test.dart',
          startTime,
        ),
        createErrorEvent(
          testId1,
          'Error from debug test',
          'Stack from debug test',
          errorTime,
        ),
        createTestDoneEvent(testId1, 'error', time: endTime),
        createTestStartEvent(
          testId2,
          'Normal Test Failure',
          'file:///test/some_other_test.dart',
          startTime,
        ),
        createErrorEvent(
          testId2,
          'Error from normal test',
          'Stack from normal test',
          errorTime,
        ),
        createTestDoneEvent(testId2, 'error', time: endTime),
      ];

      // When: Process with suppressDebugTests=true
      final processed = processor.extractFailedTests(
        allTestEvents,
        false,
        suppressDebugTests: true,
      );

      final result = script.TestRunResult(
        failedTestsByFile: processed.failedTestsByFile,
        allEvents: allTestEvents,
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
      expect(output, contains('Failed tests in: test/some_other_test.dart'));
      expect(output, contains('Normal Test Failure'));
      expect(output, isNot(contains('Debug Test Failure')));

      // Run with debug mode to see the error details
      final outputWithDebug = await capturePrint(
        () => formatter.printResults(result, true, false),
      );

      // Verify we see the error details of the normal test - using substring matching
      expect(outputWithDebug, contains('Error:'));
      expect(outputWithDebug, contains('Error from normal test'));
      expect(outputWithDebug, contains('Stack from normal test'));
    });
  });
}
