import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devicesyslog_cli/src/cli_runner.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  late MockProcessManager mockProcessManager;
  const targetBundleId = 'com.example.TargetApp';
  const otherBundleId = 'com.example.OtherApp';
  const testUdid = 'test-stream-udid-003';

  setUp(() {
    mockProcessManager = MockProcessManager();
    when(
      mockProcessManager.run(['idevice_id', '-l']),
    ).thenAnswer((_) async => ProcessResult(0, 0, testUdid, ''));
  });

  group('Log Stream Processing', () {
    test(
      'filters log lines based on bundle ID if provided (checks saved file)',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'devicesyslog_stream_tests_',
        );

        addTearDown(() {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        });

        final logData = <String>[
          'May 26 10:00:00 Host device[123] <Notice>: [$targetBundleId] Message 1 for target\n',
          'May 26 10:00:01 Host device[124] <Error>: [$otherBundleId] Message from other app\n',
          'May 26 10:00:02 Host device[125] <Warning>: [$targetBundleId] Message 2 for target\n',
          'May 26 10:00:03 Host device[126] <Notice>: Some system message without bundle ID\n',
        ];

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
        final runnerFuture = runner.run([
          '--bundle-id',
          targetBundleId,
          '--udid',
          testUdid,
          '--save',
          '--output-dir',
          tempDir.path,
        ]);

        for (final line in logData) {
          stdoutController.add(utf8.encode(line));
          await Future.delayed(const Duration(milliseconds: 50));
        }

        await Future.delayed(const Duration(milliseconds: 300));

        await stdoutController.close();
        exitCodeCompleter.complete(0);

        await runnerFuture;

        final logFiles = tempDir.listSync().whereType<File>().toList();
        expect(logFiles, hasLength(1));

        final logFileContent = await logFiles.first.readAsString();

        expect(
          logFileContent.contains('[$targetBundleId] Message 1 for target'),
          isTrue,
        );
        expect(
          logFileContent.contains('[$targetBundleId] Message 2 for target'),
          isTrue,
        );
        expect(
          logFileContent.contains('[$otherBundleId] Message from other app'),
          isFalse,
        );
        expect(
          logFileContent.contains('Some system message without bundle ID'),
          isFalse,
        );
      },
    );
  });
}
