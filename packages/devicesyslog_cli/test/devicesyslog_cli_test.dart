import 'dart:async';
import 'dart:convert';
import 'dart:io'; // For ProcessResult, exit codes etc

import 'package:devicesyslog_cli/src/cli_runner.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as path;
import 'package:process/process.dart';
import 'package:test/test.dart';

// Generate mocks for ProcessManager and Process
@GenerateMocks([ProcessManager])
import 'devicesyslog_cli_test.mocks.dart'; // Import generated mocks

// Create a custom Process class to facilitate mocking
class MockProcess extends Mock implements Process {
  final Stream<List<int>> _stdout;
  final Stream<List<int>> _stderr;
  final Future<int> _exitCode;

  MockProcess({
    Stream<List<int>>? stdout,
    Stream<List<int>>? stderr,
    Future<int>? exitCode,
  })  : _stdout = stdout ?? Stream<List<int>>.empty(),
        _stderr = stderr ?? Stream<List<int>>.empty(),
        _exitCode = exitCode ?? Future.value(0);

  @override
  Stream<List<int>> get stdout => _stdout;

  @override
  Stream<List<int>> get stderr => _stderr;

  @override
  Future<int> get exitCode => _exitCode;

  @override
  int get pid => 12345; // Dummy PID

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);
}

void main() {
  late MockProcessManager mockProcessManager;

  setUp(() {
    mockProcessManager = MockProcessManager();
  });

  group('Device Detection and Handling', () {
    test('should exit with non-zero if no device is paired', () async {
      // Simulate ProcessManager.run returning an empty stdout (no devices)
      final processResult =
          ProcessResult(0, 0, '', ''); // pid, exitCode, stdout, stderr
      when(mockProcessManager.run(any)).thenAnswer((_) async => processResult);

      final runner = CliRunner(processManager: mockProcessManager);
      final exitCode = await runner
          .run([]); // No specific args, should trigger device detection

      expect(exitCode, isNot(0));
      verify(mockProcessManager.run(['idevice_id', '-l'])).called(1);
    });

    test(
      'should exit with non-zero if multiple devices are paired and no --udid is provided',
      () async {
        final processResult =
            ProcessResult(0, 0, 'udid1\nudid2', ''); // stdout shows two UDIDs
        when(mockProcessManager.run(any))
            .thenAnswer((_) async => processResult);

        final runner = CliRunner(processManager: mockProcessManager);
        final exitCode = await runner.run([]);

        expect(exitCode, isNot(0));
        verify(mockProcessManager.run(['idevice_id', '-l'])).called(1);
      },
    );

    test('should proceed if one device is paired', () async {
      final processResult =
          ProcessResult(0, 0, 'udid1', ''); // stdout shows one UDID
      when(mockProcessManager.run(any)).thenAnswer((_) async => processResult);

      // Create a controlled mock process for the idevicesyslog command
      final stdoutController = StreamController<List<int>>();
      final mockProcess = MockProcess(
        stdout: stdoutController.stream,
        stderr: Stream<List<int>>.empty(),
        exitCode: Completer<int>().future, // Will never complete in this test
      );

      // Mock the start call
      when(mockProcessManager.start(
        argThat(contains('idevicesyslog')),
        runInShell: anyNamed('runInShell'),
      )).thenAnswer((_) async => mockProcess);

      // Start the command
      final runner = CliRunner(processManager: mockProcessManager);

      // Add a test line to the stream and run
      stdoutController.add(utf8.encode('Test log line\n'));

      // Use a timeout to simulate running the command for a short period
      final exitCodeFuture = runner.run([]).timeout(
        Duration(milliseconds: 300),
        onTimeout: () => 0, // Return success on timeout
      );

      // Close the controller to clean up
      await stdoutController.close();

      // Verify the execution was successful (got 0 from timeout)
      final exitCode = await exitCodeFuture;
      expect(exitCode, 0);

      // Verify the commands were called correctly
      verify(mockProcessManager.run(['idevice_id', '-l'])).called(1);
      verify(mockProcessManager.start(argThat(contains('idevicesyslog')),
              runInShell: anyNamed('runInShell')))
          .called(1);
    });

    test(
      'should proceed if multiple devices are paired and --udid is provided for one of them',
      () async {
        final processResult =
            ProcessResult(0, 0, 'udid1\nudid2', ''); // Multiple devices
        when(mockProcessManager.run(any))
            .thenAnswer((_) async => processResult);

        // Create a controlled mock process
        final stdoutController = StreamController<List<int>>();
        final mockProcess = MockProcess(
          stdout: stdoutController.stream,
          stderr: Stream<List<int>>.empty(),
          exitCode: Completer<int>().future, // Never completes in this test
        );

        // Mock the start call
        when(mockProcessManager.start(
          argThat(contains('idevicesyslog')),
          runInShell: anyNamed('runInShell'),
        )).thenAnswer((_) async => mockProcess);

        // Start the command
        final runner = CliRunner(processManager: mockProcessManager);

        // Add a test line to the stream and run
        stdoutController.add(utf8.encode('Test log line\n'));

        // Use a timeout to simulate running the command for a short period
        final exitCodeFuture = runner.run(['--udid', 'udid1']).timeout(
          Duration(milliseconds: 300),
          onTimeout: () => 0, // Return success on timeout
        );

        // Close the controller to clean up
        await stdoutController.close();

        // Verify the execution was successful (got 0 from timeout)
        final exitCode = await exitCodeFuture;
        expect(exitCode, 0);

        // Verify the commands were called correctly
        verify(mockProcessManager.run(['idevice_id', '-l'])).called(1);
        verify(mockProcessManager.start(argThat(contains('idevicesyslog')),
                runInShell: anyNamed('runInShell')))
            .called(1);
      },
    );
  });

  group('Wi-Fi Functionality', () {
    test('--wifi flag causes idevicesyslog to be called with --network',
        () async {
      final String testUdid = 'test-wifi-udid-001';
      // Mock for idevice_id -l (to find the UDID)
      final udidCheckResult = ProcessResult(0, 0, testUdid, '');

      when(mockProcessManager.run(['idevice_id', '-l']))
          .thenAnswer((_) async => udidCheckResult);

      // Create a controlled mock process
      final stdoutController = StreamController<List<int>>();
      final mockProcess = MockProcess(
        stdout: stdoutController.stream,
        stderr: Stream<List<int>>.empty(),
        exitCode: Completer<int>().future, // Never completes in this test
      );

      // Capture the arguments passed to start
      List<String>? capturedArgs;
      when(mockProcessManager.start(captureAny,
              runInShell: anyNamed('runInShell')))
          .thenAnswer((Invocation inv) {
        capturedArgs = inv.positionalArguments.first as List<String>;
        return Future.value(mockProcess);
      });

      final runner = CliRunner(processManager: mockProcessManager);
      // Use a timeout to simulate running for a short period
      runner.run(['--wifi', '--udid', testUdid]).timeout(
        Duration(milliseconds: 300),
        onTimeout: () => 0, // Return success on timeout
      );

      // Give time for the command to be started
      await Future.delayed(Duration(milliseconds: 100));

      // Add a test line to the stream
      stdoutController.add(utf8.encode('Test log line\n'));

      // Close the controller to clean up
      await stdoutController.close();

      // Verify the commands
      verify(mockProcessManager.run(['idevice_id', '-l'])).called(1);

      // Check the arguments passed to start
      expect(capturedArgs, isNotNull);
      expect(capturedArgs, contains('idevicesyslog'));
      expect(capturedArgs, contains('--network'));
      expect(capturedArgs, contains('-u'));
      expect(capturedArgs, contains(testUdid));
    });
  });

  group('Log Saving (--save)', () {
    late Directory tempLogDir;
    final String testUdid = 'test-save-udid-002';

    setUp(() {
      tempLogDir =
          Directory.systemTemp.createTempSync('devicesyslog_test_logs_');

      // Mock for idevice_id -l
      final udidCheckResult = ProcessResult(0, 0, testUdid, '');
      when(mockProcessManager.run(['idevice_id', '-l']))
          .thenAnswer((_) async => udidCheckResult);
    });

    tearDown(() {
      if (tempLogDir.existsSync()) {
        tempLogDir.deleteSync(recursive: true);
      }
    });

    test(
      '--save flag creates a timestamped log file in the specified --output-dir',
      () async {
        // Create a controlled process with a completer for the exit code
        final exitCodeCompleter = Completer<int>();
        final stdoutController = StreamController<List<int>>();

        final mockProcess = MockProcess(
          stdout: stdoutController.stream,
          stderr: Stream<List<int>>.empty(),
          exitCode: exitCodeCompleter.future,
        );

        when(mockProcessManager.start(any, runInShell: anyNamed('runInShell')))
            .thenAnswer((_) async => mockProcess);

        final runner = CliRunner(processManager: mockProcessManager);
        final runArgs = [
          '--save',
          '--output-dir',
          tempLogDir.path,
          '--udid',
          testUdid
        ];

        // Start the runner
        final runFuture = runner.run(runArgs);

        // Add some test data
        stdoutController.add(utf8.encode('Test log line 1\n'));
        stdoutController.add(utf8.encode('Test log line 2\n'));

        // Wait for the log file to be created and written
        await Future.delayed(Duration(milliseconds: 500));

        // Close stdout and complete the process
        await stdoutController.close();
        exitCodeCompleter.complete(0);

        // Wait for the runner to complete
        final exitCode = await runFuture;
        expect(exitCode, 0);

        // Verify idevicesyslog was started
        verify(mockProcessManager.start(any,
                runInShell: anyNamed('runInShell')))
            .called(1);

        // Check if a log file was created in tempLogDir
        final files = tempLogDir.listSync().whereType<File>().toList();
        expect(files.isNotEmpty, isTrue,
            reason: 'No log file found in ${tempLogDir.path}');

        // Verify the file has the expected format (YYYY-MM-DD_HH-MM-SS.log)
        final fileName = path.basename(files.first.path);
        expect(
            RegExp(r'^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.log$')
                .hasMatch(fileName),
            isTrue,
            reason: 'File name does not match expected format: $fileName');

        // Check file contents
        final fileContent = await files.first.readAsString();
        expect(fileContent.contains('Test log line 1'), isTrue);
        expect(fileContent.contains('Test log line 2'), isTrue);
      },
    );

    test(
      '--save flag creates file in default ./logs/device/ if --output-dir is not given',
      () async {
        final defaultLogDirPath =
            path.join(Directory.current.path, 'logs', 'device');
        final defaultLogDir = Directory(defaultLogDirPath);

        // Ensure a clean state for default log dir for this test
        if (defaultLogDir.existsSync()) {
          defaultLogDir.deleteSync(recursive: true);
        }

        // Create a controlled process with a completer for the exit code
        final exitCodeCompleter = Completer<int>();
        final stdoutController = StreamController<List<int>>();

        final mockProcess = MockProcess(
          stdout: stdoutController.stream,
          stderr: Stream<List<int>>.empty(),
          exitCode: exitCodeCompleter.future,
        );

        when(mockProcessManager.start(any, runInShell: anyNamed('runInShell')))
            .thenAnswer((_) async => mockProcess);

        final runner = CliRunner(processManager: mockProcessManager);
        final runArgs = ['--save', '--udid', testUdid];

        // Start the runner
        final runFuture = runner.run(runArgs);

        // Add some test data
        stdoutController.add(utf8.encode('Test log line 1\n'));
        stdoutController.add(utf8.encode('Test log line 2\n'));

        // Wait for the log file to be created and written
        await Future.delayed(Duration(milliseconds: 500));

        // Close stdout and complete the process
        await stdoutController.close();
        exitCodeCompleter.complete(0);

        // Wait for the runner to complete
        final exitCode = await runFuture;
        expect(exitCode, 0);

        verify(mockProcessManager.start(any,
                runInShell: anyNamed('runInShell')))
            .called(1);

        expect(defaultLogDir.existsSync(), isTrue,
            reason:
                'Default log directory $defaultLogDirPath was not created.');

        final files = defaultLogDir.listSync().whereType<File>().toList();
        expect(files.isNotEmpty, isTrue,
            reason: 'No log file found in default dir $defaultLogDirPath');

        // Check file contents
        final fileContent = await files.first.readAsString();
        expect(fileContent.contains('Test log line 1'), isTrue);
        expect(fileContent.contains('Test log line 2'), isTrue);

        // Cleanup default log dir after test
        if (defaultLogDir.existsSync()) {
          defaultLogDir.deleteSync(recursive: true);
        }
      },
    );
  });

  group('Log Stream Processing', () {
    final String targetBundleId = 'com.example.TargetApp';
    final String otherBundleId = 'com.example.OtherApp';
    final String testUdid = 'test-stream-udid-003';
    late Directory tempLogDirForStreamTests;

    setUp(() {
      tempLogDirForStreamTests =
          Directory.systemTemp.createTempSync('devicesyslog_stream_tests_');
      final udidCheckResult = ProcessResult(0, 0, testUdid, '');
      when(mockProcessManager.run(['idevice_id', '-l']))
          .thenAnswer((_) async => udidCheckResult);
    });

    tearDown(() {
      if (tempLogDirForStreamTests.existsSync()) {
        tempLogDirForStreamTests.deleteSync(recursive: true);
      }
    });

    test('filters log lines based on bundle ID if provided (checks saved file)',
        () async {
      // Create test log data
      final logData = [
        'May 26 10:00:00 Host device[123] <Notice>: [$targetBundleId] Message 1 for target\n',
        'May 26 10:00:01 Host device[124] <Error>: [$otherBundleId] Message from other app\n',
        'May 26 10:00:02 Host device[125] <Warning>: [$targetBundleId] Message 2 for target\n',
        'May 26 10:00:03 Host device[126] <Notice>: Some system message without bundle ID\n',
      ];

      // Create a controlled process with a completer for the exit code
      final exitCodeCompleter = Completer<int>();
      final stdoutController = StreamController<List<int>>();

      final mockProcess = MockProcess(
        stdout: stdoutController.stream,
        stderr: Stream<List<int>>.empty(),
        exitCode: exitCodeCompleter.future,
      );

      when(mockProcessManager.start(any, runInShell: anyNamed('runInShell')))
          .thenAnswer((_) async => mockProcess);

      final runner = CliRunner(processManager: mockProcessManager);
      final runArgs = [
        '--bundle-id',
        targetBundleId,
        '--udid',
        testUdid,
        '--save',
        '--output-dir',
        tempLogDirForStreamTests.path
      ];

      // Start the CLI runner
      final runnerFuture = runner.run(runArgs);

      // Add the test log data
      for (final line in logData) {
        stdoutController.add(utf8.encode(line));
        await Future.delayed(
            Duration(milliseconds: 50)); // Small delay between lines
      }

      // Wait for processing and file writing
      await Future.delayed(Duration(milliseconds: 300));

      // Close stdout and complete the process
      await stdoutController.close();
      exitCodeCompleter.complete(0);

      // Wait for the runner to complete
      await runnerFuture;

      // Check the log file content
      final logFiles =
          tempLogDirForStreamTests.listSync().whereType<File>().toList();
      expect(logFiles.length, 1,
          reason: 'Expected one log file to be created.');

      final logFile = logFiles.first;
      final logFileContent = await logFile.readAsString();

      // Verify the filtered content
      expect(logFileContent.contains('[$targetBundleId] Message 1 for target'),
          isTrue);
      expect(logFileContent.contains('[$targetBundleId] Message 2 for target'),
          isTrue);
      expect(logFileContent.contains('[$otherBundleId] Message from other app'),
          isFalse);
      expect(logFileContent.contains('Some system message without bundle ID'),
          isFalse);
    });
  });
}
