import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'test_helpers.dart';

const String validApiKey = 'test-api-key';
const String testUserId =
    'user-from-path-123'; // For the old /users/{userId} tests
const _testMockJwtSecret = 'mock-secret-key';
const _jwtUserId = 'fake-user-id-123';

String _generateTestJwt({
  Duration expiresIn = const Duration(minutes: 5),
  String secret = _testMockJwtSecret,
  String subject = _jwtUserId,
  String issuer = 'test-issuer',
}) {
  final jwt = JWT(
    {'sub': subject},
    issuer: issuer,
    jwtId: DateTime.now().millisecondsSinceEpoch.toString(),
  );
  return jwt.sign(SecretKey(secret), expiresIn: expiresIn);
}

void main() {
  late Process? serverProcess;
  late int port;
  late String baseUrl;
  late http.Client client;

  setUpAll(() async {
    final serverInfo = await startMockServer('UserTests');
    serverProcess = serverInfo.$1;
    port = serverInfo.$2;
    baseUrl = 'http://localhost:$port/api/v1';
    client = http.Client();
    if (serverProcess == null) {
      throw Exception('Failed to start mock server process.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });

  tearDownAll(() async {
    client.close();
    if (serverProcess != null) {
      await stopMockServer('UserTests', serverProcess!);
    }
  });

  group('GET /api/v1/users/{userId} (deprecated)', () {
    test(
        'should return 404 Not Found for specific user ID as handler will be removed',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/$testUserId'),
        headers: {'x-api-key': validApiKey},
      );
      // EXPECT 404 because the handler for /users/<userId> will be removed.
      expect(response.statusCode, equals(HttpStatus.notFound));
    });

    test(
        'should return 401 Unauthorized if x-api-key header is missing (middleware check)',
        () async {
      final response = await client.get(
        Uri.parse(
            '$baseUrl/users/$testUserId'), // Path doesn't matter as much as API key
      );
      // EXPECT 401 from API Key middleware, which runs before routing.
      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test(
        'should return 404 Not Found for any other user ID path (general non-me path)',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/some-other-id'),
        headers: {'x-api-key': validApiKey},
      );
      // EXPECT 404 as no specific handler will match /users/some-other-id.
      expect(response.statusCode, equals(HttpStatus.notFound));
    });
  }); // End group /api/v1/users/{userId} (deprecated)

  group('GET /api/v1/users/profile (deprecated)', () {
    late String validToken;

    setUp(() {
      validToken = _generateTestJwt();
    });

    test(
        'should return 404 Not Found as endpoint is removed (even with valid token and API key)',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: {
          'x-api-key': validApiKey,
          'Authorization': 'Bearer $validToken',
        },
      );
      // EXPECT 404 because the handler for /users/profile will be removed.
      expect(response.statusCode, equals(HttpStatus.notFound));
    });

    test(
        'should return 404 Not Found as endpoint is removed (API key present, no auth header)',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: {'x-api-key': validApiKey},
      );
      // EXPECT 404, API key middleware passes, but no route found.
      expect(response.statusCode, equals(HttpStatus.notFound));
    });

    test(
        'should return 401 Unauthorized if x-api-key is missing (middleware check before 404)',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: {
          // No x-api-key
          'Authorization': 'Bearer $validToken',
        },
      );
      // EXPECT 401 from API Key middleware.
      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });
  }); // End group /api/v1/users/profile (deprecated)

  group('GET /api/v1/users/me (new)', () {
    late String validToken;
    late String expiredToken;
    late String wrongSecretToken;
    late String tokenWithEmptySubject; // For testing invalid 'sub' claim

    setUp(() {
      validToken = _generateTestJwt();
      expiredToken = _generateTestJwt(expiresIn: const Duration(seconds: -10));
      wrongSecretToken = _generateTestJwt(secret: 'wrong-secret-for-signing');
      tokenWithEmptySubject = _generateTestJwt(subject: '');
    });

    test(
        'should return 200 OK and user data for valid API key and Bearer token',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'x-api-key': validApiKey,
          'Authorization': 'Bearer $validToken',
        },
      );

      expect(response.statusCode, equals(HttpStatus.ok), reason: response.body);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['id'], equals(_jwtUserId));
      expect(body['name'],
          equals('Mock User ($_jwtUserId)')); // Matches old /profile structure
      expect(body['email'], equals('mock.user.$_jwtUserId@example.com'));
      expect(body['settings'], isA<Map>());
      expect(body['settings']['theme'], equals('dark'));
      expect(body['settings']['notifications_enabled'], isTrue);
    });

    test(
        'should return 401 Unauthorized if x-api-key header is missing (token present)',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          // 'x-api-key': validApiKey, // Intentionally missing
          'Authorization': 'Bearer $validToken',
        },
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('Missing or invalid X-API-Key'));
    });

    test(
        'should return 401 Unauthorized if Authorization header is missing (API key present)',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'x-api-key': validApiKey,
          // 'Authorization': 'Bearer $validToken', // Intentionally missing
        },
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('Missing or invalid Bearer token'));
    });

    test(
        'should return 401 Unauthorized if Authorization header is not Bearer type',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'x-api-key': validApiKey,
          'Authorization': 'NonBearerScheme $validToken',
        },
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('Missing or invalid Bearer token'));
    });

    test('should return 401 Unauthorized if Bearer token is malformed',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'x-api-key': validApiKey,
          'Authorization': 'Bearer this.is.not.a.jwt',
        },
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('Invalid token')); // From JWT lib
    });

    test('should return 401 Unauthorized if Bearer token is expired', () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'x-api-key': validApiKey,
          'Authorization': 'Bearer $expiredToken',
        },
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(
          body['error'], equals('Token expired')); // Exact message from JWT lib
    });

    test(
        'should return 401 Unauthorized if Bearer token is signed with wrong secret',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'x-api-key': validApiKey,
          'Authorization': 'Bearer $wrongSecretToken',
        },
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('Invalid token')); // From JWT lib
    });

    test(
        'should return 401 Unauthorized if Bearer token has empty/invalid \'sub\' claim',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'x-api-key': validApiKey,
          'Authorization': 'Bearer $tokenWithEmptySubject',
        },
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'],
          contains('Invalid token claims')); // Custom error from handler
    });

    test('should return 401 Unauthorized when request has no headers at all',
        () async {
      final response = await client.get(
        Uri.parse('$baseUrl/users/me'),
        // No headers provided at all
      );
      expect(response.statusCode, equals(HttpStatus.unauthorized));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('Missing or invalid X-API-Key'));
    });
  }); // End group /api/v1/users/me (new)
}
