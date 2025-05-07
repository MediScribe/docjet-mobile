// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Added for HttpStatus
import 'package:shelf/shelf.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:mock_api_server/src/config.dart'; // For verboseLoggingEnabled
import 'package:mock_api_server/src/core/constants.dart'; // Corrected path for JWT constants

// Login handler logic
Future<Response> loginHandler(Request request) async {
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
        'exp': now.add(accessTokenDuration).millisecondsSinceEpoch ~/ 1000,
        // Add other claims if needed, e.g., roles
      },
      issuer: 'mock-api-server',
    );
    final accessToken = accessJwt.sign(SecretKey(mockJwtSecret));

    // Create Refresh Token
    final refreshJwt = JWT(
      {
        'sub': userId,
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': now.add(refreshTokenDuration).millisecondsSinceEpoch ~/ 1000,
        // Optionally add a unique ID (jti) for refresh token revocation (not implemented here)
      },
      issuer: 'mock-api-server',
    );
    final refreshToken = refreshJwt.sign(SecretKey(mockJwtSecret));

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
Future<Response> refreshHandler(Request request) async {
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
    if (verboseLoggingEnabled) {
      print('DEBUG: Error processing refresh request body: $e');
    }
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
      'exp': nowEpochSeconds + accessTokenDuration.inSeconds,
      // Add any other claims if needed for testing
    },
    // Use a standard JWT header if needed, default is HS256
    // header: {'alg': 'HS256', 'typ': 'JWT'},
  );
  final newAccessToken = accessJwt.sign(SecretKey(mockJwtSecret));

  // Create Refresh Token
  final refreshJwt = JWT(
    {
      'sub': userId,
      'iat': nowEpochSeconds,
      'exp': nowEpochSeconds + refreshTokenDuration.inSeconds,
    },
  );
  final newRefreshToken = refreshJwt.sign(SecretKey(mockJwtSecret));

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

// Get User Me handler logic
Future<Response> getUserMeHandler(Request request) async {
  if (verboseLoggingEnabled) print('DEBUG: Get User Me handler called');

  // --- JWT Validation ---
  try {
    final authorizationHeader = request.headers['authorization'];
    if (authorizationHeader == null ||
        !authorizationHeader.startsWith('Bearer ')) {
      if (verboseLoggingEnabled) {
        print('DEBUG: Missing or invalid Bearer token header.');
      }
      return Response(HttpStatus.unauthorized,
          body: jsonEncode({'error': 'Missing or invalid Bearer token'}),
          headers: {'content-type': 'application/json'});
    }

    final token =
        authorizationHeader.substring(7); // Extract token after "Bearer "

    // Verify the token
    final jwt = JWT.verify(token, SecretKey(mockJwtSecret));
    final userId = jwt.payload['sub'] as String?;

    if (userId == null || userId.isEmpty) {
      if (verboseLoggingEnabled) {
        print("DEBUG: Token is missing or has empty 'sub' (user ID) claim.");
      }
      return Response(HttpStatus.unauthorized,
          body: jsonEncode({
            'error': 'Invalid token claims'
          }), // Consistent error message with tests
          headers: {'content-type': 'application/json'});
    }

    if (verboseLoggingEnabled) {
      print('DEBUG: Token validated for user: $userId');
    }

    // --- Generate Response using validated User ID (mirroring old /profile structure) ---
    final responseBody = jsonEncode({
      'id': userId, // Use the ID from the token!
      'name':
          'Mock User ($userId)', // Consistent with old /profile test expectations
      'email': 'mock.user.$userId@example.com', // Consistent
      'settings': {
        'theme': 'dark', // Consistent
        'notifications_enabled': true, // Consistent
      },
    });

    return Response.ok(
      responseBody,
      headers: {'content-type': 'application/json'},
    );
  } on JWTExpiredException {
    if (verboseLoggingEnabled) print('DEBUG: JWT expired.');
    return Response(HttpStatus.unauthorized,
        body: jsonEncode({'error': 'Token expired'}),
        headers: {'content-type': 'application/json'});
  } on JWTException catch (ex) {
    // Catches other JWT errors (signature, format)
    if (verboseLoggingEnabled) {
      print('DEBUG: JWT validation error: ${ex.message}');
    }
    return Response(HttpStatus.unauthorized,
        body: jsonEncode({'error': 'Invalid token: ${ex.message}'}),
        headers: {'content-type': 'application/json'});
  } catch (e) {
    if (verboseLoggingEnabled) print('DEBUG: Unexpected error: $e');
    return Response.internalServerError(
        body: jsonEncode({'error': 'Internal server error'}),
        headers: {'content-type': 'application/json'});
  }
}
