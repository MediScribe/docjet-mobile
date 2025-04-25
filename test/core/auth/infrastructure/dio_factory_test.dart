import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_interceptor.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:mockito/annotations.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';

@GenerateMocks([AuthApiClient, AuthCredentialsProvider, AuthEventBus])
import 'dio_factory_test.mocks.dart';

void main() {
  late MockAuthApiClient mockApiClient;
  late MockAuthCredentialsProvider mockCredProvider;
  late MockAuthEventBus mockAuthEventBus;
  final container = GetIt.instance;

  setUp(() {
    mockApiClient = MockAuthApiClient();
    mockCredProvider = MockAuthCredentialsProvider();
    mockAuthEventBus = MockAuthEventBus();
    container.reset(); // Reset GetIt before each test

    // DO NOT register default here, register in each test or group as needed
    // container.registerSingleton<AppConfig>(AppConfig.fromEnvironment());
  });

  group('DioFactory', () {
    test('DioFactory uses AppConfig for domain configuration', () {
      // Arrange: Override default config
      container.registerSingleton<AppConfig>(
        AppConfig.test(apiDomain: 'test.example.com', apiKey: 'test-key'),
      );

      // Act
      final dio = DioFactory.createBasicDio();

      // Assert
      expect(dio.options.baseUrl, contains('test.example.com'));
    });

    group('createBasicDio', () {
      test(
        'should return configured Dio instance with default staging URL when using default AppConfig',
        () {
          // Arrange: Explicitly register the default config for this test
          container.registerSingleton<AppConfig>(AppConfig.fromEnvironment());

          // Act
          final dio = DioFactory.createBasicDio();

          // Assert
          expect(dio, isA<Dio>());
          final expectedBaseUrl = ApiConfig.baseUrlFromDomain(
            'staging.docjet.ai', // Default domain from AppConfig.fromEnvironment
          );
          expect(dio.options.baseUrl, expectedBaseUrl);
          expect(
            dio.options.connectTimeout,
            equals(const Duration(seconds: 30)),
          );
          expect(
            dio.options.receiveTimeout,
            equals(const Duration(seconds: 30)),
          );
          expect(dio.options.contentType, equals('application/json'));
          expect(dio.options.headers.containsKey('X-API-Key'), isFalse);
        },
      );

      test(
        'should use API_DOMAIN from AppConfig when available (localhost -> http)',
        () {
          // Arrange
          const testDomain = 'localhost:8080';
          container.registerSingleton<AppConfig>(
            AppConfig.test(apiDomain: testDomain, apiKey: ''),
          );

          // Act
          final dio = DioFactory.createBasicDio();

          // Assert
          final expectedBaseUrl = ApiConfig.baseUrlFromDomain(testDomain);
          expect(dio.options.baseUrl, expectedBaseUrl);
          expect(dio.options.baseUrl, startsWith('http://'));
          expect(dio.options.headers.containsKey('X-API-Key'), isFalse);
        },
      );

      test(
        'should use API_DOMAIN from AppConfig when available (remote -> https)',
        () {
          // Arrange
          const testDomain = 'api.test.com';
          // Unregister default if exists, then register test-specific
          if (container.isRegistered<AppConfig>())
            container.unregister<AppConfig>();
          container.registerSingleton<AppConfig>(
            AppConfig.test(apiDomain: testDomain, apiKey: ''),
          );

          // Act
          final dio = DioFactory.createBasicDio();

          // Assert
          final expectedBaseUrl = ApiConfig.baseUrlFromDomain(testDomain);
          expect(dio.options.baseUrl, expectedBaseUrl);
          expect(dio.options.baseUrl, startsWith('https://'));
          expect(dio.options.headers.containsKey('X-API-Key'), isFalse);
        },
      );
    });

    group('createAuthenticatedDio', () {
      test(
        'should add AuthInterceptor and API Key interceptor from AppConfig',
        () {
          // Arrange
          const testApiKey = 'test-key-123';
          container.registerSingleton<AppConfig>(
            AppConfig.test(apiDomain: 'staging.docjet.ai', apiKey: testApiKey),
          );

          // Act
          final dio = DioFactory.createAuthenticatedDio(
            authApiClient: mockApiClient,
            credentialsProvider: mockCredProvider,
            authEventBus: mockAuthEventBus,
          );

          // Assert
          expect(dio, isA<Dio>());
          expect(
            dio.interceptors.whereType<AuthInterceptor>().length,
            equals(1),
            reason: 'AuthInterceptor should be present',
          );

          // Check for the API Key interceptor
          final apiKeyInterceptors =
              dio.interceptors.whereType<InterceptorsWrapper>();
          expect(
            apiKeyInterceptors.isNotEmpty,
            isTrue,
            reason: 'Should have at least one InterceptorsWrapper for API key',
          );

          bool apiKeyHeaderCorrect = false;
          for (final interceptor in apiKeyInterceptors) {
            final options = RequestOptions(path: '/test');
            final handler = RequestInterceptorHandler();
            // ignore: invalid_use_of_internal_member
            interceptor.onRequest(options, handler);

            if (options.headers.containsKey('x-api-key') &&
                options.headers['x-api-key'] == testApiKey) {
              apiKeyHeaderCorrect = true;
              break;
            }
          }
          expect(
            apiKeyHeaderCorrect,
            isTrue,
            reason: 'API Key header should be set correctly by an interceptor',
          );
        },
      );

      test(
        'should NOT add X-API-Key header if API_KEY in AppConfig is missing',
        () {
          // Arrange
          // Unregister default if exists, then register test-specific
          if (container.isRegistered<AppConfig>())
            container.unregister<AppConfig>();
          container.registerSingleton<AppConfig>(
            AppConfig.test(
              apiDomain: 'staging.docjet.ai',
              apiKey: '',
            ), // No API Key
          );

          // Act
          final dio = DioFactory.createAuthenticatedDio(
            authApiClient: mockApiClient,
            credentialsProvider: mockCredProvider,
            authEventBus: mockAuthEventBus,
          );

          // Assert
          final apiKeyInterceptors =
              dio.interceptors.whereType<InterceptorsWrapper>();

          bool headerFound = false;
          for (final interceptor in apiKeyInterceptors) {
            final options = RequestOptions(path: '/test');
            final handler = RequestInterceptorHandler();
            // ignore: invalid_use_of_internal_member
            interceptor.onRequest(options, handler);

            if (options.headers.containsKey('x-api-key')) {
              headerFound = true;
              break;
            }
          }

          expect(
            headerFound,
            isFalse,
            reason:
                'x-api-key header should not be set when AppConfig.apiKey is empty',
          );
        },
      );

      test('should use API_DOMAIN from AppConfig for base URL', () {
        // Arrange
        const testDomain = 'auth.test.com';
        container.registerSingleton<AppConfig>(
          AppConfig.test(apiDomain: testDomain, apiKey: 'dummy-key'),
        );

        // Act
        final dio = DioFactory.createAuthenticatedDio(
          authApiClient: mockApiClient,
          credentialsProvider: mockCredProvider,
          authEventBus: mockAuthEventBus,
        );

        // Assert
        final expectedBaseUrl = ApiConfig.baseUrlFromDomain(testDomain);
        expect(dio.options.baseUrl, expectedBaseUrl);
        expect(dio.options.baseUrl, startsWith('https://'));
      });
    });

    // Removed the Environment Variable Loading group as getEnvironmentValue is deleted
  });
}
