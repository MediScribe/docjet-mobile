import 'package:shelf/shelf.dart';

/// Handles health check requests.
Response healthHandler(Request request) {
  return Response.ok('OK');
}
