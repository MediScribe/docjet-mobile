import 'package:args/args.dart';
import 'dart:io';

void main(List<String> arguments) {
  final parser =
      ArgParser()
        ..addOption(
          'output-dir',
          abbr: 'o',
          help: 'Directory to save log files.',
        )
        ..addFlag(
          'wifi',
          abbr: 'w',
          help: 'Connect to device via Wi-Fi (requires iproxy).',
        )
        ..addOption('udid', help: 'Target a specific device by its UDID.')
        ..addFlag(
          'save',
          abbr: 's',
          help: 'Save syslog output to a timestamped file.',
          defaultsTo: false,
        )
        ..addFlag(
          'utc',
          help: 'Use UTC for timestamps in filenames and logs.',
          defaultsTo: false,
        )
        ..addFlag(
          'json',
          help: 'Output logs in JSON format.',
          defaultsTo: false,
        )
        ..addFlag(
          'help',
          abbr: 'h',
          negatable: false,
          help: 'Show this help message.',
        );

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error parsing arguments: ${e.message}');
    stderr.writeln(parser.usage);
    exit(64); // EX_USAGE in BSD
  }

  if (argResults['help'] as bool) {
    print('Usage: devicesyslog [options]');
    print(parser.usage);
    return;
  }

  // Placeholder for actual logic
  print('Parsed arguments:');
  print('  Output Directory: ${argResults['output-dir']}');
  print('  Wi-Fi: ${argResults['wifi']}');
  print('  UDID: ${argResults['udid']}');
  print('  Save: ${argResults['save']}');
  print('  UTC: ${argResults['utc']}');
  print('  JSON: ${argResults['json']}');

  // Future implementation will go here
}
