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
      ..addFlag(
        'utc',
        negatable: false,
        help: 'Display and save timestamps in UTC instead of local time.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Output logs in JSON format (Not yet implemented).',
      )
      ..addOption(
        'bundle-id',
        help: 'Filter logs for a specific application bundle ID.',
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
            'No iOS devices found. Ensure a device is connected via USB or paired for Wi-Fi debugging.');
        return null;
      }

      if (udids.length == 1) {
        final detectedUdid = udids.first;
        if (preferredUdid != null && preferredUdid != detectedUdid) {
          stderr.writeln(
              'Specified UDID \'$preferredUdid\' does not match the only connected device \'$detectedUdid\'.');
          return null;
        }
        stdout.writeln('Found device: $detectedUdid');
        return detectedUdid;
      }

      // Multiple devices connected
      if (preferredUdid == null) {
        stderr.writeln(
            'Multiple iOS devices found. Please specify one using the --udid flag:');
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
            'Specified UDID \'$preferredUdid\' not found among connected devices:');
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

    final String? targetUdid =
        await _determineTargetUdid(argResults['udid'] as String?);
    if (targetUdid == null) {
      return _errorExitCode;
    }
    stdout.writeln('Using device UDID: $targetUdid');

    final List<String> syslogCmd = ['idevicesyslog', '-u', targetUdid];
    if (argResults['wifi'] as bool) {
      syslogCmd.add('--network');
    }
    // TODO: Add other idevicesyslog options based on argResults (filtering, etc.)

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
        final timestamp =
            DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
        final logFilePath = p.join(dir.path, '$timestamp.log');
        stdout.writeln('Saving logs to: $logFilePath'); // Inform user
        // Create the file AND open the sink for writing.
        logFileSink = File(logFilePath).openWrite(mode: FileMode.append);
      }

      // stdout.writeln('Starting: ${syslogCmd.join(' ')}'); // Less verbose
      syslogProcess = await _processManager.start(syslogCmd, runInShell: true);

      final completer = Completer<int>();
      final String? bundleIdFilter = argResults['bundle-id'] as String?;
      // Pre-format the filter string for efficiency if it's used
      final String? bundleIdSearchString =
          bundleIdFilter != null && bundleIdFilter.isNotEmpty
              ? '[$bundleIdFilter]'
              : null;

      stdoutSub = syslogProcess.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        // If bundle ID filter is set, only process matching lines
        if (bundleIdSearchString == null ||
            line.contains(bundleIdSearchString)) {
          stdout.writeln(line);
          logFileSink?.writeln(line);
        }
      }, onDone: () {
        if (!completer.isCompleted) {
          // The process ended naturally, we'll get the exit code from exitCode.then
        }
      }, onError: (error) {
        stderr.writeln('Error on syslog stdout stream: $error');
        if (!completer.isCompleted) completer.complete(_errorExitCode);
      });

      stderrSub = syslogProcess.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        stderr.writeln(line);
        logFileSink?.writeln('ERROR: $line');
      }, onDone: () {
        // stderr stream completed
      }, onError: (error) {
        stderr.writeln('Error on syslog stderr stream: $error');
      });

      syslogProcess.exitCode.then((code) {
        // stdout.writeln('idevicesyslog process exited with code $code.');
        if (!completer.isCompleted) completer.complete(code);
      }).catchError((error) {
        stderr.writeln('Error waiting for syslog process exit code: $error');
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
}
