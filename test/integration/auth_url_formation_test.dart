import 'package:docjet_mobile/core/auth/infrastructure/authentication_api_client.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import 'helpers/test_server.dart';

/// Simple test to verify the URL formation and API key presence
/// without having to run the full app
void main() {
  // Setup logging
  final logger = LoggerFactory.getLogger(
    'AuthUrlFormationTest',
    level: Level.debug,
  );
  final tag = logTag('AuthUrlFormationTest');

  group('Auth API URL Formation Integration Tests', () {
    late TestServer server;
    late GetIt getIt;

    setUp(() async {
      logger.i('$tag Setting up test');

      // Create test server to capture requests
      logger.d('$tag Creating test server');
      server = await createTestServer();
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

      // Register a basic Dio client with logging interceptor and configured BaseURL
      logger.d('$tag Setting up Dio with logging');
      final dio = Dio(
        BaseOptions(
          // Critical fix: Set the base URL to correctly form the request URL
          baseUrl: 'http://$testHost/api/v1/',
          headers: {
            // Add the API key here to test header formation
            'x-api-key': 'test-api-key',
          },
        ),
      );

      // Add logging interceptor to see requests
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => logger.d('$tag DIO: $obj'),
        ),
      );

      getIt.registerSingleton<Dio>(dio, instanceName: 'basicDio');
      logger.d('$tag Dio configured with baseUrl: http://$testHost/api/v1/');

      // Register auth credentials provider with a test API key
      logger.d('$tag Registering credentials provider');
      final credentialsProvider = TestAuthCredentialsProvider();
      getIt.registerSingleton<AuthCredentialsProvider>(credentialsProvider);

      // Register auth API client with correctly named parameters
      logger.d('$tag Registering auth API client');
      getIt.registerSingleton<AuthenticationApiClient>(
        AuthenticationApiClient(
          basicHttpClient: getIt<Dio>(instanceName: 'basicDio'),
          credentialsProvider: credentialsProvider,
        ),
      );

      logger.i('$tag Test setup complete');
    });

    tearDown(() async {
      logger.i('$tag Tearing down test');
      // Close server and reset DI
      await server.close();
      await getIt.reset();
      logger.i('$tag Test teardown complete');
    });

    test('integration_test_url_formation', () async {
      logger.i('$tag Starting test');

      // Try to login, don't care about the result (will likely fail)
      final authClient = getIt<AuthenticationApiClient>();

      logger.d(
        '$tag Attempting login - we expect this to fail, but want to see the request',
      );
      try {
        await authClient.login('test@example.com', 'password');
        logger.w('$tag Login unexpectedly succeeded!');
      } catch (e) {
        logger.d('$tag Expected exception: ${e.toString()}');
      }

      logger.d('$tag Checking if request was captured');
      logger.d('$tag Server received ${server.requests.length} requests');

      // Check if any request was made
      final request = server.lastRequest;
      if (request == null) {
        logger.e('$tag No request was captured by test server');
      } else {
        logger.i('$tag Request captured! URL path: ${request.uri.path}');
        logger.d('$tag Request headers: ${request.headers}');
      }

      expect(
        request,
        isNotNull,
        reason: 'No request was captured by test server',
      );

      if (request != null) {
        // Verify URL path is correctly formed with proper slashes
        expect(
          request.uri.path,
          contains('/api/v1/auth/login'),
          reason:
              'Path should contain properly formatted endpoint with slashes',
        );

        // Verify API key is present in headers
        expect(
          request.headers['x-api-key'],
          isNotNull,
          reason: 'API key header is missing',
        );
        expect(
          request.headers['x-api-key']?.first,
          equals('test-api-key'),
          reason: 'API key value is incorrect',
        );
      }

      logger.i('$tag Test completed');
    });
  });
}

/// Test implementation of AuthCredentialsProvider
class TestAuthCredentialsProvider implements AuthCredentialsProvider {
  @override
  Future<void> deleteAccessToken() async {}

  @override
  Future<void> deleteRefreshToken() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getApiKey() async => 'test-api-key';

  @override
  Future<String?> getRefreshToken() async => null;

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
