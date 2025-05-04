#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

// Constants
const String _helpFlag = 'help';
const String _debugFlag = 'debug';
const String _exceptFlag = 'except';
const bool _debugScript = false;

/// Represents a test command with working directory and relative test path
class TestCommand {
  final String workingDirectory;
  final String testPath;

  TestCommand({required this.workingDirectory, required this.testPath});
}

/// Finds the closest directory containing a pubspec.yaml file, starting from the test file path
/// This is used to determine the package root for tests in subpackages
Directory? findPackageRoot(String testPath) {
  final testFile = File(testPath);
  Directory? directory;

  if (path.isAbsolute(testPath)) {
    // For absolute paths, start from the file's parent directory
    directory = testFile.parent;
  } else {
    // For relative paths, resolve against current directory first
    directory = Directory(
      path.join(Directory.current.path, path.dirname(testPath)),
    );
  }

  // Traverse up the directory structure looking for pubspec.yaml
  while (directory != null) {
    final pubspecFile = File(path.join(directory.path, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      return directory;
    }

    // Move up one directory
    final parent = directory.parent;
    // If we've reached the filesystem root, stop
    if (parent.path == directory.path) {
      return null;
    }
    directory = parent;
  }

  return null;
}

/// Generates a TestCommand object with the working directory and relative test path
/// This allows the script to run tests in the correct package context
TestCommand getTestCommandForPath(String testPath) {
  // Find the package root containing this test
  final packageRoot = findPackageRoot(testPath);

  if (packageRoot == null) {
    // If no package root found, use current directory as a fallback
    print('[WARN] No pubspec.yaml found in any parent directory of $testPath');
    return TestCommand(
      workingDirectory: Directory.current.path,
      testPath: testPath,
    );
  }

  // Convert the test path to be relative to the package root
  String relativePath;
  if (path.isAbsolute(testPath)) {
    // For absolute paths, make them relative to the package root
    relativePath = path.relative(testPath, from: packageRoot.path);
  } else {
    // For relative paths (from the current directory), we need to resolve them first
    final resolvedPath = path.normalize(
      path.join(Directory.current.path, testPath),
    );
    relativePath = path.relative(resolvedPath, from: packageRoot.path);
  }

  return TestCommand(
    workingDirectory: packageRoot.path,
    testPath: relativePath,
  );
}

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
    final List<String> testTargets = argResults.rest;

    // Check if we're specifically targeting debug_test.dart
    final bool suppressDebugTests =
        !testTargets.any((target) => target.contains('debug_test.dart'));

    String targetMessage = '';
    if (testTargets.isEmpty) {
      targetMessage = '';
    } else if (testTargets.length == 1) {
      targetMessage = ' for target: ${testTargets.first}';
    } else {
      targetMessage = ' for targets: ${testTargets.join(', ')}';
    }

    print(
      'Running tests$targetMessage${debugMode ? ' in debug mode' : ''}${exceptMode ? ' showing exceptions only' : ''}...',
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
      testTargets,
      debugMode: debugMode,
      exceptMode: exceptMode,
      suppressDebugTests: suppressDebugTests,
    );

    formatter.printResults(result, debugMode, exceptMode);

    // Exit with proper code based on test results
    if (result.totalTestsFailed > 0) {
      exit(1); // Exit with non-zero code when tests fail
    }
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
      help: 'Show both console output and exception details for failed tests.',
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
    'Usage: ./scripts/list_failed_tests.dart [--debug] [--except] [test_target1 test_target2 ...]',
  );
  print('');
  print(
    'Run Flutter tests and list failed tests, optionally showing debug output.',
  );
  print('');
  print('Arguments:');
  print(
    '  [test_targets]  Optional. Paths to specific test files or directories.',
  );
  print('                 Multiple targets can be specified to run them all.');
  print('                 If omitted, all tests in the project are run.');
  print('');
  print('Multi-package support:');
  print(
    '  This script automatically detects the package directory for each test target,',
  );
  print(
    '  eliminating the need to manually change directories before running tests.',
  );
  print(
    '  Example: ./scripts/list_failed_tests.dart mock_api_server/test/auth_test.dart',
  );
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
    String? workingDirectory,
  });
}

/// Implementation of ProcessRunner using dart:io Process
class ProcessRunnerImpl implements ProcessRunner {
  @override
  Future<ProcessResult> runProcess(
    List<String> arguments, {
    bool runInShell = true,
    Map<String, String>? environment,
    String? workingDirectory,
  }) async {
    try {
      if (workingDirectory != null) {
        if (_debugScript) {
          print('[SCRIPT_DEBUG] Using working directory: $workingDirectory');
        }
      }

      final process = await Process.start(
        'flutter',
        arguments,
        runInShell: runInShell,
        environment: environment,
        workingDirectory: workingDirectory,
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
  /// Processes a list of test events and returns the processed results.
  ProcessedTestResult extractFailedTests(
    List<Map<String, dynamic>> allEvents,
    bool debugMode, {
    bool suppressDebugTests = true,
  }) {
    final Map<String, List<FailedTest>> failedTestsByFile = {};
    final Map<int, Map<String, dynamic>> errorEventsById = {};
    final Map<int, Map<String, dynamic>> testStartEventsById = {};
    int totalTestsRun = 0; // Initialize total test counter

    // First pass: collect explicit error events and testStart events
    for (final event in allEvents) {
      if (event['type'] == 'error' && event['testID'] != null) {
        errorEventsById[event['testID']] = event;
        if (_debugScript) {
          print(
            '[SCRIPT_DEBUG] Found explicit error event for testID: ${event['testID']}',
          );
        }
      } else if (event['type'] == 'testStart' && event['test']?['id'] != null) {
        testStartEventsById[event['test']['id']] = event;
      }
    }

    // Second pass: process testDone events for failures/errors AND count totals
    for (final event in allEvents) {
      if (event['type'] == 'testDone') {
        totalTestsRun++; // Count every test completion

        if (event['result'] == 'failure' || event['result'] == 'error') {
          final int testId = event['testID'] as int? ?? -1;
          if (testId == -1) {
            stderr.writeln(
              '[WARN] Found failed/error testDone event with missing testID: $event',
            );
            continue;
          }

          final testStartEvent = testStartEventsById[testId];

          // Add warning for missing test start event
          if (testStartEvent == null) {
            stderr.writeln(
              '[WARN] Could not find testStart event for failed/error testID: $testId',
            );
            // Attempt to find *some* file association if possible, maybe from error?
            // For now, we'll likely end up with unknown_file.dart below.
          }

          final testInfo =
              testStartEvent?['test'] as Map<String, dynamic>? ?? {};
          String? filePathUrl = testInfo['url'] as String?;
          final String testName =
              testInfo['name'] as String? ?? 'Unknown Test Name';

          String filePath;
          if (filePathUrl != null && filePathUrl.isNotEmpty) {
            filePath = _getRelativePath(filePathUrl);
          } else if (testName.startsWith('loading ')) {
            // Try extracting path from name for loading errors
            final potentialPath = testName.substring('loading '.length);
            // Basic check if it looks like a path
            if (potentialPath.contains('/') &&
                potentialPath.endsWith('.dart')) {
              filePath = _getRelativePath(
                potentialPath,
              ); // Use existing helper, assumes it can handle absolute paths
            } else {
              filePath = 'unknown_file.dart'; // Fallback
            }
          } else {
            filePath =
                'unknown_file.dart'; // Fallback if no URL and not a loading error
            if (testStartEvent != null) {
              // Only warn if we actually had a start event but no URL
              stderr.writeln(
                '[WARN] Test $testName (ID: $testId) failed but has no associated file URL. Grouping under unknown_file.dart.',
              );
            }
          }

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
    }
    return ProcessedTestResult(
      failedTestsByFile: failedTestsByFile,
      totalTestsRun: totalTestsRun,
    );
  }

  String _getRelativePath(String? pathOrUrl) {
    if (pathOrUrl == null) return 'unknown_file.dart';
    String path = pathOrUrl.replaceFirst('file://', '');
    try {
      final projectRoot = Directory.current.path;
      if (path.startsWith(projectRoot)) {
        path = path.substring(projectRoot.length + 1);
      }
      // Remove leading slash if it's still absolute after potential projectRoot removal
      // (e.g., if the path was outside the project root but still absolute)
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
    final int failedCount = result.totalTestsFailed;
    final int totalCount = result.totalTestsRun;

    if (failedCount == 0) {
      print('No failed tests found.');
      print('All $totalCount tests passed.'); // Summary for passed tests

      // Add tip about specifying test target if no target was provided
      if (result.testTargets == null || result.testTargets!.isEmpty) {
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
    if (!debugMode && !exceptMode && failedCount > 0) {
      // Only show debug tip if tests failed
      print('');
      print(
        '\x1B[33mTip: Run with --debug to see both console output and exception details from the failing tests.\x1B[0m',
      );
    }
    if (!exceptMode && failedCount > 0) {
      // Only show except tip if tests failed
      print(
        '\x1B[33mTip: Run with --except to see exception details (grouped by file).\x1B[0m',
      );
    }

    // Add tip about specifying test target if no target was provided
    if (result.testTargets == null || result.testTargets!.isEmpty) {
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
      print(
        '\x1B[33m     ./scripts/list_failed_tests.dart path/to/test_file1.dart path/to/test_file2.dart\x1B[0m',
      );
    }

    // --- Add Summary ---
    print(''); // Blank line before summary
    if (failedCount > 0) {
      print(
        '[31mSummary: $failedCount/$totalCount tests failed.[0m',
      ); // Red summary
    } else {
      // Already printed "All X tests passed." above if failedCount is 0
    }
    // --- End Summary ---
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
        final String displayName =
            failure.name.startsWith('loading ')
                ? 'File loading error' // Display generic name for loading errors
                : failure.name; // Display original name otherwise

        print('  • \x1B[31mTest: $displayName\x1B[0m');

        // --- MODIFIED LOGIC ---
        // Always print exception details if available, unless in default mode
        if (debugMode || exceptMode) {
          _printSingleExceptionDetail(failure);
        }
        // Additionally, print console output if debugMode is true
        if (debugMode) {
          // Add a small separator if both are printed
          if (failure.error != null || failure.stackTrace != null) {
            print('    --- '); // Separator
          }
          _printDebugConsoleOutput(failure.id, allEvents);
        }
        // Default mode (neither debugMode nor exceptMode) prints nothing extra
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
    final List<String> testTargets = args.isNotEmpty ? args : [];

    // Check if we have test targets that need package-specific handling
    if (testTargets.isEmpty) {
      // No specific targets - run in the current directory as before
      return await _runTestsInContext(
        [],
        debugMode: debugMode,
        exceptMode: exceptMode,
        suppressDebugTests: suppressDebugTests,
      );
    } else if (testTargets.length == 1) {
      // Single target - check if it's in a subpackage
      final testCommand = getTestCommandForPath(testTargets.first);

      if (_debugScript) {
        print(
          '[SCRIPT_DEBUG] Determined package root: ${testCommand.workingDirectory}',
        );
        print('[SCRIPT_DEBUG] Relative test path: ${testCommand.testPath}');
      }

      return await _runTestsInContext(
        [testCommand.testPath],
        debugMode: debugMode,
        exceptMode: exceptMode,
        suppressDebugTests: suppressDebugTests,
        workingDirectory: testCommand.workingDirectory,
      );
    } else {
      // Multiple targets - check if they're all in the same package
      final workingDirs = <String>{};
      final adjustedPaths = <String>[];

      for (final target in testTargets) {
        final testCommand = getTestCommandForPath(target);
        workingDirs.add(testCommand.workingDirectory);
        adjustedPaths.add(testCommand.testPath);
      }

      if (workingDirs.length == 1) {
        // All targets in the same package
        final workingDir = workingDirs.first;

        if (_debugScript) {
          print(
            '[SCRIPT_DEBUG] All test targets in the same package: $workingDir',
          );
        }

        return await _runTestsInContext(
          adjustedPaths,
          debugMode: debugMode,
          exceptMode: exceptMode,
          suppressDebugTests: suppressDebugTests,
          workingDirectory: workingDir,
        );
      } else {
        // Targets span multiple packages - can't run them all together
        print(
          '\x1B[33mWarning: Test targets span multiple packages and cannot be run together.\x1B[0m',
        );
        print('\x1B[33mPlease run tests for each package separately:\x1B[0m');

        // Group targets by package
        final Map<String, List<String>> testsByPackage = {};
        for (int i = 0; i < testTargets.length; i++) {
          final testCommand = getTestCommandForPath(testTargets[i]);
          testsByPackage
              .putIfAbsent(testCommand.workingDirectory, () => [])
              .add(testTargets[i]);
        }

        // Show suggested commands
        for (final entry in testsByPackage.entries) {
          print(
            '\x1B[33m  ./scripts/list_failed_tests.dart ${entry.value.join(' ')}\x1B[0m',
          );
        }

        // Run tests in the current directory
        return await _runTestsInContext(
          testTargets,
          debugMode: debugMode,
          exceptMode: exceptMode,
          suppressDebugTests: suppressDebugTests,
        );
      }
    }
  }

  /// Internal method to run tests in the specified working directory
  Future<TestRunResult> _runTestsInContext(
    List<String> testTargets, {
    required bool debugMode,
    required bool exceptMode,
    bool suppressDebugTests = true,
    String? workingDirectory,
  }) async {
    final arguments = ['test', '--machine'];
    if (testTargets.isNotEmpty) {
      arguments.addAll(testTargets);
    }

    // Prepare environment variables specifically for the debug test
    Map<String, String>? environment;
    if (testTargets.any((target) => target.contains('debug_test.dart'))) {
      environment = {'DEBUG_TEST_SHOULD_FAIL': 'true'};
      if (_debugScript) {
        print(
          '[SCRIPT_DEBUG] Activating DEBUG_TEST_SHOULD_FAIL for debug_test.dart',
        );
      }
    }

    if (_debugScript) {
      print('[SCRIPT_DEBUG] Starting flutter test with arguments: $arguments');
      if (environment != null) {
        print('[SCRIPT_DEBUG] Using environment: $environment');
      }
      if (workingDirectory != null) {
        print('[SCRIPT_DEBUG] Using working directory: $workingDirectory');
      }
    }

    final processResult = await processRunner.runProcess(
      arguments,
      environment: environment,
      workingDirectory: workingDirectory,
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

    final processedResult = eventProcessor.extractFailedTests(
      allEvents,
      debugMode,
      suppressDebugTests: suppressDebugTests,
    );

    return TestRunResult(
      failedTestsByFile: processedResult.failedTestsByFile,
      allEvents: allEvents,
      exitCode: processResult.exitCode,
      testTargets: testTargets.isNotEmpty ? testTargets : null,
      totalTestsRun: processedResult.totalTestsRun,
      totalTestsFailed: processedResult.totalTestsFailed,
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
  final List<String>? testTargets;
  final int totalTestsRun;
  final int totalTestsFailed;

  TestRunResult({
    required this.failedTestsByFile,
    required this.allEvents,
    required this.exitCode,
    this.testTargets,
    required this.totalTestsRun,
    required this.totalTestsFailed,
  });
}

// --- Corrected Class to hold processed results ---
class ProcessedTestResult {
  final Map<String, List<FailedTest>> failedTestsByFile;
  final int totalTestsRun;
  final int totalTestsFailed;

  ProcessedTestResult({
    required this.failedTestsByFile,
    required this.totalTestsRun,
  }) : totalTestsFailed = failedTestsByFile.values.fold(
         0,
         (sum, list) => sum + list.length,
       );
}
