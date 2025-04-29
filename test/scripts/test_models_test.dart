import 'package:test/test.dart';

import '../../scripts/list_failed_tests.dart' as script;

void main() {
  group('Model Classes', () {
    test('FailedTest class should store test information correctly', () {
      // Given
      const id = 1;
      const name = 'Test Name';
      const error = 'Error Message';
      const stackTrace = 'Stack Trace';
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

    test('ProcessedTestResult calculates totalTestsFailed correctly', () {
      // Given
      final failedTestsByFile = {
        'file1.dart': [
          script.FailedTest(
            id: 1,
            name: 'Test 1',
            error: 'Error 1',
            stackTrace: 'Stack 1',
            testDoneEvent: {'result': 'failure'},
            errorEvent: {'error': 'Error 1'},
          ),
          script.FailedTest(
            id: 2,
            name: 'Test 2',
            error: 'Error 2',
            stackTrace: 'Stack 2',
            testDoneEvent: {'result': 'failure'},
            errorEvent: {'error': 'Error 2'},
          ),
        ],
        'file2.dart': [
          script.FailedTest(
            id: 3,
            name: 'Test 3',
            error: 'Error 3',
            stackTrace: 'Stack 3',
            testDoneEvent: {'result': 'failure'},
            errorEvent: {'error': 'Error 3'},
          ),
        ],
      };

      // When
      final result = script.ProcessedTestResult(
        failedTestsByFile: failedTestsByFile,
        totalTestsRun: 10,
      );

      // Then
      expect(result.totalTestsFailed, 3);
      expect(result.totalTestsRun, 10);
    });

    test('TestRunResult stores all properties correctly', () {
      // Given
      final failedTestsByFile = {
        'file1.dart': [
          script.FailedTest(
            id: 1,
            name: 'Test 1',
            error: 'Error 1',
            stackTrace: 'Stack 1',
            testDoneEvent: {'result': 'failure'},
            errorEvent: {'error': 'Error 1'},
          ),
        ],
      };
      final allEvents = [
        {
          'type': 'testStart',
          'test': {'id': 1},
        },
        {'type': 'testDone', 'testID': 1, 'result': 'failure'},
      ];
      const exitCode = 1;
      final testTargets = ['file1.dart'];
      const totalTestsRun = 5;
      const totalTestsFailed = 1;

      // When
      final result = script.TestRunResult(
        failedTestsByFile: failedTestsByFile,
        allEvents: allEvents,
        exitCode: exitCode,
        testTargets: testTargets,
        totalTestsRun: totalTestsRun,
        totalTestsFailed: totalTestsFailed,
      );

      // Then
      expect(result.failedTestsByFile, failedTestsByFile);
      expect(result.allEvents, allEvents);
      expect(result.exitCode, exitCode);
      expect(result.testTargets, testTargets);
      expect(result.totalTestsRun, totalTestsRun);
      expect(result.totalTestsFailed, totalTestsFailed);
    });
  });
}
