// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:mock_api_server/src/debug_handlers.dart'; // Import the real McCoy

// Placeholder removed, we are now using the real one from the import.
// Future<Response> _routeByJobIdPresence(
// Request request,
// Future<Response> Function(Request request, String jobId) singleJobHandler,
// Future<Response> Function(Request request) allJobsHandler,
// ) async {
//   final jobIdParam = request.url.queryParameters['id'];
//   if (jobIdParam == null || jobIdParam.isEmpty) {
//     return allJobsHandler(request);
//   } else if (jobIdParam.trim().isEmpty) {
//     return Response.badRequest(body: jsonEncode({'error': 'Job ID cannot be empty or just whitespace if provided.'}));
//   }
//   return singleJobHandler(request, jobIdParam);
// }

void main() {
  group('routeByJobIdPresence', () {
    // Updated group name to reflect public function
    // Mock handlers
    Future<Response> mockSingleJobHandler(Request req, String jobId) async {
      return Response.ok(jsonEncode({'handler': 'single', 'jobId': jobId}));
    }

    Future<Response> mockAllJobsHandler(Request req) async {
      return Response.ok(jsonEncode({'handler': 'all'}));
    }

    Request createTestRequest({String? idQueryParam}) {
      Map<String, String> queryParams = {};
      if (idQueryParam != null) {
        queryParams['id'] = idQueryParam;
      }
      return Request(
          'GET',
          Uri.parse('http://localhost/test').replace(
              queryParameters: queryParams.isNotEmpty ? queryParams : null));
    }

    test('calls allJobsHandler when id query parameter is null', () async {
      final request = createTestRequest(); // idQueryParam is null by default
      // Call the imported function
      final response = await routeByJobIdPresence(
          request, mockSingleJobHandler, mockAllJobsHandler);
      final body = jsonDecode(await response.readAsString());
      expect(response.statusCode, 200);
      expect(body['handler'], 'all');
    });

    test('calls allJobsHandler when id query parameter is an empty string',
        () async {
      final request = createTestRequest(idQueryParam: '');
      // Call the imported function
      final response = await routeByJobIdPresence(
          request, mockSingleJobHandler, mockAllJobsHandler);
      final body = jsonDecode(await response.readAsString());
      expect(response.statusCode, 200);
      expect(body['handler'], 'all');
    });

    test(
        'calls singleJobHandler with id when id query parameter is present and not empty',
        () async {
      final testId = 'test-job-123';
      final request = createTestRequest(idQueryParam: testId);
      // Call the imported function
      final response = await routeByJobIdPresence(
          request, mockSingleJobHandler, mockAllJobsHandler);
      final body = jsonDecode(await response.readAsString());
      expect(response.statusCode, 200);
      expect(body['handler'], 'single');
      expect(body['jobId'], testId);
    });

    test(
        'calls singleJobHandler with trimmed id when id has leading/trailing whitespace',
        () async {
      final testId = 'test-job-xyz';
      final requestWithWhitespace =
          createTestRequest(idQueryParam: '  $testId  ');
      final response = await routeByJobIdPresence(
          requestWithWhitespace, mockSingleJobHandler, mockAllJobsHandler);
      final body = jsonDecode(await response.readAsString());
      expect(response.statusCode, 200);
      expect(body['handler'], 'single');
      expect(body['jobId'], testId); // Expect trimmed ID
    });

    test(
        'returns 400 Bad Request when id query parameter is present but only whitespace',
        () async {
      final request = createTestRequest(idQueryParam: '   ');
      // Call the imported function
      final response = await routeByJobIdPresence(
          request, mockSingleJobHandler, mockAllJobsHandler);
      expect(response.statusCode, 400);
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], isNotNull);
      expect(body['error'],
          'Job ID cannot be empty or just whitespace if provided.');
    });

    test('passes the original request object to allJobsHandler', () async {
      final request = createTestRequest();
      Request? capturedRequest;
      Future<Response> capturingAllJobsHandler(Request req) async {
        capturedRequest = req;
        return Response.ok(jsonEncode({'handler': 'all'}));
      }

      // Call the imported function
      await routeByJobIdPresence(
          request, mockSingleJobHandler, capturingAllJobsHandler);
      expect(capturedRequest, same(request));
    });

    test('passes the original request object and id to singleJobHandler',
        () async {
      final testId = 'test-job-456';
      final request = createTestRequest(idQueryParam: testId);
      Request? capturedRequest;
      String? capturedJobId;

      Future<Response> capturingSingleJobHandler(
          Request req, String jobId) async {
        capturedRequest = req;
        capturedJobId = jobId;
        return Response.ok(jsonEncode({'handler': 'single', 'jobId': jobId}));
      }

      // Call the imported function
      await routeByJobIdPresence(
          request, capturingSingleJobHandler, mockAllJobsHandler);
      expect(capturedRequest, same(request));
      expect(capturedJobId, testId);
    });
  });
}
