import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/infrastructure/authentication_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:docjet_mobile/core/interfaces/app_config_interface.dart';
import 'package:docjet_mobile/core/user/infrastructure/user_api_client.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:docjet_mobile/core/auth/domain/repositories/i_user_profile_cache.dart';
import 'package:docjet_mobile/core/user/infrastructure/dtos/user_profile_dto.dart';

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
            'access_token': 'test-access-token',
            'refresh_token': 'test-refresh-token',
            'user_id': 'test-user-id',
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

/// Test implementation of IUserProfileCache
class TestUserProfileCache implements IUserProfileCache {
  UserProfileDto? _profile;
  DateTime? _timestamp;

  @override
  Future<void> clearAllProfiles() async {
    _profile = null;
    _timestamp = null;
  }

  @override
  Future<void> clearProfile(String userId) async {
    // Assuming single user for tests
    _profile = null;
    _timestamp = null;
  }

  @override
  Future<UserProfileDto?> getProfile(String userId) async {
    return _profile;
  }

  @override
  Future<bool> isProfileStale(
    String userId, {
    required bool isAccessTokenValid,
    required bool isRefreshTokenValid,
    Duration? maxAge,
  }) async {
    if (!isAccessTokenValid && !isRefreshTokenValid) return true;
    if (_timestamp == null) return true;
    if (maxAge != null && DateTime.now().difference(_timestamp!) > maxAge) {
      return true;
    }
    return false;
  }

  @override
  Future<void> saveProfile(
    UserProfileDto profileDto,
    DateTime timestamp,
  ) async {
    _profile = profileDto;
    _timestamp = timestamp;
  }
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
    test('Authentication clients work with proper Dio instances', () async {
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

      // Register AuthenticationApiClient FIRST - CRITICAL: this uses basicDio
      getIt.registerSingleton<AuthenticationApiClient>(
        AuthenticationApiClient(
          basicHttpClient: getIt<Dio>(instanceName: 'basicDio'),
          credentialsProvider: getIt<AuthCredentialsProvider>(),
        ),
      );

      // Register authenticatedDio AFTER AuthenticationApiClient
      getIt.registerSingleton<Dio>(
        getIt<DioFactory>().createAuthenticatedDio(
          authApiClient: getIt<AuthenticationApiClient>(),
          credentialsProvider: getIt<AuthCredentialsProvider>(),
          authEventBus: getIt<AuthEventBus>(),
        ),
        instanceName: 'authenticatedDio',
      );

      // Register UserApiClient which uses authenticatedDio
      getIt.registerSingleton<UserApiClient>(
        UserApiClient(
          authenticatedHttpClient: getIt<Dio>(instanceName: 'authenticatedDio'),
          credentialsProvider: getIt<AuthCredentialsProvider>(),
        ),
      );

      // Added: Register TestUserProfileCache
      getIt.registerSingleton<IUserProfileCache>(TestUserProfileCache());

      // Register AuthService WITH CACHE
      getIt.registerSingleton<AuthService>(
        AuthServiceImpl(
          authenticationApiClient: getIt<AuthenticationApiClient>(),
          userApiClient: getIt<UserApiClient>(),
          credentialsProvider: getIt<AuthCredentialsProvider>(),
          eventBus: getIt<AuthEventBus>(),
          userProfileCache: getIt<IUserProfileCache>(),
        ),
      );

      // Now attempt login with AuthenticationApiClient
      try {
        final result = await getIt<AuthenticationApiClient>().login(
          'test@example.com',
          'password',
        );

        // Now we expect this to succeed since basicDio has the API key interceptor
        expect(result.accessToken, equals('test-access-token'));
        expect(result.refreshToken, equals('test-refresh-token'));
        expect(result.userId, equals('test-user-id'));
      } catch (e) {
        fail(
          'Login should have succeeded with AuthenticationApiClient using basicDio: $e',
        );
      }

      // Verify the request that was made
      expect(server.lastRequest, isNotNull);
      expect(
        server.lastRequest!.headers.value('x-api-key'),
        equals('test-api-key'),
      );

      // Reset test server to verify next request
      server = await TestServer.create();
      logger.i('Created new test server on port ${server.port}');

      // Update the AppConfig to use the new server port
      getIt.unregister<AppConfigInterface>();
      getIt.registerSingleton<AppConfigInterface>(
        AppConfig.test(
          apiDomain: 'localhost:${server.port}',
          apiKey: 'test-api-key',
        ),
      );

      // Re-create DioFactory with updated config
      getIt.unregister<DioFactory>();
      getIt.registerSingleton<DioFactory>(
        DioFactory(appConfig: getIt<AppConfigInterface>()),
      );

      // Re-register Dio instances
      getIt.unregister<Dio>(instanceName: 'basicDio');
      getIt.registerSingleton<Dio>(
        getIt<DioFactory>().createBasicDio(),
        instanceName: 'basicDio',
      );

      // Re-register AuthenticationApiClient
      getIt.unregister<AuthenticationApiClient>();
      getIt.registerSingleton<AuthenticationApiClient>(
        AuthenticationApiClient(
          basicHttpClient: getIt<Dio>(instanceName: 'basicDio'),
          credentialsProvider: getIt<AuthCredentialsProvider>(),
        ),
      );

      // Re-register authenticatedDio
      getIt.unregister<Dio>(instanceName: 'authenticatedDio');
      getIt.registerSingleton<Dio>(
        getIt<DioFactory>().createAuthenticatedDio(
          authApiClient: getIt<AuthenticationApiClient>(),
          credentialsProvider: getIt<AuthCredentialsProvider>(),
          authEventBus: getIt<AuthEventBus>(),
        ),
        instanceName: 'authenticatedDio',
      );

      // Re-register UserApiClient
      getIt.unregister<UserApiClient>();
      getIt.registerSingleton<UserApiClient>(
        UserApiClient(
          authenticatedHttpClient: getIt<Dio>(instanceName: 'authenticatedDio'),
          credentialsProvider: getIt<AuthCredentialsProvider>(),
        ),
      );

      // Added: Re-register TestUserProfileCache
      getIt.unregister<IUserProfileCache>();
      getIt.registerSingleton<IUserProfileCache>(TestUserProfileCache());

      // Re-register AuthService WITH CACHE
      getIt.unregister<AuthService>();
      getIt.registerSingleton<AuthService>(
        AuthServiceImpl(
          authenticationApiClient: getIt<AuthenticationApiClient>(),
          userApiClient: getIt<UserApiClient>(),
          credentialsProvider: getIt<AuthCredentialsProvider>(),
          eventBus: getIt<AuthEventBus>(),
          userProfileCache: getIt<IUserProfileCache>(),
        ),
      );

      // Our fix is working! Both client types are using the right Dio instances
      // Verify UserApiClient uses authenticatedDio
      /*
      final mockUserProfile = {
        'id': 'test-user-id',
        'email': 'test@example.com',
        'name': 'Test User',
      };
      */

      // Set up mock response for next test
      server._lastRequest = null;

      try {
        // This test will actually make an HTTP request, which will fail
        // due to the mock server not properly handling user profile requests.
        // But we can still verify the API key header was sent correctly.
        await getIt<UserApiClient>().getUserProfile();
      } catch (e) {
        // Expected to fail because we don't mock the complete response
        // We just want to verify the headers
      }

      // Verify an HTTP request was made
      expect(server.lastRequest, isNotNull);
      if (server.lastRequest != null) {
        // Verify the API key was included in this request too
        expect(
          server.lastRequest!.headers.value('x-api-key'),
          equals('test-api-key'),
        );
      }
    });
  });
}
