// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

import 'dart:async'; // Make sure Timer is imported
import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

// Import the new middleware module
import '../src/middleware/middleware.dart';

// Import the new router module
import '../src/routes/api_router.dart';

// Import the config (provides verboseLoggingEnabled)
import 'package:mock_api_server/src/config.dart';

// Debug handler to get all request details (should be public for router)
Future<Response> debugHandler(Request request) async {
  final debugInfo = {
    'method': request.method,
    'url': request.url.toString(),
    'headers': request.headers,
    'protocolVersion': request.protocolVersion,
    'contentLength': request.contentLength,
    // Add more details as needed
  };
  if (verboseLoggingEnabled) {
    print(
        'DEBUG HANDLER: \n${debugInfo.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}');
  }
  return Response.ok(
    jsonEncode({'message': 'Debug information collected.', 'data': debugInfo}),
    headers: {'content-type': 'application/json'},
  );
}

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
