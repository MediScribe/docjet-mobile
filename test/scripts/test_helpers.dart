import 'dart:io';

import 'package:test/test.dart';
import '../../scripts/list_failed_tests.dart' as script;

/// Helper functions to create test events for testing

/// Creates a test start event
Map<String, dynamic> createTestStartEvent(
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

/// Creates an error event
Map<String, dynamic> createErrorEvent(
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

/// Creates a test done event
Map<String, dynamic> createTestDoneEvent(
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

/// Creates a print event
Map<String, dynamic> createPrintEvent(int testId, String message, int time) {
  return {"type": "print", "testID": testId, "message": message, "time": time};
}

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
    String? workingDirectory,
  }) async {
    capturedArguments = arguments;
    capturedEnvironment = environment;
    return result;
  }
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

/// Creates a mock process result for testing
ProcessResult createMockProcessResult({
  required int exitCode,
  dynamic stdout = '',
  dynamic stderr = '',
}) {
  return ProcessResult(123, exitCode, stdout, stderr);
}

/// Custom mock matchers to handle null safety issues with Mockito
class ListMatcher<T> extends Matcher {
  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) =>
      item is List<T>;

  @override
  Description describe(Description description) =>
      description.add('a List<$T>');
}

class MapMatcher<K, V> extends Matcher {
  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) =>
      item is Map<K, V>;

  @override
  Description describe(Description description) =>
      description.add('a Map<$K, $V>');
}

class BoolMatcher extends Matcher {
  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) => item is bool;

  @override
  Description describe(Description description) => description.add('a bool');
}

/// Matchers for Mockito compatibility
final listOfStrings = ListMatcher<String>();
final listOfDynamic = ListMatcher<dynamic>();
final mapStringDynamic = MapMatcher<String, dynamic>();
final boolMatcher = BoolMatcher();
