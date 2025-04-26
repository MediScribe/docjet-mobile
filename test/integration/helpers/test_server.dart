import 'dart:async';
import 'dart:io';

import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

/// A simple HTTP server for integration testing that logs and tracks requests
class TestServer {
  final HttpServer _server;
  HttpRequest? _lastRequest;
  final List<HttpRequest> _requests = [];
  final Logger _logger = LoggerFactory.getLogger(
    'TestServer',
    level: Level.debug,
  );
  final String _tag = logTag('TestServer');

  TestServer._(this._server);

  /// Creates and starts a test server on a random port
  static Future<TestServer> create() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final logger = LoggerFactory.getLogger('TestServer', level: Level.debug);
    final tag = logTag('TestServer');

    logger.i('$tag Started on port ${server.port}');
    final testServer = TestServer._(server);

    server.listen((request) async {
      testServer._logger.i(
        '${testServer._tag} Received ${request.method} request to: ${request.uri}',
      );
      testServer._logger.d('${testServer._tag} Headers: ${request.headers}');

      testServer._lastRequest = request;
      testServer._requests.add(request);

      // Read request body if present
      List<int> body = [];
      await for (var chunk in request) {
        body.addAll(chunk);
      }
      if (body.isNotEmpty) {
        testServer._logger.d(
          '${testServer._tag} Body: ${String.fromCharCodes(body)}',
        );
      }

      // Always respond with 200 OK and JSON
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"success": true}');
      await request.response.close();

      testServer._logger.d('${testServer._tag} Response sent with status 200');
    });

    return testServer;
  }

  /// The port this server is listening on
  int get port => _server.port;

  /// The most recent request received by the server
  HttpRequest? get lastRequest => _lastRequest;

  /// All requests received by this server
  List<HttpRequest> get requests => List.unmodifiable(_requests);

  /// Closes the server
  Future<void> close() async {
    _logger.i('$_tag Closing server on port ${_server.port}');
    await _server.close();
    _logger.i('$_tag Server closed');
  }
}

/// Creates a test server for integration testing
Future<TestServer> createTestServer() async {
  return TestServer.create();
}
