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
          'May 26 10:00:00 Host device[123] <Notice>: $targetBundleId[123] Message 1 for target\n',
          'May 26 10:00:01 Host device[124] <Error>: $otherBundleId[124] Message from other app\n',
          'May 26 10:00:02 Host device[125] <Warning>: $targetBundleId[125] Message 2 for target\n',
          'May 26 10:00:03 Host device[126] <Notice>: $targetBundleId(UIKitCore)[126] Message 3 for target\n',
          'May 26 10:00:04 Host device[127] <Notice>: Some system message without bundle ID\n',
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

        // Create the same regex that the CLI uses
        final bundleIdRegex = RegExp(
          r'(^|\s)' + RegExp.escape(targetBundleId) + r'(\[|\()',
        );

        // Message 1 should be matched by the bundle ID regex
        expect(
          bundleIdRegex.hasMatch('$targetBundleId[123] Message 1 for target'),
          isTrue,
          reason: 'Target bundle ID with PID should match regex',
        );

        // Check that logs with the target bundle ID are included
        final matchCount = bundleIdRegex.allMatches(logFileContent).length;
        expect(
          matchCount,
          equals(3),
          reason: 'Should capture exactly three messages for target bundle ID',
        );

        // Check that logs with other bundle IDs are excluded
        expect(
          logFileContent.contains('$otherBundleId[124] Message from other app'),
          isFalse,
          reason: 'Log file should not contain message from other app',
        );
        expect(
          logFileContent.contains('Some system message without bundle ID'),
          isFalse,
          reason:
              'Log file should not contain system message without bundle ID',
        );
      },
    );
  });
}
