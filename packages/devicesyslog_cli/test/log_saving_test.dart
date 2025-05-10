import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devicesyslog_cli/src/cli_runner.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  late MockProcessManager mockProcessManager;
  const String testUdid = 'test-save-udid-002';

  setUp(() {
    mockProcessManager = MockProcessManager();
    when(
      mockProcessManager.run(['idevice_id', '-l']),
    ).thenAnswer((_) async => ProcessResult(0, 0, testUdid, ''));
  });

  group('Log Saving (--save)', () {
    test(
      '--save flag creates a timestamped log file in the specified --output-dir',
      () async {
        final tempLogDir = Directory.systemTemp.createTempSync(
          'devicesyslog_test_logs_',
        );

        addTearDown(() {
          if (tempLogDir.existsSync()) {
            tempLogDir.deleteSync(recursive: true);
          }
        });

        final exitCodeCompleter = Completer<int>();
        final stdoutController = StreamController<List<int>>();

        final mockProcess = MockProcess(
          stdout: stdoutController.stream,
          stderr: const Stream.empty(),
          exitCode: exitCodeCompleter.future,
        );

        when(
          mockProcessManager.start(any, runInShell: anyNamed('runInShell')),
        ).thenAnswer((_) async => mockProcess);

        final runner = CliRunner(processManager: mockProcessManager);
        final runFuture = runner.run([
          '--save',
          '--output-dir',
          tempLogDir.path,
          '--udid',
          testUdid,
        ]);

        stdoutController.add(utf8.encode('Test log line 1\n'));
        stdoutController.add(utf8.encode('Test log line 2\n'));

        await Future.delayed(const Duration(milliseconds: 500));

        await stdoutController.close();
        exitCodeCompleter.complete(0);

        final exitCode = await runFuture;
        expect(exitCode, 0);

        verify(
          mockProcessManager.start(any, runInShell: anyNamed('runInShell')),
        ).called(1);

        final files = tempLogDir.listSync().whereType<File>().toList();
        expect(files, isNotEmpty);

        final fileName = path.basename(files.first.path);
        expect(
          RegExp(
            r'^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.log$',
          ).hasMatch(fileName),
          isTrue,
          reason: 'File name does not match expected timestamp format',
        );

        final fileContent = await files.first.readAsString();
        expect(fileContent.contains('Test log line 1'), isTrue);
        expect(fileContent.contains('Test log line 2'), isTrue);
      },
    );

    test(
      '--save flag creates file in default ./logs/device/ if --output-dir is not given',
      () async {
        final defaultLogDirPath = path.join(
          Directory.current.path,
          'logs',
          'device',
        );
        final defaultLogDir = Directory(defaultLogDirPath);

        if (defaultLogDir.existsSync()) {
          defaultLogDir.deleteSync(recursive: true);
        }

        addTearDown(() {
          if (defaultLogDir.existsSync()) {
            defaultLogDir.deleteSync(recursive: true);
          }
        });

        final exitCodeCompleter = Completer<int>();
        final stdoutController = StreamController<List<int>>();

        final mockProcess = MockProcess(
          stdout: stdoutController.stream,
          stderr: const Stream.empty(),
          exitCode: exitCodeCompleter.future,
        );

        when(
          mockProcessManager.start(any, runInShell: anyNamed('runInShell')),
        ).thenAnswer((_) async => mockProcess);

        final runner = CliRunner(processManager: mockProcessManager);
        final runFuture = runner.run(['--save', '--udid', testUdid]);

        stdoutController.add(utf8.encode('Test log line 1\n'));
        stdoutController.add(utf8.encode('Test log line 2\n'));

        await Future.delayed(const Duration(milliseconds: 500));

        await stdoutController.close();
        exitCodeCompleter.complete(0);

        final exitCode = await runFuture;
        expect(exitCode, 0);

        verify(
          mockProcessManager.start(any, runInShell: anyNamed('runInShell')),
        ).called(1);

        expect(defaultLogDir.existsSync(), isTrue);

        final files = defaultLogDir.listSync().whereType<File>().toList();
        expect(files, isNotEmpty);

        final fileContent = await files.first.readAsString();
        expect(fileContent.contains('Test log line 1'), isTrue);
        expect(fileContent.contains('Test log line 2'), isTrue);
      },
    );
  });
}
