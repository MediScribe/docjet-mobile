import 'dart:async';
import 'dart:io';

import 'package:mockito/mockito.dart';

// Export the generated mocks so tests can access MockProcessManager
export 'devicesyslog_cli_test.mocks.dart';

/// A custom [Process] implementation that allows precise control of the
/// stdout/stderr streams and the exitCode future in tests.
class MockProcess extends Mock implements Process {
  final Stream<List<int>> _stdout;
  final Stream<List<int>> _stderr;
  final Future<int> _exitCode;

  MockProcess({
    Stream<List<int>>? stdout,
    Stream<List<int>>? stderr,
    Future<int>? exitCode,
  }) : _stdout = stdout ?? const Stream<List<int>>.empty(),
       _stderr = stderr ?? const Stream<List<int>>.empty(),
       _exitCode = exitCode ?? Future<int>.value(0);

  @override
  Stream<List<int>> get stdout => _stdout;

  @override
  Stream<List<int>> get stderr => _stderr;

  @override
  Future<int> get exitCode => _exitCode;

  @override
  int get pid => 1337; // Arbitrary dummy PID

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);
}
