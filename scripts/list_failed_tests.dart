#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

// Constants
const String _helpFlag = 'help';
const String _debugFlag = 'debug';
const String _exceptFlag = 'except';
const bool _debugScript = false;

/// Main entry point for the script
void main(List<String> arguments) async {
  try {
    final parser = _buildArgParser();
    final argResults = parser.parse(arguments);

    if (argResults[_helpFlag]) {
      _printUsage(parser);
      exit(0);
    }

    final bool debugMode = argResults[_debugFlag];
    final bool exceptMode = argResults[_exceptFlag];
    final String? testTarget =
        argResults.rest.isNotEmpty ? argResults.rest.first : null;

    // Check if we're specifically targeting debug_test.dart
    final bool suppressDebugTests =
        testTarget == null || !testTarget.contains('debug_test.dart');

    print(
      'Running tests${testTarget != null ? ' for target: $testTarget' : ''}${debugMode ? ' in debug mode' : ''}${exceptMode ? ' showing exceptions only' : ''}...',
    );

    final processRunner = ProcessRunnerImpl();
    final eventProcessor = TestEventProcessor();
    final formatter = ResultFormatter();
    final runner = FailedTestRunner(
      processRunner: processRunner,
      eventProcessor: eventProcessor,
      formatter: formatter,
    );

    final result = await runner.run(
      argResults.rest,
      debugMode: debugMode,
      exceptMode: exceptMode,
      suppressDebugTests: suppressDebugTests,
    );

    formatter.printResults(result, debugMode, exceptMode);
  } on FormatException catch (e) {
    stderr.writeln('Error parsing arguments: ${e.message}');
    _printUsage(_buildArgParser());
    exit(64); // Command line usage error
  } catch (e, s) {
    stderr.writeln('An unexpected error occurred: $e\n$s');
    exit(1);
  }
}

/// Builds the argument parser
ArgParser _buildArgParser() {
  return ArgParser()
    ..addFlag(
      _helpFlag,
      abbr: 'h',
      negatable: false,
      help: 'Display this help message and exit.',
    )
    ..addFlag(
      _debugFlag,
      abbr: 'd',
      negatable: false,
      help:
          'Show console output captured *during* the execution of failed tests only.',
    )
    ..addFlag(
      _exceptFlag,
      abbr: 'e',
      negatable: false,
      help:
          'Show only the exception details (error message and stack trace) for failed tests.',
    );
}

/// Prints usage information
void _printUsage(ArgParser parser) {
  print(
    'Usage: ./scripts/list_failed_tests_ng.dart [--debug] [--except] [test_target]',
  );
  print('');
  print(
    'Run Flutter tests and list failed tests, optionally showing debug output.',
  );
  print('');
  print('Arguments:');
  print(
    '  [test_target]  Optional. Path to a specific test file or directory.',
  );
  print('                 If omitted, all tests in the project are run.');
  print('');
  print('Options:');
  print(parser.usage);
}

/// Class for running process and collecting results
abstract class ProcessRunner {
  Future<ProcessResult> runProcess(
    List<String> arguments, {
    bool runInShell = true,
    Map<String, String>? environment,
  });
}

/// Implementation of ProcessRunner using dart:io Process
class ProcessRunnerImpl implements ProcessRunner {
  @override
  Future<ProcessResult> runProcess(
    List<String> arguments, {
    bool runInShell = true,
    Map<String, String>? environment,
  }) async {
    try {
      final process = await Process.start(
        'flutter',
        arguments,
        runInShell: runInShell,
        environment: environment,
      );

      final stdoutCompleter = Completer<String>();
      final stderrCompleter = Completer<String>();
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      process.stdout
          .transform(utf8.decoder)
          .listen(
            (data) => stdoutBuffer.write(data),
            onDone: () => stdoutCompleter.complete(stdoutBuffer.toString()),
            onError: stderrCompleter.completeError,
          );

      process.stderr
          .transform(utf8.decoder)
          .listen(
            (data) => stderrBuffer.write(data),
            onDone: () => stderrCompleter.complete(stderrBuffer.toString()),
            onError: stderrCompleter.completeError,
          );

      final exitCode = await process.exitCode;
      final stdout = await stdoutCompleter.future;
      final stderr = await stderrCompleter.future;

      return ProcessResult(process.pid, exitCode, stdout, stderr);
    } catch (e) {
      if (e is ProcessException) {
        if (e.executable == 'flutter' && e.arguments.first == 'test') {
          stderr.writeln(
            'Make sure the Flutter SDK is installed and in your PATH.',
          );
        }
        rethrow;
      }
      rethrow;
    }
  }
}

/// Class to process test events and extract failed tests
class TestEventProcessor {
  Map<String, List<FailedTest>> extractFailedTests(
    List<Map<String, dynamic>> allEvents,
    bool debugMode, {
    bool suppressDebugTests = true,
  }) {
    final Map<String, List<FailedTest>> failedTestsByFile = {};
    final Map<int, Map<String, dynamic>> errorEventsById = {};

    // First pass: collect explicit error events
    for (final event in allEvents) {
      if (event['type'] == 'error' && event['testID'] != null) {
        errorEventsById[event['testID']] = event;
        if (_debugScript) {
          print(
            '[SCRIPT_DEBUG] Found explicit error event for testID: ${event['testID']}',
          );
        }
      }
    }

    // Second pass: process testDone events for failures/errors
    for (final event in allEvents) {
      if (event['type'] == 'testDone' &&
          (event['result'] == 'failure' || event['result'] == 'error')) {
        final int testId = event['testID'] as int? ?? -1;
        if (testId == -1) {
          stderr.writeln(
            '[WARN] Found failed/error testDone event with missing testID: $event',
          );
          continue;
        }

        final testStartEvent = allEvents.lastWhere(
          (e) => e['type'] == 'testStart' && e['test']?['id'] == testId,
          orElse:
              () => {
                'test': {'url': 'unknown_file.dart'},
              },
        );

        // Add warning for missing test start event
        if (testStartEvent['type'] != 'testStart') {
          stderr.writeln(
            '[WARN] Could not find testStart event for failed/error testID: $testId',
          );
        }

        final testInfo = testStartEvent['test'] as Map<String, dynamic>? ?? {};
        final String filePath = _getRelativePath(testInfo['url'] as String?);
        final String testName =
            testInfo['name'] as String? ?? 'Unknown Test Name';

        // Skip debug_test.dart unless explicitly targeted
        if (suppressDebugTests && filePath.contains('debug_test.dart')) {
          continue;
        }

        // Get error information
        final errorEvent = errorEventsById[testId];
        final String? error =
            errorEvent?['error'] as String? ?? event['error'] as String?;
        final String? stackTrace =
            errorEvent?['stackTrace'] as String? ??
            event['stackTrace'] as String?;

        final failedTest = FailedTest(
          id: testId,
          name: testName,
          error: error,
          stackTrace: stackTrace,
          testDoneEvent: event,
          errorEvent: errorEvent,
        );

        failedTestsByFile.putIfAbsent(filePath, () => []).add(failedTest);
      }
    }
    return failedTestsByFile;
  }

  String _getRelativePath(String? fileUrl) {
    if (fileUrl == null) return 'unknown_file.dart';
    String path = fileUrl.replaceFirst('file://', '');
    try {
      final projectRoot = Directory.current.path;
      if (path.startsWith(projectRoot)) {
        path = path.substring(projectRoot.length + 1);
      }
      if (path.startsWith('/')) {
        path = path.substring(1);
      }
    } catch (e) {
      stderr.writeln('[WARN] Could not determine project root directory: $e');
    }
    return path;
  }
}

/// Data class to hold information about failed tests
class FailedTest {
  final int id;
  final String name;
  final String? error;
  final String? stackTrace;
  final Map<String, dynamic> testDoneEvent;
  final Map<String, dynamic>? errorEvent;

  FailedTest({
    required this.id,
    required this.name,
    this.error,
    this.stackTrace,
    required this.testDoneEvent,
    this.errorEvent,
  });
}

/// Class to handle test result formatting
class ResultFormatter {
  void printResults(TestRunResult result, bool debugMode, bool exceptMode) {
    if (result.failedTestsByFile.isEmpty) {
      print('No failed tests found.');

      // Add tip about specifying test target if no target was provided
      if (result.testTarget == null) {
        print('');
        print(
          '\x1B[33mTip: You can run with a specific path or directory to test only a subset of tests:\x1B[0m',
        );
        print(
          '\x1B[33m     ./scripts/list_failed_tests.dart path/to/test_file.dart\x1B[0m',
        );
        print(
          '\x1B[33m     ./scripts/list_failed_tests.dart path/to/test_directory\x1B[0m',
        );
      }
      return;
    }

    // Unified printing logic
    _printGroupedResults(
      result.failedTestsByFile,
      debugMode,
      exceptMode,
      result.allEvents,
    );

    // Print summary header only if not in except mode (which has its own header/footer)
    if (!exceptMode) {
      print('');
      print('Failed tests grouped by source file');
    }

    // Add helpful hints
    if (!debugMode && !exceptMode) {
      print('');
      print(
        '\x1B[33mTip: Run with --debug to see console output from the failing tests.\x1B[0m',
      );
    }
    if (!exceptMode) {
      // Show except tip unless already in except mode
      print(
        '\x1B[33mTip: Run with --except to see exception details (grouped by file).\x1B[0m',
      );
    }

    // Add tip about specifying test target if no target was provided
    if (result.testTarget == null) {
      print('');
      print(
        '\x1B[33mTip: You can run with a specific path or directory to test only a subset of tests:\x1B[0m',
      );
      print(
        '\x1B[33m     ./scripts/list_failed_tests.dart path/to/test_file.dart\x1B[0m',
      );
      print(
        '\x1B[33m     ./scripts/list_failed_tests.dart path/to/test_directory\x1B[0m',
      );
    }
  }

  // Renamed and refactored from _printFailedTestDetails
  void _printGroupedResults(
    Map<String, List<FailedTest>> failedTestsByFile,
    bool debugMode,
    bool exceptMode,
    List<Map<String, dynamic>> allEvents,
  ) {
    final sortedFiles = failedTestsByFile.keys.toList()..sort();

    // Print header specific to except mode
    if (exceptMode) {
      print('');
      print('\x1B[31m--- Failed Test Exceptions (Grouped by File) ---\x1B[0m');
    }

    for (final filePath in sortedFiles) {
      print(''); // Blank line between files
      print(
        '\x1B[31mFailed tests in: $filePath\x1B[0m',
      ); // Red color for file path

      final tests = failedTestsByFile[filePath]!;
      for (final failure in tests) {
        // Make the test name red
        print('  • \x1B[31mTest: ${failure.name}\x1B[0m');

        // Conditionally print details based on mode
        if (exceptMode) {
          _printSingleExceptionDetail(failure);
        } else if (debugMode) {
          _printDebugConsoleOutput(failure.id, allEvents);
        }
        // Default mode: print nothing extra
      }
    }

    // Print footer specific to except mode
    if (exceptMode) {
      print('');
      print('\x1B[31m--- End of Exceptions ---\x1B[0m');
    }
  }

  void _printDebugConsoleOutput(
    int testId,
    List<Map<String, dynamic>> allEvents,
  ) {
    print(
      '    \x1B[36m--- Console output ---\x1B[0m',
    ); // Cyan color for debug header

    final testStartIndex = allEvents.indexWhere(
      (e) => e['type'] == 'testStart' && e['test']?['id'] == testId,
    );
    final testDoneIndex = allEvents.indexWhere(
      (e) => e['type'] == 'testDone' && e['testID'] == testId,
    );

    int? startMillis;
    int? endMillis;

    if (testStartIndex != -1) {
      startMillis = allEvents[testStartIndex]['time'] as int?;
    }
    if (testDoneIndex != -1) {
      endMillis = allEvents[testDoneIndex]['time'] as int?;
    }

    if (startMillis != null && endMillis != null) {
      final relevantPrintEvents =
          allEvents.where((event) {
            if (event['type'] != 'print') return false;
            final timeMillis = event['time'] as int?;
            if (timeMillis == null) return false;
            return timeMillis >= startMillis! && timeMillis <= endMillis!;
          }).toList();

      final startDateTime = DateTime.fromMillisecondsSinceEpoch(startMillis);
      final endDateTime = DateTime.fromMillisecondsSinceEpoch(endMillis);

      if (relevantPrintEvents.isNotEmpty) {
        print(
          '      (Showing console output captured between $startDateTime and $endDateTime)',
        );
        for (final printEvent in relevantPrintEvents) {
          final message = printEvent['message'] as String? ?? '';
          message.split('\n').forEach((line) {
            print('      $line'); // Indent output
          });
        }
      } else {
        print(
          '      (No console output captured between $startDateTime and $endDateTime)',
        );
      }
    } else {
      stderr.writeln(
        '[WARN] Could not determine time window for test $testId - unable to show console output',
      );
    }
    print(
      '    \x1B[36m--- End of output ---\x1B[0m',
    ); // Cyan color for debug footer
  }

  // --- Helper for printing exception details for a single test ---
  void _printSingleExceptionDetail(FailedTest failure) {
    final error = failure.error;
    final stackTrace = failure.stackTrace;

    // Indent level for details
    const indent = '    '; // 4 spaces
    const errorIndent = '       '; // Alignment for multi-line errors
    const stackIndent = '      '; // Alignment for stack lines

    if (error != null || stackTrace != null) {
      if (error != null) {
        final errorLines = error.split('\n');
        print('$indent\x1B[31mError:\x1B[0m ${errorLines.first}');
        for (int i = 1; i < errorLines.length; i++) {
          print('$errorIndent${errorLines[i]}');
        }
      } else {
        print('$indent\x1B[31mError:\x1B[0m (No error message provided)');
      }

      if (stackTrace != null) {
        print('$indent\x1B[90mStack Trace:\x1B[0m'); // Dim color
        stackTrace.split('\n').forEach((line) {
          if (line.trim().isNotEmpty) {
            print('$stackIndent$line');
          }
        });
      } else {
        print('$indent\x1B[90mStack Trace:\x1B[0m (No stack trace provided)');
      }
    } else {
      print(
        '$indent\x1B[33m(No exception details found in test event data)\x1B[0m',
      );
    }
  }

  // Method removed, logic moved to _printGroupedResults and _printSingleExceptionDetail
  // void _printExceptionDetails(
  //   Map<String, List<FailedTest>> failedTestsByFile,
  //   List<Map<String, dynamic>> allEvents,
  // ) { ... }
}

/// Main runner class that orchestrates the test process
class FailedTestRunner {
  final ProcessRunner processRunner;
  final TestEventProcessor eventProcessor;
  final ResultFormatter formatter;

  FailedTestRunner({
    required this.processRunner,
    required this.eventProcessor,
    required this.formatter,
  });

  Future<TestRunResult> run(
    List<String> args, {
    required bool debugMode,
    required bool exceptMode,
    bool suppressDebugTests = true,
  }) async {
    final testTarget = args.isNotEmpty ? args.first : null;
    final arguments = ['test', '--machine'];
    if (testTarget != null) {
      arguments.add(testTarget);
    }

    // Prepare environment variables specifically for the debug test
    Map<String, String>? environment;
    if (testTarget != null && testTarget.contains('debug_test.dart')) {
      environment = {'DEBUG_TEST_SHOULD_FAIL': 'true'};
      if (_debugScript) {
        print(
          '[SCRIPT_DEBUG] Activating DEBUG_TEST_SHOULD_FAIL for $testTarget',
        );
      }
    }

    if (_debugScript) {
      print('[SCRIPT_DEBUG] Starting flutter test with arguments: $arguments');
      if (environment != null) {
        print('[SCRIPT_DEBUG] Using environment: $environment');
      }
    }

    final processResult = await processRunner.runProcess(
      arguments,
      environment: environment,
    );

    if (processResult.exitCode != 0 && processResult.exitCode != 1) {
      stderr.writeln(
        'flutter test command failed unexpectedly with exit code ${processResult.exitCode}',
      );
      throw Exception(
        'Test process failed with exit code ${processResult.exitCode}',
      );
    }

    final stdout = processResult.stdout as String;
    final allEvents = _parseEvents(stdout);

    print('Processing ${allEvents.length} test events...');

    final failedTestsByFile = eventProcessor.extractFailedTests(
      allEvents,
      debugMode,
      suppressDebugTests: suppressDebugTests,
    );

    return TestRunResult(
      failedTestsByFile: failedTestsByFile,
      allEvents: allEvents,
      exitCode: processResult.exitCode,
      testTarget: testTarget,
    );
  }

  List<Map<String, dynamic>> _parseEvents(String stdout) {
    final List<Map<String, dynamic>> allEvents = [];

    final lines = stdout.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        if (line.startsWith('[') && line.endsWith(']')) {
          final List<dynamic> listEvents = jsonDecode(line);
          for (var item in listEvents) {
            if (item is Map<String, dynamic>) {
              allEvents.add(item);
            }
          }
        } else {
          final event = jsonDecode(line) as Map<String, dynamic>;
          allEvents.add(event);
        }
      } catch (e) {
        if (_debugScript) {
          print('[SCRIPT_DEBUG] Failed to parse JSON line: $line\nError: $e');
        }
      }
    }

    return allEvents;
  }
}

/// Results from a test run
class TestRunResult {
  final Map<String, List<FailedTest>> failedTestsByFile;
  final List<Map<String, dynamic>> allEvents;
  final int exitCode;
  final String? testTarget;

  TestRunResult({
    required this.failedTestsByFile,
    required this.allEvents,
    required this.exitCode,
    this.testTarget,
  });
}
