import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

// Assume server runs on localhost:8080 (we'll configure this later)
final String baseUrl = 'http://localhost:8080';
// As per spec, a fixed API key is needed
final String testApiKey = 'test-api-key';

void main() {
  // TODO: Add setupAll and tearDownAll to start/stop the server for tests

  group('POST /api/v1/auth/login', () {
    test('should return JWT tokens on successful login', () async {
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
      // We expect this to fail initially as the server isn't running/implemented
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));

      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse, containsPair('access_token', isA<String>()));
      expect(jsonResponse, containsPair('refresh_token', isA<String>()));
      expect(jsonResponse, containsPair('user_id', isA<String>()));
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
      final body = 'this is not json'; // Malformed body

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 400);
    });

    // We could add more tests: missing email/password, wrong content-type etc.
    // But let's keep it minimal for now.
  });

  group('POST /api/v1/auth/refresh-session', () {
    test('should return new JWT tokens on successful refresh', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': testApiKey,
      };
      final body = jsonEncode({
        'refresh_token': 'some-valid-refresh-token',
      });

      // Act
      final response = await http.post(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));

      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse, containsPair('access_token', isA<String>()));
      expect(jsonResponse, containsPair('refresh_token', isA<String>()));
      expect(
          jsonResponse,
          isNot(
              containsPair('user_id', anything))); // User ID not expected here
    });

    test('should return 401 Unauthorized if X-API-Key is missing', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/auth/refresh-session');
      final headers = {
        'Content-Type': 'application/json',
        // No X-API-Key
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
        'X-API-Key': testApiKey,
      };
      final body = 'this is not json'; // Malformed body

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
        'X-API-Key': testApiKey,
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
}
