import 'dart:async';
import 'dart:io';

import 'package:devicesyslog_cli/src/cli_runner.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  late MockProcessManager mockProcessManager;
  const String testUdid = 'test-flag-udid-010';

  setUp(() {
    mockProcessManager = MockProcessManager();

    // Stub device detection.
    when(
      mockProcessManager.run(['idevice_id', '-l']),
    ).thenAnswer((_) async => ProcessResult(0, 0, testUdid, ''));
  });

  group('Flag Acceptance (--utc, --json)', () {
    Future<void> runWithArgs(List<String> extraArgs) async {
      final exitCompleter = Completer<int>();
      final mockProcess = MockProcess(
        stdout: const Stream.empty(),
        stderr: const Stream.empty(),
        exitCode: exitCompleter.future,
      );

      when(
        mockProcessManager.start(any, runInShell: anyNamed('runInShell')),
      ).thenAnswer((_) async => mockProcess);

      final runner = CliRunner(processManager: mockProcessManager);
      final runFuture = runner.run([...extraArgs, '--udid', testUdid]);

      // Simulate process exiting cleanly.
      exitCompleter.complete(0);
      final exitCode = await runFuture;
      expect(exitCode, 0);

      // Ensure idevicesyslog was invoked.
      verify(
        mockProcessManager.start(any, runInShell: anyNamed('runInShell')),
      ).called(1);
    }

    test('--utc flag should be accepted and CLI exits with success', () async {
      await runWithArgs(['--utc']);
    });

    test('--json flag should be accepted and CLI exits with success', () async {
      await runWithArgs(['--json']);
    });
  });
}
