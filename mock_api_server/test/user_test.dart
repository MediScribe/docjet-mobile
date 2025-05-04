import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart'; // Keep JWT

import 'test_helpers.dart'; // This should contain start/stop helpers and validApiKey

// Restore likely global constants based on linter errors
const String validApiKey =
    'test-api-key'; // Assuming this value or it's in test_helpers
const String testUserId = 'user-from-path-123'; // For the /users/{userId} tests

// Shared secret for JWT generation/verification in tests
const _testMockJwtSecret = 'mock-secret-key';
// User ID to embed in the JWT 'sub' claim for tests
const _jwtUserId = 'fake-user-id-123';

// Helper to generate JWTs for testing
String _generateTestJwt({
  Duration expiresIn = const Duration(minutes: 5),
  String secret = _testMockJwtSecret,
  String subject = _jwtUserId,
}) {
  final jwt = JWT(
    {'sub': subject},
    issuer: 'test-issuer',
    jwtId: DateTime.now().millisecondsSinceEpoch.toString(),
  );
  return jwt.sign(SecretKey(secret), expiresIn: expiresIn);
}

void main() {
  late Process? serverProcess; // Handle nullable Process
  late int port;
  late String baseUrl;
  late http.Client client;

  setUpAll(() async {
    final serverInfo = await startMockServer('UserTests');
    serverProcess = serverInfo.$1;
    port = serverInfo.$2;
    baseUrl = 'http://localhost:$port/api/v1';
    client = http.Client();
    // Add a null check for safety, though startMockServer should ideally throw
    // if it fails to start the process.
    if (serverProcess == null) {
      throw Exception('Failed to start mock server process.');
    }
    // Simple delay to allow server startup
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });

  tearDownAll(() async {
    client.close();
    // Add null check before trying to stop
    if (serverProcess != null) {
      await stopMockServer('UserTests', serverProcess!);
    }
  });

  group('GET /api/v1/users/{userId}', () {
    test('should return user data for valid ID and API key', () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/$testUserId'),
        headers: {'x-api-key': validApiKey},
      );
      expect(response.statusCode, equals(HttpStatus.ok));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['id'], equals(testUserId));
      expect(body['email'], contains('@example.com'));
    });

    test('should return 401 Unauthorized if x-api-key header is missing',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/$testUserId'),
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test('should return 404 Not Found for non-existent user ID', () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/non-existent-user'),
        headers: {'x-api-key': validApiKey},
      );
      expect(response.statusCode, equals(HttpStatus.notFound));
    });

    // Ensure other /users/{userId} tests also ONLY use x-api-key, no Auth header
  }); // End group /api/v1/users/{userId}

  // --- NEW Tests for GET /api/v1/users/profile ---
  group('GET /api/v1/users/profile', () {
    late String validToken;
    late String expiredToken;
    late String wrongSecretToken;

    setUp(() {
      validToken = _generateTestJwt();
      expiredToken = _generateTestJwt(expiresIn: const Duration(seconds: -10));
      wrongSecretToken = _generateTestJwt(secret: 'wrong-secret');
    });

    // These tests correctly use 'Authorization': 'Bearer ...' and lowercase x-api-key
    test('should return 401 Unauthorized if Authorization header is missing',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: {'x-api-key': validApiKey},
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test('should return 401 Unauthorized if Authorization header is not Bearer',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: {
          'x-api-key': validApiKey,
          'Authorization': 'Invalid $validToken',
        },
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test('should return 401 Unauthorized if token is malformed', () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: {
          'x-api-key': validApiKey,
          'Authorization': 'Bearer malformed-token-string',
        },
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test('should return 401 Unauthorized if token is signed with wrong secret',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: {
          'x-api-key': validApiKey,
          'Authorization': 'Bearer $wrongSecretToken',
        },
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test('should return 401 Unauthorized if token is expired', () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: {
          'x-api-key': validApiKey,
          'Authorization': 'Bearer $expiredToken',
        },
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test(
        'should return 200 OK and user data if valid, non-expired token is provided',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: {
          'x-api-key': validApiKey,
          'Authorization': 'Bearer $validToken',
        },
      );

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      // Verify the ID from the token's subject claim is used
      expect(body['id'], equals(_jwtUserId));
      expect(body['email'],
          contains('@example.com')); // Check other standard fields
    });
  }); // End group /api/v1/users/profile
}
