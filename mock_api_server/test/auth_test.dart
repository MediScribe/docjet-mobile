import 'dart:convert';
import 'dart:io'; // Added for Process

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart'; // Added for JWT verification

import 'test_helpers.dart'; // Import the helper

// No longer using a fixed baseUrl
// final String baseUrl = 'http://localhost:8080';
const String testApiKey = 'test-api-key';
const String dummyJwt = 'fake-jwt-token'; // For Authorization header

// Path to server executable (relative to mock_api_server directory)
// const String _mockServerPath = 'bin/server.dart'; // Moved to helper

// Constants
const String _mockJwtSecret = 'mock-secret-key'; // Secret used by server
const String _jwtUserId = 'fake-user-id-123'; // User ID for tests

// Helper to generate JWTs (copied from user_test.dart for simplicity)
String _generateTestJwt({
  Duration expiresIn = const Duration(minutes: 5),
  String secret = _mockJwtSecret,
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
  Process? mockServerProcess;
  int mockServerPort = 0; // Initialize port
  late String baseUrl; // Declare baseUrl, will be set in setUpAll

  setUpAll(() async {
    (mockServerProcess, mockServerPort) = await startMockServer('AuthTest');
    if (mockServerProcess == null) {
      throw Exception('Failed to start mock server for AuthTest');
    }
    baseUrl = 'http://localhost:$mockServerPort'; // Set dynamic baseUrl
  });

  tearDownAll(() async {
    await stopMockServer('AuthTest', mockServerProcess);
  });

  group('POST /api/v1/auth/login', () {
    test('should return 200 OK on successful login with expected structure',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/login');
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': testApiKey,
      };
      final body = jsonEncode({
        'email': 'test@example.com',
        'password': 'password',
      });

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));

      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse, containsPair('access_token', isA<String>()));
      expect(jsonResponse, containsPair('refresh_token', isA<String>()));
      expect(jsonResponse, containsPair('user_id', isA<String>()));
      expect(
          jsonResponse['user_id'], 'fake-user-id-123'); // Verify fixed user ID
    });

    test('login handler access_token is a valid JWT', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/login');
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': testApiKey,
      };
      final body = jsonEncode({
        'email': 'test@example.com',
        'password': 'password',
      });

      // Act
      final response = await http.post(url, headers: headers, body: body);
      final jsonResponse = jsonDecode(response.body);
      final accessToken = jsonResponse['access_token'] as String;

      // Assert
      expect(response.statusCode, 200);
      JWT? jwt;
      dynamic verifyError;
      try {
        // We can only decode here, verification needs the secret (and impl)
        jwt = JWT.decode(accessToken);
      } catch (e) {
        verifyError = e;
      }
      expect(verifyError, isNull,
          reason: 'Access token should be decodable as a JWT');
      expect(jwt, isNotNull);
      expect(jwt?.payload, isA<Map>());
    });

    test('login handler refresh_token is a valid JWT', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/login');
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': testApiKey,
      };
      final body = jsonEncode({
        'email': 'test@example.com',
        'password': 'password',
      });

      // Act
      final response = await http.post(url, headers: headers, body: body);
      final jsonResponse = jsonDecode(response.body);
      final refreshToken = jsonResponse['refresh_token'] as String;

      // Assert
      expect(response.statusCode, 200);
      JWT? jwt;
      dynamic verifyError;
      try {
        // We can only decode here, verification needs the secret (and impl)
        jwt = JWT.decode(refreshToken);
      } catch (e) {
        verifyError = e;
      }
      expect(verifyError, isNull,
          reason: 'Refresh token should be decodable as a JWT');
      expect(jwt, isNotNull);
      expect(jwt?.payload, isA<Map>());
    });

    test(
        'login handler access_token payload contains correct user_id and future expiry',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/login');
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': testApiKey,
      };
      final body = jsonEncode({
        'email': 'test@example.com',
        'password': 'password',
      });
      final requestTimeSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Act
      final response = await http.post(url, headers: headers, body: body);
      final jsonResponse = jsonDecode(response.body);
      final accessToken = jsonResponse['access_token'] as String;

      // Assert
      expect(response.statusCode, 200);
      final jwt = JWT.decode(accessToken);
      final payload = jwt.payload as Map<String, dynamic>;
      expect(payload['sub'], 'fake-user-id-123');
      expect(payload['exp'], isA<int>());
      expect(payload['iat'], isA<int>());
      expect(payload['exp'], greaterThan(requestTimeSeconds),
          reason: 'Expiry should be in the future');
      expect(payload['exp'], lessThan(requestTimeSeconds + 60),
          reason:
              'Expiry should be reasonably short (e.g., < 1 min)'); // Generous upper bound for now
    });

    test(
        'login handler refresh_token payload contains correct user_id and longer future expiry',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/login');
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': testApiKey,
      };
      final body = jsonEncode({
        'email': 'test@example.com',
        'password': 'password',
      });
      final requestTimeSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Act
      final response = await http.post(url, headers: headers, body: body);
      final jsonResponse = jsonDecode(response.body);
      final refreshToken = jsonResponse['refresh_token'] as String;

      // Assert
      expect(response.statusCode, 200);
      final jwt = JWT.decode(refreshToken);
      final payload = jwt.payload as Map<String, dynamic>;
      expect(payload['sub'], 'fake-user-id-123');
      expect(payload['exp'], isA<int>());
      expect(payload['iat'], isA<int>());
      expect(
          payload['exp'],
          greaterThan(
              requestTimeSeconds + 60), // Expect longer than access token
          reason: 'Refresh expiry should be significantly in the future');
    });

    test('should return 401 Unauthorized if x-api-key is missing', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/login');
      final headers = {
        // Note: No x-api-key
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({
        'email': 'test@example.com',
        'password': 'password',
      });

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(
        response.statusCode,
        401,
      ); // Or 403 Forbidden, depending on how we implement
    });

    test('should return 400 Bad Request if body is malformed', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/login');
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': testApiKey,
      };
      const body = 'this is not json'; // Malformed body

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 400);
    });

    // We could add more tests: missing email/password, wrong content-type etc.
    // But let's keep it minimal for now.
  });

  group('POST /api/v1/auth/refresh-session', () {
    test('should return 200 OK and new tokens on valid request structure',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': testApiKey,
      };
      final body = jsonEncode({
        'refresh_token': 'some-valid-refresh-token',
      });

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, equals(HttpStatus.ok));
      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      expect(jsonResponse, containsPair('access_token', isA<String>()));
      expect(jsonResponse, containsPair('refresh_token', isA<String>()));

      // --- Verify NEW JWT Claims ---
      final newAccessToken = jsonResponse['access_token'] as String;
      final newRefreshToken = jsonResponse['refresh_token'] as String;
      final nowEpochSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      try {
        final accessJwt = JWT.decode(newAccessToken);
        expect(accessJwt.subject, equals(_jwtUserId));
        expect(accessJwt.payload['iat'], lessThanOrEqualTo(nowEpochSec));
        expect(accessJwt.payload['exp'],
            greaterThan(nowEpochSec)); // Future expiry
        expect(accessJwt.payload['exp'],
            lessThanOrEqualTo(nowEpochSec + 15)); // Short expiry

        final refreshJwt = JWT.decode(newRefreshToken);
        expect(refreshJwt.subject, equals(_jwtUserId));
        expect(refreshJwt.payload['iat'], lessThanOrEqualTo(nowEpochSec));
        expect(refreshJwt.payload['exp'],
            greaterThan(nowEpochSec)); // Future expiry
        expect(refreshJwt.payload['exp'],
            greaterThan(nowEpochSec + 290)); // Long expiry (>5 min buffer)
        expect(refreshJwt.payload['exp'], lessThanOrEqualTo(nowEpochSec + 305));
      } on JWTException catch (e) {
        fail('Failed to decode NEW JWTs from refresh: $e');
      }
    });

    test('new access_token is a valid JWT', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': testApiKey,
      };
      final body = jsonEncode({
        'refresh_token': 'some-valid-refresh-token',
      });

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 200);
      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = jsonResponse['access_token'] as String;
      try {
        final jwt = JWT.decode(accessToken);
        expect(jwt, isNotNull);
        // --- Add Claim Assertions ---
        expect(jwt.subject, equals(_jwtUserId));
        expect(jwt.payload['iat'], isNotNull);
        expect(jwt.payload['iat'], isA<int>());
        expect(jwt.payload['exp'], isNotNull);
        expect(jwt.payload['exp'], isA<int>());
      } on JWTException catch (e) {
        fail('New access token is not a valid JWT: $e');
      }
    });

    test('new refresh_token is a valid JWT', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': testApiKey,
      };
      final body = jsonEncode({
        'refresh_token': 'some-valid-refresh-token',
      });

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 200);
      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final refreshToken = jsonResponse['refresh_token'] as String;
      try {
        final jwt = JWT.decode(refreshToken);
        expect(jwt, isNotNull);
        // --- Add Claim Assertions ---
        expect(jwt.subject, equals(_jwtUserId));
        expect(jwt.payload['iat'], isNotNull);
        expect(jwt.payload['iat'], isA<int>());
        expect(jwt.payload['exp'], isNotNull);
        expect(jwt.payload['exp'], isA<int>());
      } on JWTException catch (e) {
        fail('New refresh token is not a valid JWT: $e');
      }
    });

    test('new tokens have future expiry dates', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': testApiKey,
      };
      final body = jsonEncode({
        'refresh_token': 'some-valid-refresh-token',
      });

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 200);
      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = jsonResponse['access_token'] as String;
      final refreshToken = jsonResponse['refresh_token'] as String;
      final nowEpochSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      try {
        final accessJwt = JWT.decode(accessToken);
        expect(accessJwt.payload['exp'], isA<int>());
        expect(accessJwt.payload['exp'], greaterThan(nowEpochSec));
        expect(accessJwt.payload['iat'],
            lessThanOrEqualTo(nowEpochSec)); // Also check iat

        final refreshJwt = JWT.decode(refreshToken);
        expect(refreshJwt.payload['exp'], isA<int>());
        expect(refreshJwt.payload['exp'], greaterThan(nowEpochSec));
        expect(refreshJwt.payload['iat'],
            lessThanOrEqualTo(nowEpochSec)); // Also check iat
      } on JWTException catch (e) {
        fail('Failed to decode tokens or check expiry claims: $e');
      }
    });

    test('should return 401 Unauthorized if x-api-key is missing', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        'Content-Type': 'application/json',
        // No x-api-key
      };
      final body = jsonEncode({
        'refresh_token': 'some-valid-refresh-token',
      });

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 401);
    });

    test('should return 400 Bad Request if body is malformed', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': testApiKey,
      };
      const body = 'this is not json'; // Malformed body

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 400);
    });

    test('should return 400 Bad Request if refresh_token is missing', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': testApiKey,
      };
      final body = jsonEncode({
        // Missing refresh_token field
        'some_other_field': 'value'
      });

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 400);
    });
  });

  group('GET /api/v1/users/profile', () {
    test('should return user profile on successful GET with valid JWT',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/users/profile');
      final validJwt = _generateTestJwt(); // Generate a valid token
      final headers = {
        'x-api-key': testApiKey, // Use lowercase
        'Authorization': 'Bearer $validJwt' // Use the valid JWT
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 200); // Should now be 200 OK
      expect(response.headers['content-type'], contains('application/json'));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, isA<Map<String, dynamic>>());
      // Verify the ID matches the one from the JWT
      expect(body['id'], equals(_jwtUserId));
      expect(body['name'], contains(_jwtUserId)); // Name should contain the ID
      expect(
          body['email'], contains(_jwtUserId)); // Email should contain the ID
      expect(body['settings'], isA<Map>());
    });

    test('should return 401 Unauthorized if x-api-key is missing', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/users/profile');
      final validJwt =
          _generateTestJwt(); // Need a token even if API key missing
      final headers = {
        // No x-api-key
        'Authorization': 'Bearer $validJwt'
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 401);
    });

    test('should return 401 Unauthorized if Authorization header is missing',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/users/profile');
      final headers = {
        'x-api-key': testApiKey, // Use lowercase
        // No Authorization header
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 401);
    });

    // Add tests for expired/invalid JWT if desired (mirroring user_test.dart)
    test('should return 401 Unauthorized if JWT is expired', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/users/profile');
      final expiredJwt =
          _generateTestJwt(expiresIn: const Duration(seconds: -10));
      final headers = {
        'x-api-key': testApiKey,
        'Authorization': 'Bearer $expiredJwt'
      };
      // Act
      final response = await http.get(url, headers: headers);
      // Assert
      expect(response.statusCode, 401);
      expect(response.body, contains('Token expired'));
    });

    test('should return 401 Unauthorized if JWT is invalid (wrong secret)',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/users/profile');
      final invalidJwt = _generateTestJwt(secret: 'wrong-secret');
      final headers = {
        'x-api-key': testApiKey,
        'Authorization': 'Bearer $invalidJwt'
      };
      // Act
      final response = await http.get(url, headers: headers);
      // Assert
      expect(response.statusCode, 401);
      expect(response.body, contains('Invalid token')); // Or specific message
    });
  });

  // Add tests for health endpoint authentication behavior
  group('GET /api/v1/health', () {
    test('should return 200 OK without requiring x-api-key header', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/health');
      // Act - Send request without any auth headers
      final response = await http.get(url);
      // Assert
      expect(response.statusCode, equals(HttpStatus.ok));
      expect(response.body, equals('OK'));
    });

    test('should still return 200 OK when x-api-key header is provided',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/health');
      final headers = {'x-api-key': testApiKey};
      // Act
      final response = await http.get(url, headers: headers);
      // Assert
      expect(response.statusCode, equals(HttpStatus.ok));
      expect(response.body, equals('OK'));
    });
  });
}
