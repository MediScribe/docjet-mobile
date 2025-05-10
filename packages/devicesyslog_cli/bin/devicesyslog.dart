import 'package:devicesyslog_cli/src/cli_runner.dart';
import 'dart:io'; // For exitCode

Future<void> main(List<String> arguments) async {
  final CliRunner runner = CliRunner();
  exitCode = await runner.run(arguments);
}
