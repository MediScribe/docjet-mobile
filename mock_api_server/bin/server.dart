// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

import 'dart:async'; // Make sure Timer is imported
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:uuid/uuid.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart'; // Import JWT library

// Import the new debug HANDLERS, including the cleanup function
import 'package:mock_api_server/src/debug_handlers.dart';
import 'package:mock_api_server/src/debug_helpers.dart';
// Import the new job store with a prefix
import 'package:mock_api_server/src/job_store.dart' as job_store;
// Import the config (provides verboseLoggingEnabled)
import 'package:mock_api_server/src/config.dart';

// API version (should match ApiConfig.apiVersion in the app)
const String _apiVersion = 'v1';
const String _apiPrefix = 'api';
const String _versionedApiPath = '$_apiPrefix/$_apiVersion';

// Hardcoded API key for mock validation, matching the test
const String _expectedApiKey = 'test-api-key';

const String _mockJwtSecret = 'mock-secret-key'; // Define JWT secret
const Duration _accessTokenDuration =
    Duration(seconds: 10); // Access token lifetime
const Duration _refreshTokenDuration =
    Duration(minutes: 5); // Refresh token lifetime

const Uuid _uuid = Uuid();

// Helper function to read MimeMultipart as string
Future<String> readAsString(Stream<List<int>> stream) async {
  // MimeMultipart is a Stream<List<int>>, so collect all chunks and decode
  final chunks = await stream.toList();
  final allBytes = <int>[];
  for (var chunk in chunks) {
    allBytes.addAll(chunk);
  }
  return utf8.decode(allBytes);
}

// Debug middleware to log request details
Middleware _debugMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (verboseLoggingEnabled) {
        print('=== DEBUG: Incoming Request ===');
        print('Method: ${request.method}, URL: ${request.url}');
        print('Headers: ${request.headers}');
      }

      // Add special debug for multipart content type
      if (verboseLoggingEnabled &&
          request.headers['content-type'] != null &&
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
          if (verboseLoggingEnabled) print('Body: $bodyContent');

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
          if (verboseLoggingEnabled) print('Could not read body: $e');
          requestForHandler = request;
        }
      } else if (request.headers['content-type'] != null &&
          request.headers['content-type']!.startsWith('multipart/form-data')) {
        if (verboseLoggingEnabled) {
          print(
              'Body: [multipart form data detected - not displaying raw body]');
        }
        requestForHandler = request;
      } else {
        requestForHandler = request;
      }

      Response response;
      try {
        // Call the next handler with our possibly modified request
        response = await innerHandler(requestForHandler);
      } catch (e) {
        if (verboseLoggingEnabled) {
          print('=== DEBUG: Handler Error ===');
          print('Error: $e');
          print('=============================');
        }
        rethrow; // Re-throw so shelf can handle it
      }

      if (verboseLoggingEnabled) {
        print('=== DEBUG: Outgoing Response ===');
        print('Status: ${response.statusCode}');
        print('Headers: ${response.headers}');
      }

      // Log error responses but don't try to read the body
      if (verboseLoggingEnabled && response.statusCode >= 400) {
        print('Error response status: ${response.statusCode}');
      }

      if (verboseLoggingEnabled) print('=============================');
      return response;
    };
  };
}

// Define the router with versioned endpoints
final _router = Router()
  // Health check (prefixed)
  ..get('/$_versionedApiPath/health', _healthHandler)

  // Authentication endpoints (prefixed)
  ..post('/$_versionedApiPath/auth/login', _loginHandler)
  ..post('/$_versionedApiPath/auth/refresh-session', _refreshHandler)

  // User profile endpoints (prefixed)
  ..get('/$_versionedApiPath/users/profile', _getUserProfileHandler)
  ..get('/$_versionedApiPath/users/<userId>', _getUserByIdHandler)

  // Job endpoints (prefixed)
  ..post('/$_versionedApiPath/jobs', _createJobHandler)
  ..get('/$_versionedApiPath/jobs', _listJobsHandler)
  ..get('/$_versionedApiPath/jobs/<jobId>', _getJobByIdHandler)
  ..get('/$_versionedApiPath/jobs/<jobId>/documents', _getJobDocumentsHandler)
  ..patch('/$_versionedApiPath/jobs/<jobId>', _updateJobHandler)
  ..delete('/$_versionedApiPath/jobs/<jobId>', _deleteJobHandler)

  // Debug endpoints for job progression (Use handlers from debug_handlers.dart)
  ..post('/$_versionedApiPath/debug/jobs/start', startJobProgressionHandler)
  ..post('/$_versionedApiPath/debug/jobs/stop', stopJobProgressionHandler)
  ..post('/$_versionedApiPath/debug/jobs/reset', resetJobProgressionHandler)

  // Debug endpoint for listing all jobs - requires standard API key auth
  ..get('/$_versionedApiPath/debug/jobs/list', listAllJobsHandler);

// Health check handler
Response _healthHandler(Request request) {
  return Response.ok('OK');
}

// Login handler logic
Future<Response> _loginHandler(Request request) async {
  if (verboseLoggingEnabled) print('DEBUG: Login handler called');
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
        throw const FormatException('Missing email or password fields');
      }
    } catch (e) {
      // If JSON parsing fails, return a 400 to pass the malformed body test
      if (verboseLoggingEnabled) print('DEBUG: JSON parsing failed: $e');
      return Response(
        HttpStatus.badRequest, // 400
        body: jsonEncode({'error': 'Malformed JSON or missing fields: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }

    // --- Generate Real JWTs ---
    final now = DateTime.now();
    final userId = 'fake-user-id-123'; // Keep user ID consistent

    // Create Access Token
    final accessJwt = JWT(
      {
        'sub': userId,
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': now.add(_accessTokenDuration).millisecondsSinceEpoch ~/ 1000,
        // Add other claims if needed, e.g., roles
      },
      issuer: 'mock-api-server',
    );
    final accessToken = accessJwt.sign(SecretKey(_mockJwtSecret));

    // Create Refresh Token
    final refreshJwt = JWT(
      {
        'sub': userId,
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': now.add(_refreshTokenDuration).millisecondsSinceEpoch ~/ 1000,
        // Optionally add a unique ID (jti) for refresh token revocation (not implemented here)
      },
      issuer: 'mock-api-server',
    );
    final refreshToken = refreshJwt.sign(SecretKey(_mockJwtSecret));

    // Create success response with real JWTs
    final responseBody = jsonEncode({
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user_id': userId,
    });

    return Response.ok(
      responseBody,
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    // Log any unexpected errors
    if (verboseLoggingEnabled) {
      print('DEBUG LOGIN: Error processing login: $e');
    }
    return Response(
      HttpStatus.internalServerError, // 500 for unexpected JWT errors maybe?
      body: jsonEncode(
          {'error': 'Error processing login request: ${e.toString()}'}),
      headers: {'content-type': 'application/json'},
    );
  }
}

// Refresh handler logic
Future<Response> _refreshHandler(Request request) async {
  if (verboseLoggingEnabled) print('DEBUG: Refresh handler called');

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

  String? requestBody;
  Map<String, dynamic>? decodedBody;
  try {
    requestBody = await request.readAsString();
    decodedBody = jsonDecode(requestBody) as Map<String, dynamic>;

    // Check if refresh_token field exists
    if (!decodedBody.containsKey('refresh_token')) {
      if (verboseLoggingEnabled) print('DEBUG: Missing refresh_token field');
      return Response(
        HttpStatus.badRequest, // 400
        body: jsonEncode({'error': 'Missing refresh_token field'}),
        headers: {'content-type': 'application/json'},
      );
    }

    // We don't actually validate the incoming token in the mock
    // final String incomingRefreshToken = decodedBody['refresh_token'] as String;
    // if (verboseLoggingEnabled) print('DEBUG: Incoming refresh token: $incomingRefreshToken');
  } catch (e) {
    // Handle JSON parsing errors or other issues reading the body
    if (verboseLoggingEnabled)
      print('DEBUG: Error processing refresh request body: $e');
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({'error': 'Malformed JSON or error reading body: $e'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // Generate new JWTs
  final now = DateTime.now();
  final nowEpochSeconds = now.millisecondsSinceEpoch ~/ 1000;
  const userId = 'fake-user-id-123'; // Use the same hardcoded ID

  // Create Access Token
  final accessJwt = JWT(
    {
      'sub': userId,
      'iat': nowEpochSeconds,
      'exp': nowEpochSeconds + _accessTokenDuration.inSeconds,
      // Add any other claims if needed for testing
    },
    // Use a standard JWT header if needed, default is HS256
    // header: {'alg': 'HS256', 'typ': 'JWT'},
  );
  final newAccessToken = accessJwt.sign(SecretKey(_mockJwtSecret));

  // Create Refresh Token
  final refreshJwt = JWT(
    {
      'sub': userId,
      'iat': nowEpochSeconds,
      'exp': nowEpochSeconds + _refreshTokenDuration.inSeconds,
    },
  );
  final newRefreshToken = refreshJwt.sign(SecretKey(_mockJwtSecret));

  if (verboseLoggingEnabled) {
    print('DEBUG: Generated new access token: $newAccessToken');
    print('DEBUG: Generated new refresh token: $newRefreshToken');
  }

  // Return the new tokens
  return Response.ok(
    jsonEncode({
      'access_token': newAccessToken,
      'refresh_token': newRefreshToken,
    }),
    headers: {
      'content-type': 'application/json',
    },
  );
}

// Get User Profile handler logic
Future<Response> _getUserProfileHandler(Request request) async {
  if (verboseLoggingEnabled) print('DEBUG: Get User Profile handler called');

  // --- JWT Validation ---
  try {
    final authorizationHeader = request.headers['authorization'];
    if (authorizationHeader == null ||
        !authorizationHeader.startsWith('Bearer ')) {
      if (verboseLoggingEnabled)
        print('DEBUG Profile: Missing or invalid Bearer token header.');
      return Response(HttpStatus.unauthorized,
          body: jsonEncode({'error': 'Missing or invalid Bearer token'}),
          headers: {'content-type': 'application/json'});
    }

    final token =
        authorizationHeader.substring(7); // Extract token after "Bearer "

    // Verify the token
    final jwt = JWT.verify(token, SecretKey(_mockJwtSecret));
    final userId = jwt.payload['sub'] as String?;

    if (userId == null) {
      if (verboseLoggingEnabled)
        print('DEBUG Profile: Token is missing \'sub\' (user ID) claim.');
      return Response(HttpStatus.unauthorized,
          body: jsonEncode({'error': 'Invalid token claims'}),
          headers: {'content-type': 'application/json'});
    }

    if (verboseLoggingEnabled)
      print('DEBUG Profile: Token validated for user: $userId');

    // --- Generate Response using validated User ID ---
    final responseBody = jsonEncode({
      'id': userId, // Use the ID from the token!
      'name': 'Mock User ($userId)', // Make name specific to validated user
      'email': 'mock.user.$userId@example.com', // Make email specific
      'settings': {
        'theme': 'dark',
        'notifications_enabled': true,
      },
    });

    return Response.ok(
      responseBody,
      headers: {'content-type': 'application/json'},
    );
  } on JWTExpiredException {
    if (verboseLoggingEnabled) print('DEBUG Profile: JWT expired.');
    return Response(HttpStatus.unauthorized,
        body: jsonEncode({'error': 'Token expired'}),
        headers: {'content-type': 'application/json'});
  } on JWTException catch (ex) {
    // Catches other JWT errors (signature, format)
    if (verboseLoggingEnabled)
      print('DEBUG Profile: JWT validation error: ${ex.message}');
    return Response(HttpStatus.unauthorized,
        body: jsonEncode({'error': 'Invalid token: ${ex.message}'}),
        headers: {'content-type': 'application/json'});
  } catch (e) {
    if (verboseLoggingEnabled) print('DEBUG Profile: Unexpected error: $e');
    return Response.internalServerError(
        body: jsonEncode({'error': 'Internal server error'}),
        headers: {'content-type': 'application/json'});
  }
}

// Get User By ID handler logic
Future<Response> _getUserByIdHandler(Request request, String userId) async {
  if (verboseLoggingEnabled) {
    print('DEBUG: Get User By ID handler called for userId: $userId');
  }

  // Note: Header validation (API Key) is done by the middleware

  // Validate userId format/presence
  if (userId.isEmpty) {
    return Response(
      HttpStatus.badRequest,
      body: jsonEncode({'error': 'User ID cannot be empty'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // --- Mock User Existence Check ---
  // Here, we'll just check against the specific ID used in tests.
  const String expectedWorkaroundUserId =
      'fake-user-id-123'; // User ID from JWT/workaround

  if (userId != expectedWorkaroundUserId) {
    // Also allow the old test ID for compatibility, remove later if needed
    const String oldTestUserId = 'user-from-path-123';
    if (userId != oldTestUserId) {
      if (verboseLoggingEnabled) {
        print(
            'DEBUG GetUserById: User ID "$userId" not found (expecting "$expectedWorkaroundUserId" or "$oldTestUserId").');
      }
      // Return 404 Not Found
      return Response.notFound(
        jsonEncode({'error': 'User with ID \'$userId\' not found'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }
  // --- End Mock User Existence Check ---

  // User ID is known, proceed to generate response
  if (verboseLoggingEnabled) {
    print('DEBUG GetUserById: User ID "$userId" found. Generating response.');
  }

  final responseBody = jsonEncode({
    'id': userId, // Use the ID from the URL path
    'name': 'Mock User (ID: $userId)', // Add ID to name for clarity
    'email': 'mock.user.$userId@example.com', // Make email unique too
    'settings': {
      'theme': 'light', // Slightly different settings for testing
      'notifications_enabled': false,
    },
  });

  return Response.ok(
    responseBody,
    headers: {'content-type': 'application/json'},
  );
}

// Create Job handler logic
Future<Response> _createJobHandler(Request request) async {
  if (verboseLoggingEnabled) {
    print(
        'DEBUG CREATE JOB: Content-Type is ${request.headers['content-type']}');
  }

  // Additional debugging for the request
  if (verboseLoggingEnabled) {
    print('DEBUG CREATE JOB: All headers:');
    request.headers.forEach((name, value) {
      print('  $name: $value');
    });
  }

  // IMPORTANT: DO NOT read the request body here as it can only be read once
  if (verboseLoggingEnabled) {
    print('DEBUG CREATE JOB: Processing multipart request');
  }

  // More lenient check for multipart content type
  if (request.headers['content-type'] == null ||
      !request.headers['content-type']!
          .toLowerCase()
          .contains('multipart/form-data')) {
    if (verboseLoggingEnabled) {
      print(
          'DEBUG CREATE JOB: Not a valid multipart request. Content-Type: ${request.headers['content-type']}');
    }
    return Response(
      HttpStatus.badRequest,
      body: jsonEncode(
          {'error': 'Expected Content-Type containing multipart/form-data'}),
      headers: {'content-type': 'application/json'},
    );
  }

  String? userId;
  String? text;
  String? additionalText;
  bool hasAudioFile = false;

  try {
    if (verboseLoggingEnabled) {
      print('DEBUG CREATE JOB: Processing multipart request');
    }

    // First, ensure we have a multipart request
    final multipartRequest = request.multipart();
    if (multipartRequest == null) {
      throw const FormatException('Could not parse as multipart request');
    }

    // Initialize variables to store form data
    userId = null;
    text = null;
    additionalText = null;
    hasAudioFile = false;

    // Process the multipart parts directly without storing them first
    await for (final part in multipartRequest.parts) {
      final headers = part.headers;
      if (verboseLoggingEnabled) {
        print('DEBUG CREATE JOB: Part headers: $headers');
      }

      final contentDisposition = headers['content-disposition'];
      if (contentDisposition == null) {
        if (verboseLoggingEnabled) {
          print('DEBUG CREATE JOB: Missing Content-Disposition header in part');
        }
        continue;
      }

      // Extract field name and filename
      final nameMatch =
          RegExp(r'name="([^"]*)"').firstMatch(contentDisposition);
      final filenameMatch =
          RegExp(r'filename="([^"]*)"').firstMatch(contentDisposition);

      final name = nameMatch?.group(1);
      final filename = filenameMatch?.group(1);

      if (name == null) {
        if (verboseLoggingEnabled) {
          print(
              'DEBUG CREATE JOB: Could not find name in Content-Disposition: $contentDisposition');
        }
        continue;
      }

      if (verboseLoggingEnabled) {
        print(
            'DEBUG CREATE JOB: Processing part with name: $name, filename: $filename');
      }

      // Check if this is a file by looking for a filename
      if (filename != null) {
        if (name == 'audio_file') {
          if (verboseLoggingEnabled) {
            print(
                'DEBUG CREATE JOB: Found audio_file upload with filename: $filename');
          }
          hasAudioFile = true;
          // Just consume the bytes - in a real implementation we might save the file
          await part
              .drain(); // MimeMultipart extends Stream<List<int>> so we can use drain()
        }
      } else {
        // Regular form field
        final value = await readAsString(part);
        if (verboseLoggingEnabled) {
          print('DEBUG CREATE JOB: Field $name = $value');
        }

        if (name == 'user_id') {
          userId = value;
        } else if (name == 'text') {
          text = value;
        } else if (name == 'additional_text') {
          additionalText = value;
        }
      }
    }

    // Validate required fields
    if (userId == null || userId.isEmpty) {
      throw const FormatException('Missing or empty user_id field');
    }
    if (!hasAudioFile) {
      throw const FormatException('Missing audio_file part');
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

    job_store.addJob(newJob);

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
    if (verboseLoggingEnabled) {
      print('DEBUG CREATE JOB ERROR: $e');
      print('Stack trace: $stackTrace');
    }
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
  final responseData = job_store
      .getAllJobs()
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
    foundJob = job_store.findJobById(jobId);
  } on StateError {
    // Thrown by firstWhere if no element is found
    foundJob = null;
  }

  if (foundJob == null) {
    return job_store.createNotFoundResponse('Job', jobId);
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
    // Include display fields, they might be null but should be present
    'display_title': foundJob['display_title'],
    'display_text': foundJob['display_text'],
    // Exclude other potential fields like transcript
  };

  return Response.ok(
    jsonEncode({'data': responseData}),
    headers: {'content-type': 'application/json'},
  );
}

// Get Job Documents handler logic
Future<Response> _getJobDocumentsHandler(Request request, String jobId) async {
  // Authentication and API key are already handled by middleware

  // Find the job by ID first
  Map<String, dynamic>? foundJob;
  try {
    foundJob = job_store.findJobById(jobId);
  } on StateError {
    foundJob = null;
  }

  if (foundJob == null) {
    return job_store.createNotFoundResponse('Job', jobId);
  }

  // Job found, return mock document data
  // URLs should be relative to the API base known by the client.
  final mockDocuments = [
    {
      'id': 'doc-${_uuid.v4()}',
      'type': 'transcript',
      // Return a relative path from the API base
      'url': '/$_versionedApiPath/documents/doc-transcript-$jobId.txt'
    },
    {
      'id': 'doc-${_uuid.v4()}',
      'type': 'summary',
      // Return a relative path from the API base
      'url': '/$_versionedApiPath/documents/doc-summary-$jobId.pdf'
    }
  ];

  return Response.ok(
    jsonEncode({'data': mockDocuments}),
    headers: {'content-type': 'application/json'},
  );
}

// Middleware for handling authorization (both API key and potentially JWT later)
// Apply API Key check globally here, simplifying the pipeline
Middleware _authMiddleware() {
  return (innerHandler) {
    return (request) {
      final path = request.requestedUri.path;

      // Skip API key check for health and ALL debug endpoints
      if (path == '/$_versionedApiPath/health' ||
          path.startsWith('/$_versionedApiPath/debug/')) {
        if (verboseLoggingEnabled) {
          print(
              'DEBUG AUTH MIDDLEWARE: Skipping auth for health or debug endpoint: $path');
        }
        return innerHandler(request);
      }

      // All other endpoints require authentication
      if (verboseLoggingEnabled) {
        print('DEBUG AUTH MIDDLEWARE: Checking API key for path: $path');
      }

      final apiKey = request.headers['x-api-key'];
      if (apiKey != _expectedApiKey) {
        if (verboseLoggingEnabled) {
          print(
              'DEBUG AUTH MIDDLEWARE: API Key validation FAILED. Expected \'$_expectedApiKey\', got \'$apiKey\'');
        }
        return Response(
          HttpStatus.unauthorized, // 401
          body: jsonEncode({'error': 'Missing or invalid X-API-Key header'}),
          headers: {'content-type': 'application/json'},
        );
      }

      if (verboseLoggingEnabled) {
        print('DEBUG AUTH MIDDLEWARE: API Key validation successful.');
      }

      // If API key is valid, proceed to the next handler
      return innerHandler(request);
    };
  };
}

// Update Job handler logic
Future<Response> _updateJobHandler(Request request, String jobId) async {
  if (verboseLoggingEnabled) {
    print(
        'DEBUG UPDATE JOB: Handler called for jobId: $jobId, Path: ${request.requestedUri.path}, Content-Type: ${request.headers['content-type']}');
  }

  // Content-Type check
  if (request.headers['content-type']
          ?.toLowerCase()
          .startsWith('application/json') !=
      true) {
    if (verboseLoggingEnabled) {
      print(
          'DEBUG UPDATE JOB: Invalid Content-Type: ${request.headers['content-type']}');
    }
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode(
          {'error': 'Expected Content-Type starting with application/json'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // Find the job by ID
  int jobIndex = job_store.findJobIndexById(jobId);

  if (jobIndex == -1) {
    return job_store.createNotFoundResponse('Job', jobId);
  }

  // Parse the update payload
  Map<String, dynamic> updatePayload;
  try {
    final body = await request.readAsString();
    if (verboseLoggingEnabled) {
      print('DEBUG UPDATE JOB: Received update payload: $body');
    }
    updatePayload = jsonDecode(body) as Map<String, dynamic>;
  } catch (e) {
    if (verboseLoggingEnabled) {
      print('DEBUG UPDATE JOB: Error parsing update payload: $e');
    }
    return Response(
      HttpStatus.badRequest,
      body: jsonEncode({'error': 'Malformed JSON payload: $e'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // Apply updates
  final existingJob = job_store.findJobById(jobId);
  final updatedJob = Map<String, dynamic>.from(existingJob);

  updatePayload.forEach((key, value) {
    // Only update keys that exist in the job model (or add if necessary based on real API)
    // Simple approach: update if key exists or is a known field
    final knownKeys = [
      'job_status',
      'error_code',
      'error_message',
      'text',
      'additional_text',
      'display_title',
      'display_text',
      'transcript'
    ];
    if (updatedJob.containsKey(key) || knownKeys.contains(key)) {
      updatedJob[key] = value;
      if (verboseLoggingEnabled) {
        print('DEBUG UPDATE JOB: Updated $key to $value');
      }
    }
  });

  // Update the timestamp
  updatedJob['updated_at'] = DateTime.now().toUtc().toIso8601String();

  // Replace the old job with the updated one
  job_store.updateJobByIndex(jobIndex, updatedJob);

  if (verboseLoggingEnabled) {
    print('DEBUG UPDATE JOB: Job updated successfully. New state: $updatedJob');
  }

  // Return the full updated job object
  return Response.ok(
    jsonEncode({'data': updatedJob}),
    headers: {'content-type': 'application/json'},
  );
}

// Job deletion handler
Future<Response> _deleteJobHandler(Request request, String jobId) async {
  if (verboseLoggingEnabled) {
    print('DEBUG: Delete job handler called for $jobId');
  }

  // --- IMPORTANT: Cancel progression timer before deleting job data ---
  // Call the helper function from the imported file
  cancelProgressionTimerForJob(jobId); // Call the cancellation function

  try {
    // Use JobStore
    final removed = job_store.removeJob(jobId);

    if (!removed) {
      // Although cleanup timer was called, the job might have already been deleted
      // by another request, or maybe never existed. Return 404.
      return job_store.createNotFoundResponse('Job', jobId);
    }

    if (verboseLoggingEnabled) {
      print('DEBUG: Deleted job with ID: $jobId');
    }
    return Response(HttpStatus.noContent); // 204
  } catch (e, stackTrace) {
    if (verboseLoggingEnabled) {
      print('DEBUG: Error deleting job: $e');
      print('Stack trace: $stackTrace');
    }
    return Response(
      HttpStatus.internalServerError, // 500
      body: jsonEncode({'error': 'Failed to delete job: ${e.toString()}'}),
      headers: {'content-type': 'application/json'},
    );
  }
}

// Main function now just adds the router, as middleware is applied per-route or globally
void main(List<String> args) async {
  // Define argument parser
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8080')
    ..addFlag('verbose',
        abbr: 'v', defaultsTo: false, help: 'Enable verbose logging');
  final argResults = parser.parse(args);
  final port = int.tryParse(argResults['port'] as String) ?? 8080;
  // Assign the parsed flag to the global config variable
  verboseLoggingEnabled = argResults['verbose'] as bool;

  try {
    // Simplified Main server pipeline
    final handler = const Pipeline()
        .addMiddleware(logRequests()) // Log requests first
        .addMiddleware(_debugMiddleware()) // Debug details
        // Apply Auth checks (which now include API key) globally
        .addMiddleware(_authMiddleware())
        // Add the router handler at the end to handle all matched routes
        .addHandler(_router.call);

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
