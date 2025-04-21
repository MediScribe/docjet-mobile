#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:args/args.dart';

// Import the logger using package import
// import 'package:docjet_mobile/core/utils/log_helpers.dart'; // REMOVED - Cannot use Flutter logger

// --- Script Configuration ---
// Controls internal script debugging print statements
const bool _debugScript = false;

// const String _scriptName = 'ListFailedTestsScript';
// final _logger = LoggerFactory.getLogger(_scriptName);
// final _tag = logTag(_scriptName);

const String _helpFlag = 'help';
const String _debugFlag = 'debug';

// --- Entry Point ---
void main(List<String> arguments) async {
  ArgResults? argResults = _parseArguments(arguments);
  if (argResults == null) return; // Error handled in _parseArguments

  final bool debugMode = argResults[_debugFlag];
  final String? testTarget =
      argResults.rest.isNotEmpty ? argResults.rest.first : null;

  // Reverted to print for status
  print(
    'Running tests${testTarget != null ? ' for target: $testTarget' : ''}${debugMode ? ' in debug mode' : ''}...',
  );

  try {
    final events = await _runTestsAndCollectEvents(testTarget, debugMode);
    final failedTests = _extractFailedTests(events, debugMode);
    _printTestResults(failedTests, debugMode, events);
  } on ProcessException catch (e) {
    // Reverted to stderr for errors
    stderr.writeln('Error starting flutter process: ${e.message}');
    if (e.executable == 'flutter' && e.arguments.first == 'test') {
      stderr.writeln(
        'Make sure the Flutter SDK is installed and in your PATH.',
      );
    }
    exit(e.errorCode);
  } catch (e, s) {
    // Reverted to stderr for errors
    stderr.writeln(
      'An unexpected error occurred during test execution or processing: $e\n$s',
    );
    exit(1);
  }
}

// --- Argument Parsing & Usage ---
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
    );
}

ArgResults? _parseArguments(List<String> arguments) {
  final parser = _buildArgParser();
  try {
    final results = parser.parse(arguments);
    if (results[_helpFlag]) {
      _printUsage(parser);
      exit(0);
    }
    return results;
  } on FormatException catch (e) {
    // Reverted to stderr for errors
    stderr.writeln('Error parsing arguments: ${e.message}');
    _printUsage(parser);
    exit(64); // Command line usage error
  }
}

void _printUsage(ArgParser parser) {
  print('Usage: ./scripts/list_failed_tests.dart [--debug] [test_target]');
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

// --- Test Execution & Event Processing ---
Future<List<Map<String, dynamic>>> _runTestsAndCollectEvents(
  String? testTarget,
  bool debugMode,
) async {
  final arguments = ['test', '--machine'];
  if (testTarget != null) {
    arguments.add(testTarget);
  }

  // Reverted to print for debug
  if (_debugScript) {
    print('[SCRIPT_DEBUG] Starting flutter test with arguments: $arguments');
  }
  final process = await _startTestProcess(arguments);

  final List<Map<String, dynamic>> allEvents = [];
  final completer = Completer<void>();

  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(
        (line) {
          // Reverted to print for debug
          // if (debugMode) { // This was the RAW output, keep commented
          //   print('[DEBUG] RAW_STDOUT: $line'); // REMOVED - Too noisy
          // }
          try {
            final event = jsonDecode(line) as Map<String, dynamic>;
            allEvents.add(event);
          } catch (e) {
            // Reverted to print for debug
            if (_debugScript) {
              print(
                '[SCRIPT_DEBUG] Failed to parse JSON line: $line\nError: $e',
              );
            }
            // Handle potentially malformed JSON like: [{"event":"test.startedProcess...}]
            if (line.startsWith('[') && line.endsWith(']')) {
              try {
                final List<dynamic> listEvents = jsonDecode(line);
                for (var item in listEvents) {
                  if (item is Map<String, dynamic>) {
                    allEvents.add(item);
                    // Reverted to print for debug
                    if (_debugScript) {
                      print('[SCRIPT_DEBUG] Parsed list item: $item');
                    }
                  } else {
                    // Reverted to print for debug
                    if (_debugScript) {
                      print('[SCRIPT_DEBUG] Non-map item in list: $item');
                    }
                  }
                }
              } catch (listError) {
                // Reverted to print for debug
                if (_debugScript) {
                  print(
                    '[SCRIPT_DEBUG] Failed to parse list JSON line: $line\nError: $listError',
                  );
                }
              }
            }
          }
        },
        onDone: () => completer.complete(),
        onError: (e, s) {
          // Reverted to stderr for errors
          stderr.writeln('Error reading stdout from flutter test: $e\n$s');
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
      );

  final exitCode = await process.exitCode;
  // Reverted to print for debug
  if (_debugScript) {
    print(
      '[SCRIPT_DEBUG] flutter test process finished with exit code: $exitCode',
    );
  }

  // Ensure stdout stream is fully processed before continuing
  await completer.future;

  if (exitCode != 0 && exitCode != 1) {
    // Reverted to stderr for errors
    stderr.writeln(
      'flutter test command failed unexpectedly with exit code $exitCode',
    );
    exit(exitCode);
  }

  // Reverted to print for status
  print('Processing ${allEvents.length} test events...');
  return allEvents;
}

Future<Process> _startTestProcess(List<String> arguments) async {
  try {
    return await Process.start('flutter', arguments, runInShell: true);
  } catch (e) {
    // Let the main try-catch handle this ProcessException
    rethrow;
  }
}

// --- Failure Extraction ---
Map<String, List<Map<String, dynamic>>> _extractFailedTests(
  List<Map<String, dynamic>> allEvents,
  bool debugMode,
) {
  final Map<String, List<Map<String, dynamic>>> failedTestsByFile = {};

  for (final event in allEvents) {
    if (event['type'] == 'testDone' && event['result'] == 'failure') {
      final testStartEvent = allEvents.lastWhere(
        (e) => e['type'] == 'testStart' && e['test']?['id'] == event['testID'],
        orElse: () {
          // Reverted to stderr for warnings/errors
          stderr.writeln(
            '[WARN] Could not find testStart event for failed testID: ${event['testID']}',
          );
          return {
            'test': {'url': 'unknown_file.dart'},
          }; // Fallback
        },
      );

      final testInfo = testStartEvent['test'] as Map<String, dynamic>? ?? {};
      String filePath = _getRelativePath(testInfo['url'] as String?);
      final String testName =
          testInfo['name'] as String? ?? 'Unknown Test Name';
      final int testId = event['testID'] as int? ?? -1;

      final failureDetails = {
        'name': testName,
        'id': testId,
        'failureEvent': event,
      };

      failedTestsByFile.putIfAbsent(filePath, () => []).add(failureDetails);
      // Reverted to print for debug
      if (_debugScript) {
        print(
          '[SCRIPT_DEBUG] Found failed test: [$filePath] $testName (ID: $testId)',
        );
      }
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
  } catch (e) {
    // Reverted to stderr for warnings/errors
    stderr.writeln('[WARN] Could not determine project root directory: $e');
  }
  return path;
}

// --- Result Printing ---
void _printTestResults(
  Map<String, List<Map<String, dynamic>>> failedTestsByFile,
  bool debugMode,
  List<Map<String, dynamic>> allEvents,
) {
  if (failedTestsByFile.isEmpty) {
    print('No failed tests found.');
  } else {
    _printFailedTestDetails(failedTestsByFile, debugMode, allEvents);
    print('');
    print('Failed tests grouped by source file');

    // Add helpful hint about --debug if not already using it
    if (!debugMode) {
      print('');
      print(
        '\x1B[33mTip: Run with --debug to see console output from the failing tests.\x1B[0m',
      );
    }
  }
}

void _printFailedTestDetails(
  Map<String, List<Map<String, dynamic>>> failedTestsByFile,
  bool debugMode,
  List<Map<String, dynamic>> allEvents,
) {
  final sortedFiles = failedTestsByFile.keys.toList()..sort();

  for (final filePath in sortedFiles) {
    print(''); // Blank line between files
    print(
      '\x1B[31mFailed tests in: $filePath\x1B[0m',
    ); // Red color for file path

    final tests = failedTestsByFile[filePath]!;
    for (final failure in tests) {
      final testName = failure['name'] as String;
      final testId = failure['id'] as int;
      print('  • Test: $testName');

      if (debugMode) {
        _printDebugConsoleOutput(testId, allEvents);
      }
    }
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
          // Only compare if timeMillis is also not null
          if (timeMillis == null) return false;
          // Now all three are guaranteed non-null for the comparison
          // Use ! because we've logically ensured non-nullity
          return timeMillis >= startMillis! && timeMillis <= endMillis!;
        }).toList();

    // Remove unnecessary bang operators here
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
    // Reverted to stderr for warnings/errors
    stderr.writeln(
      '[WARN] Could not determine time window for test $testId - unable to show console output',
    );
  }
  print(
    '    \x1B[36m--- End of output ---\x1B[0m',
  ); // Cyan color for debug footer
}
