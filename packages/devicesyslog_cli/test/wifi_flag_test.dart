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

  group('Wi-Fi Functionality', () {
    test(
      '--wifi flag causes idevicesyslog to be called with --network',
      () async {
        const testUdid = 'test-wifi-udid-001';

        when(
          mockProcessManager.run(['idevice_id', '-l']),
        ).thenAnswer((_) async => ProcessResult(0, 0, testUdid, ''));

        final stdoutController = StreamController<List<int>>();
        final mockProcess = MockProcess(
          stdout: stdoutController.stream,
          stderr: const Stream.empty(),
          exitCode: Completer<int>().future,
        );

        List<String>? capturedArgs;
        when(
          mockProcessManager.start(
            captureAny,
            runInShell: anyNamed('runInShell'),
          ),
        ).thenAnswer((invocation) {
          capturedArgs = invocation.positionalArguments.first as List<String>;
          return Future.value(mockProcess);
        });

        final runner = CliRunner(processManager: mockProcessManager);
        runner
            .run(['--wifi', '--udid', testUdid])
            .timeout(const Duration(milliseconds: 300), onTimeout: () => 0);

        await Future.delayed(const Duration(milliseconds: 100));
        stdoutController.add(utf8.encode('Test log line\n'));
        await stdoutController.close();

        verify(mockProcessManager.run(['idevice_id', '-l'])).called(1);

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!, contains('idevicesyslog'));
        expect(capturedArgs, contains('--network'));
        expect(capturedArgs, contains('-u'));
        expect(capturedArgs, contains(testUdid));
      },
    );
  });
}
