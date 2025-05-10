import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devicesyslog_cli/src/cli_runner.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  late MockProcessManager mockProcessManager;

  setUp(() {
    mockProcessManager = MockProcessManager();
  });

  group('Device Detection and Handling', () {
    test('should exit with non-zero if no device is paired', () async {
      final processResult = ProcessResult(0, 0, '', '');
      when(
        mockProcessManager.run(['idevice_id', '-l']),
      ).thenAnswer((_) async => processResult);

      final runner = CliRunner(processManager: mockProcessManager);
      final exitCode = await runner.run([]);

      expect(exitCode, isNot(0));
      verify(mockProcessManager.run(['idevice_id', '-l'])).called(1);
    });

    test(
      'should exit with non-zero if multiple devices are paired and no --udid is provided',
      () async {
        final processResult = ProcessResult(0, 0, 'udid1\nudid2', '');
        when(
          mockProcessManager.run(['idevice_id', '-l']),
        ).thenAnswer((_) async => processResult);

        final runner = CliRunner(processManager: mockProcessManager);
        final exitCode = await runner.run([]);

        expect(exitCode, isNot(0));
        verify(mockProcessManager.run(['idevice_id', '-l'])).called(1);
      },
    );

    test('should proceed if one device is paired', () async {
      final processResult = ProcessResult(0, 0, 'udid1', '');
      when(
        mockProcessManager.run(['idevice_id', '-l']),
      ).thenAnswer((_) async => processResult);

      final stdoutController = StreamController<List<int>>();
      final mockProcess = MockProcess(
        stdout: stdoutController.stream,
        stderr: const Stream.empty(),
        exitCode: Completer<int>().future,
      );

      when(
        mockProcessManager.start(
          argThat(contains('idevicesyslog')),
          runInShell: anyNamed('runInShell'),
        ),
      ).thenAnswer((_) async => mockProcess);

      final runner = CliRunner(processManager: mockProcessManager);

      stdoutController.add(utf8.encode('Test log line\n'));

      final exitCodeFuture = runner
          .run([])
          .timeout(const Duration(milliseconds: 300), onTimeout: () => 0);

      await stdoutController.close();

      final exitCode = await exitCodeFuture;
      expect(exitCode, 0);

      verify(mockProcessManager.run(['idevice_id', '-l'])).called(1);
      verify(
        mockProcessManager.start(
          argThat(contains('idevicesyslog')),
          runInShell: anyNamed('runInShell'),
        ),
      ).called(1);
    });

    test(
      'should proceed if multiple devices are paired and --udid is provided for one of them',
      () async {
        final processResult = ProcessResult(0, 0, 'udid1\nudid2', '');
        when(
          mockProcessManager.run(['idevice_id', '-l']),
        ).thenAnswer((_) async => processResult);

        final stdoutController = StreamController<List<int>>();
        final mockProcess = MockProcess(
          stdout: stdoutController.stream,
          stderr: const Stream.empty(),
          exitCode: Completer<int>().future,
        );

        when(
          mockProcessManager.start(
            argThat(contains('idevicesyslog')),
            runInShell: anyNamed('runInShell'),
          ),
        ).thenAnswer((_) async => mockProcess);

        final runner = CliRunner(processManager: mockProcessManager);

        stdoutController.add(utf8.encode('Test log line\n'));

        final exitCodeFuture = runner
            .run(['--udid', 'udid1'])
            .timeout(const Duration(milliseconds: 300), onTimeout: () => 0);

        await stdoutController.close();
        final exitCode = await exitCodeFuture;
        expect(exitCode, 0);

        verify(mockProcessManager.run(['idevice_id', '-l'])).called(1);
        verify(
          mockProcessManager.start(
            argThat(contains('idevicesyslog')),
            runInShell: anyNamed('runInShell'),
          ),
        ).called(1);
      },
    );
  });
}
