import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'test_helpers.dart'; // Import helper functions, including MockApiServer

// Base URL for the mock server
late String baseUrl;
// Valid API key
const String validApiKey = 'test-api-key';
// Valid Auth Token
const String validAuthToken = 'fake-bearer-token';
// User ID to use in tests
const String testUserId = 'user-from-path-123';

void main() {
  late Process serverProcess;
  int port = 0; // Will be assigned dynamically

  // Start the server before tests run
  setUpAll(() async {
    // Use the helper function, providing a name for logging
    final serverInfo = await startMockServer('UserTests');
    serverProcess = serverInfo.$1!; // Access the Process object
    port = serverInfo.$2; // Access the port number
    baseUrl = 'http://localhost:$port/api/v1'; // Use the versioned path
  });

  // Stop the server after tests complete
  tearDownAll(() async {
    await stopMockServer('UserTests', serverProcess);
  });

  group('User Endpoints', () {
    test('GET /users/{userId} - Success', () async {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$testUserId'),
        headers: {
          'Authorization': 'Bearer $validAuthToken',
          'x-api-key': validApiKey,
        },
      );

      expect(response.statusCode, equals(HttpStatus.ok)); // 200
      expect(response.headers['content-type'], contains('application/json'));

      final decodedBody = jsonDecode(response.body) as Map<String, dynamic>;
      expect(decodedBody, isA<Map<String, dynamic>>());
      expect(
          decodedBody['id'], equals(testUserId)); // Crucial: ID must match path
      expect(decodedBody['name'], isA<String>());
      expect(decodedBody['email'], isA<String>());

      // Verify name and email contain the userId as expected
      expect(decodedBody['name'], contains(testUserId),
          reason: 'Name should contain the user ID');
      expect(decodedBody['email'], contains(testUserId),
          reason: 'Email should contain the user ID');

      expect(decodedBody['settings'], isA<Map<String, dynamic>>());
    });

    test('GET /users/{userId} - Unauthorized (Missing Token)', () async {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$testUserId'),
        headers: {
          // Missing Authorization
          'x-api-key': validApiKey,
        },
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized)); // 401
    });

    test('GET /users/{userId} - Unauthorized (Missing API Key)', () async {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$testUserId'),
        headers: {
          'Authorization': 'Bearer $validAuthToken',
          // Missing x-api-key
        },
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized)); // 401
    });

    test('GET /users/{userId} - Bad Request (Empty ID)', () async {
      final response = await http.get(
        Uri.parse('$baseUrl/users/'), // Empty userId
        headers: {
          'Authorization': 'Bearer $validAuthToken',
          'x-api-key': validApiKey,
        },
      );

      // Shelf routing might return 404 if path doesn't match pattern, or 400 if our handler processes it
      // Either is acceptable, but we check for both possibilities
      expect(response.statusCode,
          anyOf([equals(HttpStatus.notFound), equals(HttpStatus.badRequest)]),
          reason:
              'Should return 404 (Not Found) or 400 (Bad Request) for empty userId');
    });

    // Future enhancement: Move the GET /users/profile test from auth_test.dart to consolidate user endpoint testing
  });
}
