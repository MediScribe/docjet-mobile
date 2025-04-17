import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

// Path to server executable (relative to mock_api_server directory)
const String _mockServerPath = 'bin/server.dart';

// Helper to print logs with a consistent prefix
void _logHelper(String testSuite, String message) {
  print('[$testSuite Test Helper] $message');
}

/// Clears the specified port and starts the mock server.
///
/// Returns a record containing the started [Process] object and the assigned port number.
/// Requires the test suite name for logging.
Future<(Process?, int)> startMockServer(String testSuiteName) async {
  _logHelper(testSuiteName, 'Starting mock server management...');

  // Find an available port
  int assignedPort = 0;
  try {
    final serverSocket =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    assignedPort = serverSocket.port;
    await serverSocket.close(); // Close the socket immediately
    _logHelper(testSuiteName, 'Found available port: $assignedPort');
  } catch (e, stackTrace) {
    _logHelper(
      testSuiteName,
      'Error finding available port: $e $stackTrace',
    );
    rethrow; // Fail setup if we can't get a port
  }

  // Start the server
  _logHelper(testSuiteName, 'Starting mock server on port $assignedPort...');
  Process? process;
  try {
    // Determine working directory relative to the test file execution
    // Assumes tests are run from the package root (e.g., `dart test`)
    // or from the `mock_api_server` directory.
    // The server path is relative to the `mock_api_server` dir.
    String workingDir = Directory.current.path;
    if (!workingDir.endsWith('mock_api_server')) {
      workingDir = p.join(workingDir, 'mock_api_server');
      _logHelper(testSuiteName, 'Adjusted working dir to: $workingDir');
    }

    process = await Process.start(
      'dart',
      [_mockServerPath, '--port', assignedPort.toString()],
      workingDirectory: workingDir,
    );
    _logHelper(testSuiteName, 'Mock server started (PID: ${process.pid})');

    // Optional: Pipe server output
    process.stdout
        .transform(utf8.decoder)
        .listen((line) => _logHelper(testSuiteName, 'SERVER STDOUT: $line'));
    process.stderr
        .transform(utf8.decoder)
        .listen((line) => _logHelper(testSuiteName, 'SERVER STDERR: $line'));

    _logHelper(testSuiteName, 'Waiting 5 seconds for server...');
    await Future.delayed(const Duration(seconds: 5));
    _logHelper(testSuiteName, 'Server should be ready.');
    return (process, assignedPort);
  } catch (e, stackTrace) {
    _logHelper(testSuiteName, 'Error starting mock server: $e $stackTrace');
    process?.kill();
    rethrow; // Propagate error to fail setup
  }
}

/// Stops the mock server process gracefully.
///
/// Requires the [Process] object and test suite name for logging.
Future<void> stopMockServer(String testSuiteName, Process? process) async {
  if (process == null) {
    _logHelper(testSuiteName, 'No server process to stop.');
    return;
  }
  _logHelper(testSuiteName, 'Stopping mock server (PID: ${process.pid})...');
  process.kill(ProcessSignal.sigterm);
  await Future.delayed(const Duration(seconds: 2)); // Grace period
  process.kill(ProcessSignal.sigkill); // Force kill
  _logHelper(testSuiteName, 'Mock server stop signal sent.');
}
