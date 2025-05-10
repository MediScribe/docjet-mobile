// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

import 'dart:async'; // Make sure Timer is imported
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

// Import the new middleware module
import 'package:mock_api_server/src/middleware/middleware.dart';

// Import the new router module
import 'package:mock_api_server/src/routes/api_router.dart';

// Import the config (provides verboseLoggingEnabled)
import 'package:mock_api_server/src/config.dart';

// Main function now just adds the router, as middleware is applied per-route or globally
Future<void> main(List<String> args) async {
  // Define argument parser
  final parser = ArgParser()
    ..addOption('port',
        abbr: 'p', defaultsTo: '8080', help: 'Port to listen on.')
    ..addFlag('verbose',
        abbr: 'v', defaultsTo: false, help: 'Enable verbose logging');
  final results = parser.parse(args);
  verboseLoggingEnabled = results['verbose'] as bool;

  // Use the port from command-line arguments. ArgParser handles the default.
  final String portString = results['port'] as String;
  final port = int.parse(portString);

  try {
    // Simplified Main server pipeline
    final handler = const Pipeline()
        .addMiddleware(
            logRequests()) // Assuming logRequests is globally available or imported
        .addMiddleware(debugMiddleware())
        .addMiddleware(authMiddleware())
        .addHandler(router.call); // Use the new public router

    // Create server
    final server = await io.serve(handler, 'localhost', port);
    print('Mock server listening on port ${server.port}');

    // Handle signals for graceful shutdown
    ProcessSignal.sigint.watch().listen((_) async {
      print('Received SIGINT - shutting down gracefully...');
      await server.close(force: false);
      exit(0);
    });

    ProcessSignal.sigterm.watch().listen((_) async {
      print('Received SIGTERM - shutting down gracefully...');
      await server.close(force: false);
      exit(0);
    });
  } catch (e, stack) {
    print('ERROR starting server: $e');
    print('Stack trace: $stack');
    exit(1);
  }
}
