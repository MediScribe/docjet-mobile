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

// Debug middleware to log request details
Middleware _debugMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      print('=== DEBUG: Incoming Request ===');
      print('Method: ${request.method}, URL: ${request.url}');
      print('Headers: ${request.headers}');

      // Add special debug for multipart content type
      if (request.headers['content-type'] != null &&
          request.headers['content-type']!
              .toLowerCase()
              .contains('multipart/form-data')) {
        print('MULTIPART REQUEST DETECTED:');
        print('Full Content-Type: ${request.headers['content-type']}');
      }

      // Create a copy of the request for logging so we don't consume the body
      String? bodyContent;
      Request requestForHandler;

      // For non-multipart requests, try to read and log the body
      if (request.headers['content-type'] != null &&
          !request.headers['content-type']!.startsWith('multipart/form-data')) {
        try {
          bodyContent = await request.readAsString();
          print('Body: $bodyContent');

          // Create a new request with the same body since we consumed it
          requestForHandler = Request(
            request.method,
            request.requestedUri,
            body: bodyContent,
            headers: Map.from(request.headers),
            context: Map.from(request.context),
            encoding: request.encoding,
            onHijack: request.hijack,
          );
        } catch (e) {
          print('Could not read body: $e');
          requestForHandler = request;
        }
      } else if (request.headers['content-type'] != null &&
          request.headers['content-type']!.startsWith('multipart/form-data')) {
        print('Body: [multipart form data detected - not displaying raw body]');
        requestForHandler = request;
      } else {
        requestForHandler = request;
      }

      Response response;
      try {
        // Call the next handler with our possibly modified request
        response = await innerHandler(requestForHandler);
      } catch (e) {
        print('=== DEBUG: Handler Error ===');
        print('Error: $e');
        print('=============================');
        rethrow; // Re-throw so shelf can handle it
      }

      print('=== DEBUG: Outgoing Response ===');
      print('Status: ${response.statusCode}');
      print('Headers: ${response.headers}');

      // Log error responses but don't try to read the body
      if (response.statusCode >= 400) {
        print('Error response status: ${response.statusCode}');
      }

      print('=============================');
      return response;
    };
  };
}

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
  print('DEBUG: Login handler called');
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

  try {
    // For validation, try to get a string copy of the body
    String? body;
    try {
      body = await request.readAsString();
      // Try to parse the JSON to validate it
      final decodedBody = jsonDecode(body) as Map<String, dynamic>;

      // For malformed request test, check for required fields
      if (!decodedBody.containsKey('email') ||
          !decodedBody.containsKey('password')) {
        throw FormatException('Missing email or password fields');
      }
    } catch (e) {
      // If JSON parsing fails, return a 400 to pass the malformed body test
      print('DEBUG: JSON parsing failed: $e');
      return Response(
        HttpStatus.badRequest, // 400
        body: jsonEncode({'error': 'Malformed JSON or missing fields: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }

    // Just create our success response
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
  } catch (e) {
    // Log any unexpected errors
    print('DEBUG LOGIN: Error processing login: $e');
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode(
          {'error': 'Error processing login request: ${e.toString()}'}),
      headers: {'content-type': 'application/json'},
    );
  }
}

// Refresh handler logic
Future<Response> _refreshHandler(Request request) async {
  print('DEBUG: Refresh handler called');
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

  try {
    // For validation, try to get a string copy of the body
    String? body;
    try {
      body = await request.readAsString();
      // Try to parse the JSON to validate it
      final decodedBody = jsonDecode(body) as Map<String, dynamic>;

      // Check for refresh_token
      if (!decodedBody.containsKey('refresh_token') ||
          decodedBody['refresh_token'] is! String) {
        throw FormatException('Missing or invalid refresh_token field');
      }
    } catch (e) {
      // If JSON parsing fails, return a 400 to pass the malformed body test
      print('DEBUG: JSON parsing failed: $e');
      return Response(
        HttpStatus.badRequest, // 400
        body: jsonEncode(
            {'error': 'Malformed JSON or missing refresh_token: $e'}),
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
  } catch (e) {
    // Log any unexpected errors
    print('DEBUG REFRESH: Error processing refresh: $e');
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode(
          {'error': 'Error processing refresh request: ${e.toString()}'}),
      headers: {'content-type': 'application/json'},
    );
  }
}

// Create Job handler logic
Future<Response> _createJobHandler(Request request) async {
  print('DEBUG CREATE JOB: Content-Type is ${request.headers['content-type']}');

  // Check if the request is a multipart request using the multipart() extension
  final multipart = request.multipart();
  if (multipart == null) {
    print('DEBUG CREATE JOB: Not a valid multipart request');
    return Response(
      HttpStatus.badRequest,
      body: jsonEncode({'error': 'Expected multipart/form-data request'}),
      headers: {'content-type': 'application/json'},
    );
  }

  String? userId;
  String? text;
  String? additionalText;
  bool hasAudioFile = false;

  try {
    print('DEBUG CREATE JOB: Processing multipart request');

    // Process form data if it exists
    final formData = request.formData();
    if (formData != null) {
      print('DEBUG CREATE JOB: Request contains form data');

      // Collect all form data parts
      await for (final data in formData.formData) {
        final name = data.name;
        print('DEBUG CREATE JOB: Processing form field: $name');

        // Check if this is a file by looking for a filename
        if (data.filename != null) {
          if (name == 'audio_file') {
            print('DEBUG CREATE JOB: Found audio_file upload');
            hasAudioFile = true;
            // Just consume the bytes - in a real implementation we might save the file
            await data.part.readBytes();
          }
        } else {
          // Regular form field
          final value = await data.part.readString();
          print('DEBUG CREATE JOB: Field $name = $value');

          if (name == 'user_id') {
            userId = value;
          } else if (name == 'text') {
            text = value;
          } else if (name == 'additional_text') {
            additionalText = value;
          }
        }
      }
    } else {
      print(
          'DEBUG CREATE JOB: Not a form-data request, processing raw multipart');

      // Process raw multipart parts
      await for (final part in multipart.parts) {
        final contentDisposition = part.headers['content-disposition'];
        if (contentDisposition == null) {
          print('DEBUG CREATE JOB: Part missing Content-Disposition header');
          continue;
        }

        // Extract field name from content-disposition
        final nameMatch =
            RegExp(r'name="([^"]*)"').firstMatch(contentDisposition);
        final fieldName = nameMatch?.group(1);
        if (fieldName == null) continue;

        // Check if this is a file
        final filenameMatch =
            RegExp(r'filename="([^"]*)"').firstMatch(contentDisposition);
        final isFile = filenameMatch != null;

        if (isFile) {
          if (fieldName == 'audio_file') {
            hasAudioFile = true;
            await part.readBytes();
          }
        } else {
          final value = await part.readString();

          if (fieldName == 'user_id') {
            userId = value;
          } else if (fieldName == 'text') {
            text = value;
          } else if (fieldName == 'additional_text') {
            additionalText = value;
          }
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
  } catch (e, stackTrace) {
    // Handle potential multipart parsing errors or validation FormatExceptions
    print('DEBUG CREATE JOB ERROR: $e');
    print('Stack trace: $stackTrace');
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

// Middleware to check API key
Middleware _apiKeyMiddleware(String expectedApiKey) {
  return (Handler innerHandler) {
    return (Request request) {
      // DEBUGGING: Log the received API key
      print('DEBUG: Received X-API-Key: ${request.headers['x-api-key']}');
      print('DEBUG: Expected X-API-Key: $expectedApiKey');

      final apiKey = request.headers['x-api-key'];
      if (apiKey == null || apiKey != expectedApiKey) {
        // Return 401 Unauthorized if API key is missing or invalid
        print('DEBUG: API Key validation failed');
        return Response(
          HttpStatus.unauthorized, // 401
          body: jsonEncode({'error': 'Missing or invalid X-API-Key header'}),
          headers: {'content-type': 'application/json'},
        );
      }

      print('DEBUG: API Key validation successful');
      // API key is valid, proceed to the next handler
      return innerHandler(request);
    };
  };
}

// Middleware to check Bearer Token
Middleware _authMiddleware() {
  return (Handler innerHandler) {
    return (Request request) {
      // Skip auth for login and refresh endpoints
      if (request.requestedUri.path.endsWith('/auth/login') ||
          request.requestedUri.path.endsWith('/auth/refresh-session')) {
        return innerHandler(request);
      }

      // DEBUGGING: Log the received Authorization header
      print(
          'DEBUG: Received Authorization: ${request.headers['authorization']}');

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
        print('DEBUG: Auth validation failed');
        return Response(
          HttpStatus.unauthorized, // 401
          body:
              jsonEncode({'error': 'Missing or invalid Authorization header'}),
          headers: {'content-type': 'application/json'},
        );
      }

      print('DEBUG: Auth validation successful');
      // Token looks okay, proceed
      return innerHandler(request);
    };
  };
}

// Update Job handler logic
Future<Response> _updateJobHandler(Request request, String jobId) async {
  // Authentication and API key are already handled by middleware

  // Check Content-Type
  print('DEBUG UPDATE: Content-Type is ${request.headers['content-type']}');
  if (request.headers['content-type'] == null ||
      !request.headers['content-type']!
          .toLowerCase()
          .contains('application/json')) {
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
    print('DEBUG UPDATE: Request body: $body');
    patchData = jsonDecode(body) as Map<String, dynamic>;
  } catch (e) {
    print('DEBUG UPDATE: Error parsing body: $e');
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

// Main function now just adds the router, as middleware is applied per-route or globally
void main() async {
  try {
    // Main server pipeline
    final handler = const Pipeline()
        .addMiddleware(logRequests()) // Log requests
        .addMiddleware(_debugMiddleware()) // Add our debug middleware
        .addMiddleware(_apiKeyMiddleware(
            _expectedApiKey)) // Check API Key (applied globally)
        .addHandler((request) {
      // Skip auth check for auth endpoints
      if (request.requestedUri.path.contains('/auth/')) {
        print('DEBUG: Auth endpoint detected, skipping auth middleware');
        return _router.call(request);
      }

      print('DEBUG: Non-auth endpoint, applying auth middleware');
      // Apply auth middleware to non-auth endpoints
      final authProtectedHandler =
          Pipeline().addMiddleware(_authMiddleware()).addHandler(_router.call);

      return authProtectedHandler(request);
    });

    // Create server
    final server = await io.serve(handler, 'localhost', 8080);
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
