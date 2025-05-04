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
        'X-API-Key': testApiKey,
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
        'X-API-Key': testApiKey,
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
        'X-API-Key': testApiKey,
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
        'X-API-Key': testApiKey,
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
        'X-API-Key': testApiKey,
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

    test('should return 401 Unauthorized if X-API-Key is missing', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/login');
      final headers = {
        // Note: No X-API-Key
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
        'X-API-Key': testApiKey,
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
        'X-API-Key': testApiKey,
      };
      // The actual token value doesn't matter for the mock currently
      final body = jsonEncode({'refresh_token': 'any-old-refresh-token'});

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));
      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse, containsPair('access_token', isA<String>()));
      expect(jsonResponse, containsPair('refresh_token', isA<String>()));
      // The mock refresh doesn't return user_id
      expect(jsonResponse, isNot(contains('user_id')));
    });

    test('new access_token is a valid JWT', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': testApiKey,
      };
      final body = jsonEncode({'refresh_token': 'any-old-refresh-token'});

      // Act
      final response = await http.post(url, headers: headers, body: body);
      final jsonResponse = jsonDecode(response.body);
      final accessToken = jsonResponse['access_token'] as String;

      // Assert
      expect(response.statusCode, 200);
      JWT? jwt;
      dynamic decodeError;
      try {
        jwt = JWT.decode(accessToken);
      } catch (e) {
        decodeError = e;
      }
      expect(decodeError, isNull,
          reason: 'Access token should be decodable as a JWT');
      expect(jwt, isNotNull);
      expect(jwt?.payload, isA<Map>());
    });

    test('new refresh_token is a valid JWT', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': testApiKey,
      };
      final body = jsonEncode({'refresh_token': 'any-old-refresh-token'});

      // Act
      final response = await http.post(url, headers: headers, body: body);
      final jsonResponse = jsonDecode(response.body);
      final refreshToken = jsonResponse['refresh_token'] as String;

      // Assert
      expect(response.statusCode, 200);
      JWT? jwt;
      dynamic decodeError;
      try {
        jwt = JWT.decode(refreshToken);
      } catch (e) {
        decodeError = e;
      }
      expect(decodeError, isNull,
          reason: 'Refresh token should be decodable as a JWT');
      expect(jwt, isNotNull);
      expect(jwt?.payload, isA<Map>());
    });

    test('new tokens have future expiry dates', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': testApiKey,
      };
      final body = jsonEncode({'refresh_token': 'any-old-refresh-token'});
      final requestTimeSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Act
      final response = await http.post(url, headers: headers, body: body);
      final jsonResponse = jsonDecode(response.body);
      final accessToken = jsonResponse['access_token'] as String;
      final refreshToken = jsonResponse['refresh_token'] as String;

      // Assert
      expect(response.statusCode, 200);
      final accessJwt = JWT.decode(accessToken);
      final refreshJwt = JWT.decode(refreshToken);
      final accessPayload = accessJwt.payload as Map<String, dynamic>;
      final refreshPayload = refreshJwt.payload as Map<String, dynamic>;

      // Check access token expiry
      expect(accessPayload['exp'], isA<int>());
      expect(accessPayload['iat'], isA<int>());
      expect(accessPayload['sub'], isA<String>()); // Check for subject claim
      expect(accessPayload['exp'], greaterThan(requestTimeSeconds),
          reason: 'New access token expiry should be in the future');
      expect(accessPayload['exp'],
          lessThan(requestTimeSeconds + 60), // Short expiry
          reason: 'New access token expiry should be reasonably short');

      // Check refresh token expiry
      expect(refreshPayload['exp'], isA<int>());
      expect(refreshPayload['iat'], isA<int>());
      expect(refreshPayload['sub'], isA<String>()); // Check for subject claim
      expect(refreshPayload['exp'],
          greaterThan(requestTimeSeconds + 60), // Longer expiry
          reason:
              'New refresh token expiry should be significantly in the future');
    });

    test('should return 401 Unauthorized if X-API-Key is missing', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        // Note: No X-API-Key
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({'refresh_token': 'any-old-refresh-token'});

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 401);
    });

    test('should return 400 Bad Request if refresh_token field is missing',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': testApiKey,
      };
      // Missing 'refresh_token' field
      final body = jsonEncode({'some_other_field': 'value'});

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 400);
      expect(response.headers['content-type'], contains('application/json'));
      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse,
          containsPair('error', contains('Missing refresh_token field')));
    });

    // Add more tests if needed, e.g., malformed JSON body
  });

  group('GET /api/v1/users/profile', () {
    test('should return user profile on successful GET', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/users/profile');
      final headers = {
        'X-API-Key': testApiKey,
        'Authorization': 'Bearer $dummyJwt' // Assuming auth is needed
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));
      final body = jsonDecode(response.body);
      expect(body, isA<Map<String, dynamic>>());
      expect(body['id'], equals('fake-user-id-123')); // Keep ID consistent
      expect(body['name'], isNotNull);
      expect(body['email'], isNotNull);
      expect(body['settings'], isA<Map>()); // Example extra data
    });

    test('should return 401 Unauthorized if X-API-Key is missing', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/users/profile');
      final headers = {
        // No X-API-Key
        'Authorization': 'Bearer $dummyJwt'
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
        'X-API-Key': testApiKey
        // No Authorization header
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 401);
    });
  });
}
