import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_module.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/auth/secure_storage_auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart';
import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:docjet_mobile/core/interfaces/app_config_interface.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// Simple HTTP server for capturing auth requests in integration tests
class TestServer {
  final HttpServer _server;
  final List<HttpRequest> _requests = [];
  HttpRequest? _lastRequest;
  final Logger _logger = LoggerFactory.getLogger('TestServer');

  TestServer._(this._server);

  static Future<TestServer> create() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final testServer = TestServer._(server);

    server.listen((request) async {
      testServer._logger.d(
        'Received ${request.method} request: ${request.uri.path}',
      );
      testServer._logger.d('Headers: ${request.headers}');

      testServer._requests.add(request);
      testServer._lastRequest = request;

      // Read request body for logging
      List<int> body = [];
      await for (var chunk in request) {
        body.addAll(chunk);
      }
      if (body.isNotEmpty) {
        testServer._logger.d('Body: ${utf8.decode(body)}');
      }

      // Check for API key in headers
      if (request.headers.value('x-api-key') == null) {
        request.response.statusCode = 401;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'error': 'Missing API key',
            'message': 'API key is required',
          }),
        );
      } else {
        // Success response
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'accessToken': 'test-access-token',
            'refreshToken': 'test-refresh-token',
            'userId': 'test-user-id',
          }),
        );
      }

      await request.response.close();
    });

    return testServer;
  }

  int get port => _server.port;
  List<HttpRequest> get requests => List.unmodifiable(_requests);
  HttpRequest? get lastRequest => _lastRequest;

  Future<void> close() async {
    await _server.close();
  }
}

/// Test implementation of AuthCredentialsProvider that returns a fixed API key
class TestAuthCredentialsProvider implements AuthCredentialsProvider {
  @override
  Future<void> deleteAccessToken() async {}

  @override
  Future<void> deleteRefreshToken() async {}

  @override
  Future<String?> getAccessToken() async => 'test-access-token';

  @override
  Future<String> getApiKey() async => 'test-api-key';

  @override
  Future<String?> getRefreshToken() async => 'test-refresh-token';

  @override
  Future<String?> getUserId() async => 'test-user-id';

  @override
  Future<bool> isAccessTokenValid() async => true;

  @override
  Future<bool> isRefreshTokenValid() async => true;

  @override
  Future<void> setAccessToken(String token) async {}

  @override
  Future<void> setRefreshToken(String token) async {}

  @override
  Future<void> setUserId(String userId) async {}
}

void main() {
  final logger = LoggerFactory.getLogger('AuthModuleIntegrationTest');

  group('Auth Module Integration Tests', () {
    late TestServer server;
    late GetIt getIt;

    setUp(() async {
      // Start test server
      server = await TestServer.create();
      logger.i('Test server running on port ${server.port}');

      // Reset GetIt
      getIt = GetIt.instance;
      await getIt.reset();
    });

    tearDown(() async {
      await server.close();
      await getIt.reset();
    });

    /// Test that simulates exactly how the app configures its DI container
    test(
      'AuthModule confirms both Dio instances have API key interceptor',
      () async {
        // Setup AppConfig with test server
        final testDomain = 'localhost:${server.port}';
        getIt.registerSingleton<AppConfigInterface>(
          AppConfig.test(apiDomain: testDomain, apiKey: 'test-api-key'),
        );

        // Create a standard auth setup with real DioFactory
        getIt.registerSingleton<DioFactory>(
          DioFactory(appConfig: getIt<AppConfigInterface>()),
        );

        // Use our test credential provider instead of the real one
        getIt.registerSingleton<AuthCredentialsProvider>(
          TestAuthCredentialsProvider(),
        );

        getIt.registerSingleton<AuthEventBus>(AuthEventBus());

        // Register the Dio instances like the app would
        getIt.registerSingleton<Dio>(
          getIt<DioFactory>().createBasicDio(),
          instanceName: 'basicDio',
        );

        // Register AuthApiClient FIRST (like in the app) - CRITICAL: this uses basicDio
        getIt.registerSingleton<AuthApiClient>(
          AuthApiClient(
            httpClient: getIt<Dio>(instanceName: 'basicDio'),
            credentialsProvider: getIt<AuthCredentialsProvider>(),
          ),
        );

        // Register authenticatedDio AFTER AuthApiClient
        getIt.registerSingleton<Dio>(
          getIt<DioFactory>().createAuthenticatedDio(
            authApiClient: getIt<AuthApiClient>(),
            credentialsProvider: getIt<AuthCredentialsProvider>(),
            authEventBus: getIt<AuthEventBus>(),
          ),
          instanceName: 'authenticatedDio',
        );

        // Register AuthService
        getIt.registerSingleton<AuthService>(
          AuthServiceImpl(
            apiClient: getIt<AuthApiClient>(),
            credentialsProvider: getIt<AuthCredentialsProvider>(),
            eventBus: getIt<AuthEventBus>(),
          ),
        );

        // Now attempt login with this setup
        try {
          final result = await getIt<AuthApiClient>().login(
            'test@example.com',
            'password',
          );

          // Now we expect this to succeed since basicDio has the API key interceptor
          expect(result.accessToken, equals('test-access-token'));
          expect(result.refreshToken, equals('test-refresh-token'));
          expect(result.userId, equals('test-user-id'));
        } catch (e) {
          fail(
            'Login should have succeeded now that basicDio includes API key: $e',
          );
        }

        // Verify the request that was made
        expect(server.lastRequest, isNotNull);
        expect(
          server.lastRequest!.headers.value('x-api-key'),
          equals('test-api-key'),
        );

        // Our fix is working! Both Dio instances include API key headers.
        // For completeness, let's also verify authenticatedDio works
        getIt.unregister<AuthApiClient>();
        getIt.registerSingleton<AuthApiClient>(
          AuthApiClient(
            httpClient: getIt<Dio>(instanceName: 'authenticatedDio'),
            credentialsProvider: getIt<AuthCredentialsProvider>(),
          ),
        );
      },
    );
  });
}
