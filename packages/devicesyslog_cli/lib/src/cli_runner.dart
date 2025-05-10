import 'package:args/args.dart';
import 'package:process/process.dart';
import 'dart:io'; // For stdout, stderr, exit
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'dart:async'; // For StreamSubscription
import 'dart:convert'; // For utf8.decode

class CliRunner {
  final ArgParser _argParser;
  final ProcessManager _processManager;
  static const int successExitCode =
      0; // Made public for tests if needed, or keep private
  static const int _errorExitCode = 1;
  static const int _usageExitCode =
      2; // Or some other non-zero for usage errors

  CliRunner({ProcessManager? processManager})
    : _processManager = processManager ?? const LocalProcessManager(),
      _argParser = _buildParser();

  static ArgParser _buildParser() {
    return ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Displays this help information.',
      )
      ..addFlag(
        'wifi',
        negatable: false,
        help:
            'Connect to device via Wi-Fi (requires device to be set up for Wi-Fi sync).',
      )
      ..addOption(
        'udid',
        help:
            'Specify the UDID of the target device if multiple are connected.',
      )
      ..addFlag(
        'save',
        negatable: false,
        help: 'Save syslog output to a timestamped file in ./logs/device/.',
      )
      ..addOption(
        'output-dir',
        help: 'Specify output directory for saved logs (used with --save).',
        defaultsTo: p.join('logs', 'device'),
      )
      ..addOption(
        'bundle-id',
        help: 'Filter logs for a specific application bundle ID.',
      )
      ..addOption(
        'process',
        help:
            'Filter logs for a specific process name (idevicesyslog --process).',
      )
      ..addFlag(
        'flutter-only',
        negatable: false,
        help: 'Show only Flutter print/Logger lines (adds --match flutter:).',
      )
      ..addFlag(
        'utc',
        negatable: false,
        help:
            '[DEPRECATED] Display timestamps in UTC instead of local time (no-op).',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: '[DEPRECATED] Output logs in JSON format (not yet implemented).',
      );
    // Add more options/flags as per 0.3 findings if any are missing
  }

  Future<String?> _determineTargetUdid(String? preferredUdid) async {
    try {
      final result = await _processManager.run(['idevice_id', '-l']);
      if (result.exitCode != 0) {
        stderr.writeln('Error running idevice_id: ${result.stderr}');
        return null; // Indicate error
      }

      final String output = result.stdout as String;
      final List<String> udids =
          output.trim().split('\n').where((line) => line.isNotEmpty).toList();

      if (udids.isEmpty) {
        stderr.writeln(
          'No iOS devices found. Ensure a device is connected via USB or paired for Wi-Fi debugging.',
        );
        return null;
      }

      if (udids.length == 1) {
        final detectedUdid = udids.first;
        if (preferredUdid != null && preferredUdid != detectedUdid) {
          stderr.writeln(
            'Specified UDID \'$preferredUdid\' does not match the only connected device \'$detectedUdid\'.',
          );
          return null;
        }
        stdout.writeln('Found device: $detectedUdid');
        return detectedUdid;
      }

      // Multiple devices connected
      if (preferredUdid == null) {
        stderr.writeln(
          'Multiple iOS devices found. Please specify one using the --udid flag:',
        );
        for (final udid in udids) {
          stderr.writeln('  - $udid');
        }
        return null;
      }

      if (udids.contains(preferredUdid)) {
        stdout.writeln('Targeting specified device: $preferredUdid');
        return preferredUdid;
      } else {
        stderr.writeln(
          'Specified UDID \'$preferredUdid\' not found among connected devices:',
        );
        for (final udid in udids) {
          stderr.writeln('  - $udid');
        }
        return null;
      }
    } catch (e) {
      stderr.writeln('Failed to determine target UDID: $e');
      return null;
    }
  }

  Future<int> run(List<String> args) async {
    ArgResults argResults;
    try {
      argResults = _argParser.parse(args);
    } on FormatException catch (e) {
      stderr.writeln('Error parsing arguments: ${e.message}');
      stderr.writeln(_argParser.usage);
      return _usageExitCode;
    }

    if (argResults['help'] as bool) {
      stdout.writeln('Usage: devicesyslog [options]\n');
      stdout.writeln(_argParser.usage);
      return successExitCode; // Using the public static const
    }

    final String? targetUdid = await _determineTargetUdid(
      argResults['udid'] as String?,
    );
    if (targetUdid == null) {
      return _errorExitCode;
    }
    stdout.writeln('Using device UDID: $targetUdid');

    final List<String> syslogCmd = ['idevicesyslog', '-u', targetUdid];
    if (argResults['wifi'] as bool) {
      syslogCmd.add('--network');
    }

    // Pass through utc/json flags to idevicesyslog if requested
    if (argResults['utc'] as bool) {
      syslogCmd.add('--utc');
    }
    if (argResults['json'] as bool) {
      syslogCmd.add('--json');
    }

    final bool flutterOnly = argResults['flutter-only'] as bool;
    if (flutterOnly) {
      syslogCmd.addAll(['--match', 'flutter:']);
    }

    final String? processFilter = argResults['process'] as String?;
    if (processFilter != null && processFilter.isNotEmpty) {
      syslogCmd.addAll(['--process', processFilter]);
    }

    Process? syslogProcess;
    IOSink? logFileSink;
    StreamSubscription? stdoutSub, stderrSub; // sigintSub, sigtermSub for later

    try {
      if (argResults['save'] as bool) {
        String outputDirArg = argResults['output-dir'] as String;
        String resolvedOutputDir;
        if (p.isAbsolute(outputDirArg)) {
          resolvedOutputDir = outputDirArg;
        } else {
          resolvedOutputDir = p.join(Directory.current.path, outputDirArg);
        }
        final dir = Directory(resolvedOutputDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
          // stdout.writeln('Created log directory: ${dir.path}'); // Less verbose
        }
        final DateTime now =
            argResults['utc'] as bool ? DateTime.now().toUtc() : DateTime.now();
        final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
        final logFilePath = p.join(dir.path, '$timestamp.log');
        stdout.writeln('Saving logs to: $logFilePath'); // Inform user
        // Create the file AND open the sink for writing.
        logFileSink = File(logFilePath).openWrite(mode: FileMode.append);
      }

      // stdout.writeln('Starting: ${syslogCmd.join(' ')}'); // Less verbose
      syslogProcess = await _processManager.start(syslogCmd, runInShell: true);

      final completer = Completer<int>();

      // Skip bundle ID filtering if we're already filtering by process
      RegExp? bundleIdRegex;
      if (processFilter == null && !flutterOnly) {
        final String? bundleIdFilter = argResults['bundle-id'] as String?;
        bundleIdRegex = _createBundleIdRegex(bundleIdFilter);
      }

      stdoutSub = syslogProcess.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (bundleIdRegex == null) {
                stdout.writeln(line);
                logFileSink?.writeln(line);
              } else if (bundleIdRegex.hasMatch(line)) {
                stdout.writeln(line);
                logFileSink?.writeln(line);
              }
            },
            onDone: () {
              if (!completer.isCompleted) {
                // The process ended naturally, we'll get the exit code from exitCode.then
              }
            },
            onError: (error) {
              stderr.writeln('Error on syslog stdout stream: $error');
              if (!completer.isCompleted) completer.complete(_errorExitCode);
            },
          );

      stderrSub = syslogProcess.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              stderr.writeln(line);
              logFileSink?.writeln('ERROR: $line');
            },
            onDone: () {
              // stderr stream completed
            },
            onError: (error) {
              stderr.writeln('Error on syslog stderr stream: $error');
            },
          );

      syslogProcess.exitCode
          .then((code) {
            // stdout.writeln('idevicesyslog process exited with code $code.');
            if (!completer.isCompleted) completer.complete(code);
          })
          .catchError((error) {
            stderr.writeln(
              'Error waiting for syslog process exit code: $error',
            );
            if (!completer.isCompleted) completer.complete(_errorExitCode);
          });

      // TODO: Implement SIGINT/SIGTERM handling here to kill syslogProcess and complete completer

      return await completer.future;
    } catch (e, s) {
      stderr.writeln('Error during syslog execution: $e');
      stderr.writeln(s.toString());
      syslogProcess?.kill();
      return _errorExitCode;
    } finally {
      await stdoutSub?.cancel();
      await stderrSub?.cancel();
      // await sigintSub?.cancel(); // For later
      // await sigtermSub?.cancel(); // For later

      try {
        await logFileSink?.flush();
        await logFileSink?.close();
      } catch (e) {
        stderr.writeln('Error closing log file sink: $e');
      }
      // stdout.writeln('Syslog process finished and resources cleaned up.'); // For debugging
    }
  }

  /// Creates a RegExp for matching lines containing the bundle ID in the process field
  RegExp? _createBundleIdRegex(String? bundleIdFilter) {
    if (bundleIdFilter == null || bundleIdFilter.isEmpty) {
      return null;
    }

    // Match the bundle ID as a standalone token *immediately* followed by
    // either a '[' (common) or '(' (rare) which denotes the PID / dylib
    // parent after the process name.
    // Examples that should match:
    //   … ai.docjet.mobile[123] <Notice>:
    //   … ai.docjet.mobile(UIKitCore)[123] <Notice>:
    // System lines that merely *mention* the bundle ID (fgApp: …) will NOT
    // match because the bundle-id is preceded by ':' or another char.
    return RegExp(r'(^|\s)' + RegExp.escape(bundleIdFilter) + r'(\[|\()');
  }
}
