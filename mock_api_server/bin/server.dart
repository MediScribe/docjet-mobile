import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:uuid/uuid.dart';

// Hardcoded API key for mock validation, matching the test
const String _expectedApiKey = 'test-api-key';

// In-memory storage for jobs
final List<Map<String, dynamic>> _jobs = [];
const _uuid = Uuid();

// Define the router
final _router = Router()
  ..post('/api/v1/auth/login', _loginHandler)
  ..post('/api/v1/auth/refresh-session', _refreshHandler)
  ..post('/api/v1/jobs', _createJobHandler)
  ..get('/api/v1/jobs', _listJobsHandler)
  ..get('/api/v1/jobs/<jobId>', _getJobByIdHandler)
  ..get('/api/v1/jobs/<jobId>/documents', _getJobDocumentsHandler)
  ..patch('/api/v1/jobs/<jobId>', _updateJobHandler);

// Login handler logic
Future<Response> _loginHandler(Request request) async {
  // Content-Type check (middleware could also do this, but fine here for simplicity)
  if (request.headers['content-type']
          ?.toLowerCase()
          .startsWith('application/json') !=
      true) {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode(
          {'error': 'Expected Content-Type starting with application/json'}),
      headers: {'content-type': 'application/json'},
    );
  }

  String body;
  try {
    body = await request.readAsString();
    // Validate the body contains expected fields (basic check)
    final decodedBody = jsonDecode(body) as Map<String, dynamic>;
    if (!decodedBody.containsKey('email') ||
        !decodedBody.containsKey('password')) {
      throw FormatException('Missing email or password');
    }
    // In a real app, you'd validate email/password from the parsed body here
  } catch (e) {
    // Catches JSON parsing errors and FormatException for missing keys
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode(
          {'error': 'Malformed JSON body or missing fields: ${e.toString()}'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // For the mock, we just return success if JSON is valid and has keys
  final responseBody = jsonEncode({
    'access_token':
        'fake-access-token-${DateTime.now().millisecondsSinceEpoch}',
    'refresh_token':
        'fake-refresh-token-${DateTime.now().millisecondsSinceEpoch}',
    'user_id': 'fake-user-id-123',
  });

  return Response.ok(
    responseBody,
    headers: {'content-type': 'application/json'},
  );
}

// Refresh handler logic
Future<Response> _refreshHandler(Request request) async {
  // Content-Type check
  if (request.headers['content-type']
          ?.toLowerCase()
          .startsWith('application/json') !=
      true) {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode(
          {'error': 'Expected Content-Type starting with application/json'}),
      headers: {'content-type': 'application/json'},
    );
  }

  String body;
  try {
    body = await request.readAsString();
    // Validate the body contains the refresh_token field
    final decodedBody = jsonDecode(body) as Map<String, dynamic>;
    if (!decodedBody.containsKey('refresh_token') ||
        decodedBody['refresh_token'] is! String) {
      throw FormatException('Missing or invalid refresh_token field');
    }
    // In a real app, you'd validate the actual refresh token value here
  } catch (e) {
    // Catches JSON parsing errors and FormatException for missing/invalid field
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({
        'error':
            'Malformed JSON body or missing/invalid refresh_token: ${e.toString()}'
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  // Return new fake tokens
  final responseBody = jsonEncode({
    'access_token':
        'new-fake-access-token-${DateTime.now().millisecondsSinceEpoch}',
    'refresh_token':
        'new-fake-refresh-token-${DateTime.now().millisecondsSinceEpoch}',
  });

  return Response.ok(
    responseBody,
    headers: {'content-type': 'application/json'},
  );
}

// Create Job handler logic
Future<Response> _createJobHandler(Request request) async {
  // Check if the request is multipart by checking content-type header
  if (request.headers['content-type'] == null ||
      !request.headers['content-type']!
          .toLowerCase()
          .startsWith('multipart/form-data')) {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({'error': 'Expected multipart/form-data request'}),
      headers: {'content-type': 'application/json'},
    );
  }

  String? userId;
  String? text;
  String? additionalText;
  bool hasAudioFile = false;

  try {
    // Get multipart request handler
    final multipart = MultipartRequest.of(request);
    if (multipart == null) {
      return Response(
        HttpStatus.badRequest,
        body: jsonEncode({'error': 'Invalid multipart request format'}),
        headers: {'content-type': 'application/json'},
      );
    }

    // Process all parts
    await for (final part in multipart.parts) {
      final contentDisposition = part.headers['content-disposition'];
      if (contentDisposition == null) continue;

      // Extract field name from content-disposition
      final nameMatch =
          RegExp(r'name="([^"]*)"').firstMatch(contentDisposition);
      final fieldName = nameMatch?.group(1);
      if (fieldName == null) continue;

      // Check if this is a file by looking for filename in content-disposition
      final filenameMatch =
          RegExp(r'filename="([^"]*)"').firstMatch(contentDisposition);
      final hasFilename = filenameMatch != null;

      if (hasFilename) {
        // This is a file upload
        if (fieldName == 'audio_file') {
          hasAudioFile = true;
          // Just consume the stream - in a real implementation we might save the file
          await part.readBytes();
        }
      } else {
        // This is a regular form field
        final value = await utf8.decoder.bind(part).join();

        if (fieldName == 'user_id') {
          userId = value;
        } else if (fieldName == 'text') {
          text = value;
        } else if (fieldName == 'additional_text') {
          additionalText = value;
        }
      }
    }

    // Validate required fields
    if (userId == null || userId.isEmpty) {
      throw FormatException('Missing or empty user_id field');
    }
    if (!hasAudioFile) {
      throw FormatException('Missing audio_file part');
    }

    // Create and store the job
    final now = DateTime.now().toUtc().toIso8601String();
    final newJob = {
      'id': _uuid.v4(),
      'user_id': userId,
      'job_status': 'submitted',
      'error_code': null,
      'error_message': null,
      'created_at': now,
      'updated_at': now,
      'text': text,
      'additional_text': additionalText,
      'display_title': null,
      'display_text': null,
      'transcript': null,
      'audio_file_path': null,
    };

    _jobs.add(newJob);

    // Prepare response data
    final responseData = {
      'id': newJob['id'],
      'user_id': newJob['user_id'],
      'job_status': newJob['job_status'],
      'created_at': newJob['created_at'],
      'updated_at': newJob['updated_at'],
      'text': newJob['text'],
      'additional_text': newJob['additional_text'],
    };

    return Response.ok(
      jsonEncode({'data': responseData}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    // Handle potential multipart parsing errors or validation FormatExceptions
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({'error': 'Failed to process request: ${e.toString()}'}),
      headers: {'content-type': 'application/json'},
    );
  }
}

// List Jobs handler logic
Future<Response> _listJobsHandler(Request request) async {
  // Authentication and API key are already handled by middleware

  // Prepare the response data - we need to return a list of job summaries.
  // The exact fields might differ from the POST response based on spec.
  // Let's assume for now it returns the same fields as POST creation response.
  final responseData = _jobs
      .map((job) => {
            'id': job['id'],
            'user_id': job['user_id'],
            'job_status': job['job_status'],
            'created_at': job['created_at'],
            'updated_at': job['updated_at'],
            'text': job['text'],
            'additional_text': job['additional_text'],
            // Spec might dictate fewer fields here (e.g., no text/additional_text)
            // We exclude display_title and display_text as per previous test fix
          })
      .toList();

  return Response.ok(
    jsonEncode({'data': responseData}),
    headers: {'content-type': 'application/json'},
  );
}

// Get Job by ID handler logic
Future<Response> _getJobByIdHandler(Request request, String jobId) async {
  // Authentication and API key are already handled by middleware

  // Find the job by ID
  Map<String, dynamic>? foundJob;
  try {
    foundJob = _jobs.firstWhere((job) => job['id'] == jobId);
  } on StateError {
    // Thrown by firstWhere if no element is found
    foundJob = null;
  }

  if (foundJob == null) {
    return Response(
      HttpStatus.notFound, // 404
      body: jsonEncode({'error': 'Job with ID $jobId not found'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // Prepare response data (similar to POST response, excluding null display fields)
  final responseData = {
    'id': foundJob['id'],
    'user_id': foundJob['user_id'],
    'job_status': foundJob['job_status'],
    'created_at': foundJob['created_at'],
    'updated_at': foundJob['updated_at'],
    'text': foundJob['text'],
    'additional_text': foundJob['additional_text'],
    // Exclude other potential fields like transcript, display_title, etc.
  };

  return Response.ok(
    jsonEncode({'data': responseData}),
    headers: {'content-type': 'application/json'},
  );
}

// Get Job Documents handler logic
Future<Response> _getJobDocumentsHandler(Request request, String jobId) async {
  // Authentication and API key are already handled by middleware

  // Define baseUrl locally or make it accessible globally
  final String baseUrl = 'http://localhost:8080'; // Define baseUrl here

  // Find the job by ID first
  Map<String, dynamic>? foundJob;
  try {
    foundJob = _jobs.firstWhere((job) => job['id'] == jobId);
  } on StateError {
    foundJob = null;
  }

  if (foundJob == null) {
    return Response(
      HttpStatus.notFound, // 404
      body: jsonEncode({'error': 'Job with ID $jobId not found'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // Job found, return mock document data
  // In a real backend, this would fetch actual document info related to the job
  final mockDocuments = [
    {
      'id': 'doc-${_uuid.v4()}',
      'type': 'transcript',
      'url':
          '$baseUrl/api/v1/documents/doc-transcript-$jobId.txt' // Use defined baseUrl
    },
    {
      'id': 'doc-${_uuid.v4()}',
      'type': 'summary',
      'url':
          '$baseUrl/api/v1/documents/doc-summary-$jobId.pdf' // Use defined baseUrl
    }
  ];

  return Response.ok(
    jsonEncode({'data': mockDocuments}),
    headers: {'content-type': 'application/json'},
  );
}

// Update Job handler logic
Future<Response> _updateJobHandler(Request request, String jobId) async {
  // Authentication and API key are already handled by middleware

  // Check Content-Type
  if (request.headers['content-type']
          ?.toLowerCase()
          .startsWith('application/json') !=
      true) {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({'error': 'Expected Content-Type: application/json'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // Find the job index by ID
  final jobIndex = _jobs.indexWhere((job) => job['id'] == jobId);

  if (jobIndex == -1) {
    return Response(
      HttpStatus.notFound, // 404
      body: jsonEncode({'error': 'Job with ID $jobId not found'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // Get the existing job data
  final existingJob = _jobs[jobIndex];
  Map<String, dynamic> updatedJobData = Map.from(existingJob);

  // Parse the request body
  String body;
  Map<String, dynamic> patchData;
  try {
    body = await request.readAsString();
    patchData = jsonDecode(body) as Map<String, dynamic>;
  } catch (e) {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({'error': 'Malformed JSON body: ${e.toString()}'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // Apply updates from the patch data
  bool updated = false;
  if (patchData.containsKey('text')) {
    updatedJobData['text'] = patchData['text'];
    updated = true;
  }
  if (patchData.containsKey('display_title')) {
    updatedJobData['display_title'] = patchData['display_title'];
    updated = true;
  }
  if (patchData.containsKey('display_text')) {
    updatedJobData['display_text'] = patchData['display_text'];
    updated = true;
    // Optionally update status when display fields are set
    updatedJobData['job_status'] = 'transcribed';
  }

  // Always update the updated_at timestamp if any field was changed
  if (updated) {
    updatedJobData['updated_at'] = DateTime.now().toUtc().toIso8601String();
  }

  // Update the job in the in-memory list
  _jobs[jobIndex] = updatedJobData;

  // Prepare response data (only include fields present in the updated map)
  final responseData = Map.from(updatedJobData);
  // Clean up potentially null internal fields before sending response
  responseData.removeWhere((key, value) =>
      key == 'audio_file_path' ||
      key == 'transcript' ||
      (key == 'error_code' && value == null) ||
      (key == 'error_message' && value == null));
  // Ensure display fields are present even if null after update
  responseData.putIfAbsent('display_title', () => null);
  responseData.putIfAbsent('display_text', () => null);

  return Response.ok(
    jsonEncode({'data': responseData}),
    headers: {'content-type': 'application/json'},
  );
}

// Middleware to check API key
Middleware _apiKeyMiddleware(String expectedApiKey) {
  return (Handler innerHandler) {
    return (Request request) {
      final apiKey = request.headers['x-api-key'];
      if (apiKey == null || apiKey != expectedApiKey) {
        // Return 401 Unauthorized if API key is missing or invalid
        return Response(
          HttpStatus.unauthorized, // 401
          body: jsonEncode({'error': 'Missing or invalid X-API-Key header'}),
          headers: {'content-type': 'application/json'},
        );
      }
      // API key is valid, proceed to the next handler
      return innerHandler(request);
    };
  };
}

// Middleware to check Bearer Token
Middleware _authMiddleware() {
  return (Handler innerHandler) {
    return (Request request) {
      final authHeader = request.headers['authorization'];
      bool isValid = false;
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        // Basic check: just see if it looks like a Bearer token
        // In a real app, you'd parse and validate the JWT
        final token = authHeader.substring(7);
        if (token.isNotEmpty) {
          isValid = true;
          // Optional: Add parsed token/user info to request context
          // request = request.change(context: {'user': ...});
        }
      }

      if (!isValid) {
        return Response(
          HttpStatus.unauthorized, // 401
          body:
              jsonEncode({'error': 'Missing or invalid Authorization header'}),
          headers: {'content-type': 'application/json'},
        );
      }
      // Token looks okay, proceed
      return innerHandler(request);
    };
  };
}

// Main function now just adds the router, as middleware is applied per-route or globally
void main() async {
  final handler = const Pipeline()
      .addMiddleware(logRequests()) // Log requests
      .addMiddleware(_apiKeyMiddleware(
          _expectedApiKey)) // Check API Key (applied globally)
      .addMiddleware(_authMiddleware()) // Check Bearer Token (applied globally)
      .addHandler(
          _router); // Add the router (job route has its own multipart middleware)

  final server = await io.serve(handler, 'localhost', 8080);
  print('Mock server listening on port ${server.port}');
}
