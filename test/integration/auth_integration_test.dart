import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/infrastructure/authentication_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_interceptor.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/login_response_dto.dart';
import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// A simple HTTP server for integration testing that specifically handles auth requests
class AuthTestServer {
  final HttpServer _server;
  HttpRequest? _lastRequest;
  final List<HttpRequest> _requests = [];
  final Logger _logger = LoggerFactory.getLogger(
    'AuthTestServer',
    level: Level.debug,
  );
  final String _tag = logTag('AuthTestServer');

  AuthTestServer._(this._server);

  /// Creates and starts a test server on a random port
  static Future<AuthTestServer> create({
    bool simulateMalformedUrl = false,
    bool simulateMissingApiKey = false,
    bool simulateNetworkError = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final logger = LoggerFactory.getLogger(
      'AuthTestServer',
      level: Level.debug,
    );
    final tag = logTag('AuthTestServer');

    logger.i('$tag Started on port ${server.port}');
    final testServer = AuthTestServer._(server);

    server.listen((request) async {
      testServer._logger.i(
        '${testServer._tag} Received ${request.method} request to: ${request.uri}',
      );
      testServer._logger.d('${testServer._tag} Headers: ${request.headers}');

      testServer._lastRequest = request;
      testServer._requests.add(request);

      // Read request body if present
      List<int> body = [];
      await for (var chunk in request) {
        body.addAll(chunk);
      }
      if (body.isNotEmpty) {
        testServer._logger.d(
          '${testServer._tag} Body: ${String.fromCharCodes(body)}',
        );
      }

      // Prepare valid auth response (matching what LoginResponseDto expects)
      final responseJson = {
        'access_token': 'test-access-token',
        'refresh_token': 'test-refresh-token',
        'user_id': 'test-user-id',
      };

      // Return proper error responses for error test cases
      if (simulateNetworkError) {
        // Close connection abruptly to simulate network error
        await request.response.detachSocket();
        return;
      } else if (simulateMalformedUrl &&
          request.uri.path.contains('/api/v1auth/login')) {
        // Malformed URL path - specifically return malformed URL error
        request.response.statusCode = 404;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'error': 'Malformed URL',
            'path': request.uri.path,
            'type': 'MALFORMED_URL_ERROR',
          }),
        );
      } else if (simulateMissingApiKey ||
          request.headers.value('x-api-key') == null) {
        // Missing API key
        request.response.statusCode = 401;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'error': 'Unauthorized - Missing API key',
            'type': 'MISSING_API_KEY',
          }),
        );
      } else {
        // Success cases
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(responseJson));
      }

      await request.response.close();
      testServer._logger.d(
        '${testServer._tag} Response sent with status ${request.response.statusCode}',
      );
    });

    return testServer;
  }

  /// The port this server is listening on
  int get port => _server.port;

  /// The most recent request received by the server
  HttpRequest? get lastRequest => _lastRequest;

  /// All requests received by this server
  List<HttpRequest> get requests => List.unmodifiable(_requests);

  /// Closes the server
  Future<void> close() async {
    _logger.i('$_tag Closing server on port ${_server.port}');
    await _server.close();
    _logger.i('$_tag Server closed');
  }
}

/// Comprehensive integration test to verify all auth fixes:
/// 1. URL formation (with proper slashes)
/// 2. API key header injection
/// 3. Proper Dio instance injection
/// 4. Enhanced error handling with diagnostics
void main() {
  // Setup logging
  final logger = LoggerFactory.getLogger(
    'AuthIntegrationTest',
    level: Level.debug,
  );
  final tag = logTag('AuthIntegrationTest');

  group('Auth Integration Tests - Complete Verification', () {
    late AuthTestServer server;
    late GetIt getIt;
    late AuthenticationApiClient authApiClient;

    setUp(() async {
      logger.i('$tag Setting up test');

      // Create test server to capture requests
      logger.d('$tag Creating test server');
      server = await AuthTestServer.create();
      logger.i('$tag Test server running on port ${server.port}');

      // Reset and setup minimal DI container
      getIt = GetIt.instance;
      await getIt.reset();
      logger.d('$tag DI container reset');

      // Setup app config with test server URL
      final testHost = 'localhost:${server.port}';
      logger.d('$tag Registering AppConfig with host: $testHost');
      getIt.registerSingleton<AppConfig>(
        AppConfig.test(apiDomain: testHost, apiKey: 'test-api-key'),
      );
    });

    tearDown(() async {
      logger.i('$tag Tearing down test');
      // Close server and reset DI
      await server.close();
      await getIt.reset();
      logger.i('$tag Test teardown complete');
    });

    test('should correctly form URL with proper slashes', () async {
      logger.i('$tag Testing URL formation');

      // Setup proper DI for test
      _setupProperDI(getIt, server.port);
      authApiClient = getIt<AuthenticationApiClient>();

      // Execute login request to check URL formation
      final result = await authApiClient.login('test@example.com', 'password');

      // Verify it succeeded (server returns valid response)
      expect(result, isA<LoginResponseDto>());
      expect(result.accessToken, 'test-access-token');

      // Verify request
      final request = server.lastRequest;
      expect(request, isNotNull, reason: 'No request captured');

      if (request != null) {
        // Verify URL path is correctly formed with proper slashes
        expect(
          request.uri.path,
          equals('/api/v1/auth/login'),
          reason: 'Path should be properly formatted with correct slashes',
        );

        // Verify API key is present in headers
        expect(
          request.headers.value('x-api-key'),
          equals('test-api-key'),
          reason: 'API key header should be present and correct',
        );
      }
    });

    test('should provide detailed error for missing API key', () async {
      logger.i('$tag Testing missing API key error handling');

      // Recreate server to simulate missing API key error
      await server.close();
      server = await AuthTestServer.create(simulateMissingApiKey: true);

      // Setup DI with missing API key
      _setupDIWithMissingApiKey(getIt, server.port);
      authApiClient = getIt<AuthenticationApiClient>();

      // Execute login request (should fail with missing API key error)
      try {
        await authApiClient.login('test@example.com', 'password');
        fail('Login should have failed with missing API key error');
      } catch (e) {
        logger.d('$tag Error: $e');
        expect(
          e,
          isA<AuthException>()
              .having(
                (e) => e.type,
                'error type',
                equals(AuthErrorType.missingApiKey),
              )
              .having(
                (e) => e.message,
                'message',
                contains('API key is missing'),
              ),
        );
      }
    });

    test('should provide detailed error for malformed URL', () async {
      logger.i('$tag Testing malformed URL error handling');

      // Recreate server to simulate malformed URL error
      await server.close();
      server = await AuthTestServer.create(simulateMalformedUrl: true);

      // Setup DI with malformed URL and server that returns malformed URL error
      _setupDIWithMalformedUrl(getIt, server.port);
      authApiClient = getIt<AuthenticationApiClient>();

      // Execute login request (should fail with malformed URL error)
      try {
        await authApiClient.login('test@example.com', 'password');
        fail('Login should have failed with malformed URL error');
      } catch (e) {
        logger.d('$tag Error: $e');

        // Accept either malformedUrl or a 404 server error
        expect(
          e,
          isA<AuthException>().having(
            (e) => e.type,
            'error type',
            equals(AuthErrorType.server),
          ),
        );

        // Should mention path in the message
        expect((e as AuthException).message, contains('404'));
        expect(e.message, contains('auth/login'));
      }
    });

    test('should provide rich diagnostic info in network errors', () async {
      logger.i('$tag Testing network error diagnostics');

      // Use an invalid port number to cause connection refused error
      _setupWithNetworkError(getIt, 65535); // Invalid port
      authApiClient = getIt<AuthenticationApiClient>();

      // Execute login request (should fail with network error)
      try {
        await authApiClient.login('test@example.com', 'password');
        fail('Login should have failed with network error');
      } catch (e) {
        logger.d('$tag Network error: $e');
        expect(
          e,
          isA<AuthException>()
              .having(
                (e) => e.type,
                'error type',
                equals(AuthErrorType.offlineOperation),
              )
              .having((e) => e.message, 'message', contains('offline')),
        );

        // Verify stack trace is preserved
        final authException = e as AuthException;
        expect(authException.stackTrace, isNotNull);

        // Verify diagnostic string includes both message and stack trace
        final diagnostic = authException.diagnosticString();
        expect(diagnostic, contains('Operation failed due to being offline'));
        expect(diagnostic, contains('#0')); // Stack trace line indicator
      }
    });

    test('should break circular dependency with function-based DI', () async {
      logger.i('$tag Testing function-based DI to break circular dependency');

      // Setup proper DI with AuthInterceptor
      _setupProperDIWithAuthInterceptor(getIt, server.port);

      // Verify we can create the AuthApiClient and AuthInterceptor without circular issues
      authApiClient = getIt<AuthenticationApiClient>();
      final dio = getIt<Dio>(instanceName: 'authenticatedDio');

      expect(dio.interceptors, isNotEmpty);
      expect(
        dio.interceptors.any((i) => i is AuthInterceptor),
        isTrue,
        reason: 'AuthInterceptor should be added to authenticatedDio',
      );

      // Verify AuthApiClient can be created with authenticatedDio
      expect(authApiClient, isNotNull);

      // Simple request to verify the circular dependency is broken
      try {
        await authApiClient.login('test@example.com', 'password');
      } catch (e) {
        // Just verifying no DI errors occur, actual response doesn't matter
        logger.d('$tag Expected error: $e');
      }

      // Verify request was made through the interceptor
      final request = server.lastRequest;
      expect(request, isNotNull);
    });

    // NEW TEST: Verify that using basicDio without API key interceptor causes issues
    test(
      'should fail when basicDio does not have API key interceptor',
      () async {
        logger.i('$tag Testing API key interceptor issue with basicDio');

        // Setup DI with basicDio that doesn't have API key interceptor
        final testHost = 'localhost:${server.port}';

        // Reset GetIt to start fresh
        await getIt.reset();

        getIt.registerSingleton<AppConfig>(
          AppConfig.test(apiDomain: testHost, apiKey: 'test-api-key'),
        );

        // Create a basicDio without API key interceptor
        final basicDio = Dio(BaseOptions(baseUrl: 'http://$testHost/api/v1/'));

        // Create an authenticatedDio with API key interceptor
        final authenticatedDio = Dio(
          BaseOptions(baseUrl: 'http://$testHost/api/v1/'),
        );
        authenticatedDio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              options.headers['x-api-key'] = 'test-api-key';
              return handler.next(options);
            },
          ),
        );

        getIt.registerSingleton<Dio>(basicDio, instanceName: 'basicDio');
        getIt.registerSingleton<Dio>(
          authenticatedDio,
          instanceName: 'authenticatedDio',
        );

        final credentialsProvider = TestAuthCredentialsProvider();
        getIt.registerSingleton<AuthCredentialsProvider>(credentialsProvider);

        // Register auth client with basicDio (problematic)
        getIt.registerSingleton<AuthenticationApiClient>(
          AuthenticationApiClient(
            basicHttpClient: getIt<Dio>(instanceName: 'basicDio'),
            credentialsProvider: credentialsProvider,
          ),
        );

        authApiClient = getIt<AuthenticationApiClient>();

        // Execute login request - should fail due to missing API key
        try {
          await authApiClient.login('test@example.com', 'password');
          fail('Login should have failed due to missing API key');
        } catch (e) {
          expect(
            e,
            isA<AuthException>().having(
              (e) => e.type,
              'error type',
              equals(AuthErrorType.missingApiKey),
            ),
          );
        }

        // Now fix the issue by using authenticatedDio instead
        getIt.unregister<AuthenticationApiClient>();
        getIt.registerSingleton<AuthenticationApiClient>(
          AuthenticationApiClient(
            basicHttpClient: getIt<Dio>(instanceName: 'authenticatedDio'),
            credentialsProvider: credentialsProvider,
          ),
        );

        authApiClient = getIt<AuthenticationApiClient>();

        // Try again - should work now
        final result = await authApiClient.login(
          'test@example.com',
          'password',
        );
        expect(result, isA<LoginResponseDto>());
        expect(result.accessToken, 'test-access-token');

        final request = server.lastRequest;
        expect(request, isNotNull);
        if (request != null) {
          expect(request.headers.value('x-api-key'), equals('test-api-key'));
        }
      },
    );
  });
}

/// Sets up proper DI for testing
void _setupProperDI(GetIt getIt, int serverPort) {
  final testHost = 'localhost:$serverPort';
  final credentialsProvider = TestAuthCredentialsProvider();

  // Create a properly configured Dio with base URL that has trailing slash
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://$testHost/api/v1/',
      headers: {'x-api-key': 'test-api-key'},
    ),
  );

  getIt.registerSingleton<AuthCredentialsProvider>(credentialsProvider);
  getIt.registerSingleton<Dio>(dio, instanceName: 'basicDio');

  getIt.registerSingleton<AuthenticationApiClient>(
    AuthenticationApiClient(
      basicHttpClient: getIt<Dio>(instanceName: 'basicDio'),
      credentialsProvider: credentialsProvider,
    ),
  );
}

/// Sets up DI with missing API key
void _setupDIWithMissingApiKey(GetIt getIt, int serverPort) {
  final testHost = 'localhost:$serverPort';
  final credentialsProvider = TestAuthCredentialsProvider(
    apiKey: null, // Missing API key
  );

  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://$testHost/api/v1/',
      // No API key in headers
    ),
  );

  getIt.registerSingleton<AuthCredentialsProvider>(credentialsProvider);
  getIt.registerSingleton<Dio>(dio, instanceName: 'basicDio');

  getIt.registerSingleton<AuthenticationApiClient>(
    AuthenticationApiClient(
      basicHttpClient: getIt<Dio>(instanceName: 'basicDio'),
      credentialsProvider: credentialsProvider,
    ),
  );
}

/// Sets up DI with malformed URL
void _setupDIWithMalformedUrl(GetIt getIt, int serverPort) {
  final testHost = 'localhost:$serverPort';
  final credentialsProvider = TestAuthCredentialsProvider();

  // Malformed URL - missing slash in base URL pattern
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://$testHost/api/v1', // missing trailing slash
      headers: {'x-api-key': 'test-api-key'},
    ),
  );

  getIt.registerSingleton<AuthCredentialsProvider>(credentialsProvider);
  getIt.registerSingleton<Dio>(dio, instanceName: 'basicDio');

  getIt.registerSingleton<AuthenticationApiClient>(
    AuthenticationApiClient(
      basicHttpClient: getIt<Dio>(instanceName: 'basicDio'),
      credentialsProvider: credentialsProvider,
    ),
  );
}

/// Sets up DI with network error
void _setupWithNetworkError(GetIt getIt, int invalidPort) {
  final testHost = 'localhost:$invalidPort';
  final credentialsProvider = TestAuthCredentialsProvider();

  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://$testHost/api/v1/',
      headers: {'x-api-key': 'test-api-key'},
    ),
  );

  getIt.registerSingleton<AuthCredentialsProvider>(credentialsProvider);
  getIt.registerSingleton<Dio>(dio, instanceName: 'basicDio');

  getIt.registerSingleton<AuthenticationApiClient>(
    AuthenticationApiClient(
      basicHttpClient: getIt<Dio>(instanceName: 'basicDio'),
      credentialsProvider: credentialsProvider,
    ),
  );
}

/// Sets up proper DI with auth interceptor
void _setupProperDIWithAuthInterceptor(GetIt getIt, int serverPort) {
  final testHost = 'localhost:$serverPort';
  final credentialsProvider = TestAuthCredentialsProvider();
  final eventBus = TestAuthEventBus();

  // Create basic Dio
  final basicDio = Dio(
    BaseOptions(
      baseUrl: 'http://$testHost/api/v1/',
      headers: {'x-api-key': 'test-api-key'},
    ),
  );

  getIt.registerSingleton<AuthCredentialsProvider>(credentialsProvider);
  getIt.registerSingleton<AuthEventBus>(eventBus);
  getIt.registerSingleton<Dio>(basicDio, instanceName: 'basicDio');

  // Register the auth API client with basicDio (for un-authenticated requests)
  getIt.registerSingleton<AuthenticationApiClient>(
    AuthenticationApiClient(
      basicHttpClient: getIt<Dio>(instanceName: 'basicDio'),
      credentialsProvider: credentialsProvider,
    ),
  );

  // Function-based DI for auth interceptor
  final authInterceptor = AuthInterceptor(
    refreshTokenFunction:
        (refreshToken) =>
            getIt<AuthenticationApiClient>().refreshToken(refreshToken),
    credentialsProvider: credentialsProvider,
    dio: basicDio,
    authEventBus: eventBus,
  );

  // Create authenticated Dio with auth interceptor
  final authenticatedDio = Dio(
    BaseOptions(
      baseUrl: 'http://$testHost/api/v1/',
      headers: {'x-api-key': 'test-api-key'},
    ),
  );
  authenticatedDio.interceptors.add(authInterceptor);

  getIt.registerSingleton<Dio>(
    authenticatedDio,
    instanceName: 'authenticatedDio',
  );
}

/// Test implementation of AuthCredentialsProvider
class TestAuthCredentialsProvider implements AuthCredentialsProvider {
  final String? apiKey;
  final String? accessToken;
  final String? refreshToken;

  TestAuthCredentialsProvider({
    this.apiKey = 'test-api-key',
    this.accessToken,
    this.refreshToken,
  });

  @override
  Future<void> deleteAccessToken() async {}

  @override
  Future<void> deleteRefreshToken() async {}

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getApiKey() async => apiKey;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<String?> getUserId() async => null;

  @override
  Future<bool> isAccessTokenValid() async => false;

  @override
  Future<bool> isRefreshTokenValid() async => false;

  @override
  Future<void> setAccessToken(String token) async {}

  @override
  Future<void> setRefreshToken(String token) async {}

  @override
  Future<void> setUserId(String userId) async {}
}

/// Test implementation of AuthEventBus
class TestAuthEventBus implements AuthEventBus {
  final List<AuthEvent> events = [];

  @override
  void add(AuthEvent event) {
    events.add(event);
  }

  void addError(Object error, [StackTrace? stackTrace]) {
    // No-op for test
  }

  @override
  Stream<AuthEvent> get stream => Stream.fromIterable(events);

  @override
  void dispose() {
    // No-op for test
  }
}
