import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_interceptor.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/interfaces/app_config_interface.dart';

@GenerateMocks([
  AuthApiClient,
  AuthCredentialsProvider,
  AuthEventBus,
  AppConfigInterface,
])
import 'dio_factory_test.mocks.dart';

void main() {
  late MockAuthApiClient mockApiClient;
  late MockAuthCredentialsProvider mockCredProvider;
  late MockAuthEventBus mockAuthEventBus;
  late MockAppConfigInterface mockAppConfig;

  setUp(() {
    mockApiClient = MockAuthApiClient();
    mockCredProvider = MockAuthCredentialsProvider();
    mockAuthEventBus = MockAuthEventBus();
    mockAppConfig = MockAppConfigInterface();

    // Default stubbing for mockAppConfig used in instance-based tests
    when(mockAppConfig.apiDomain).thenReturn('default.test.com');
    when(mockAppConfig.apiKey).thenReturn('default-test-key');
  });

  // Refactored legacy tests to use the instance-based approach
  group('DioFactory (Refactored Legacy Tests)', () {
    // Helper to create factory with specific config for these tests
    DioFactory createFactory(AppConfigInterface config) {
      return DioFactory(appConfig: config);
    }

    test('DioFactory uses AppConfig for domain configuration', () {
      // Arrange: Create specific config for this test
      final testConfig = AppConfig.test(
        apiDomain: 'test.example.com',
        apiKey: 'test-key',
      );
      final dioFactory = createFactory(testConfig);

      // Act
      final dio = dioFactory.createBasicDio(); // Use instance method

      // Assert
      expect(dio.options.baseUrl, contains('test.example.com'));
    });

    group('createBasicDio', () {
      test(
        'should return configured Dio instance with default staging URL when using default AppConfig',
        () {
          // Arrange: Use the default environment config
          final testConfig = AppConfig.fromEnvironment();
          final dioFactory = createFactory(testConfig);

          // Act
          final dio = dioFactory.createBasicDio(); // Use instance method

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
          expect(
            dio.options.headers.containsKey('x-api-key'),
            isFalse,
          ); // Corrected assertion key
        },
      );

      test(
        'should use API_DOMAIN from AppConfig when available (localhost -> http)',
        () {
          // Arrange
          const testDomain = 'localhost:8080';
          final testConfig = AppConfig.test(apiDomain: testDomain, apiKey: '');
          final dioFactory = createFactory(testConfig);

          // Act
          final dio = dioFactory.createBasicDio(); // Use instance method

          // Assert
          final expectedBaseUrl = ApiConfig.baseUrlFromDomain(testDomain);
          expect(dio.options.baseUrl, expectedBaseUrl);
          expect(dio.options.baseUrl, startsWith('http://'));
          expect(
            dio.options.headers.containsKey('x-api-key'),
            isFalse,
          ); // Corrected assertion key
        },
      );

      test(
        'should use API_DOMAIN from AppConfig when available (remote -> https)',
        () {
          // Arrange
          const testDomain = 'api.test.com';
          final testConfig = AppConfig.test(apiDomain: testDomain, apiKey: '');
          final dioFactory = createFactory(testConfig);

          // Act
          final dio = dioFactory.createBasicDio(); // Use instance method

          // Assert
          final expectedBaseUrl = ApiConfig.baseUrlFromDomain(testDomain);
          expect(dio.options.baseUrl, expectedBaseUrl);
          expect(dio.options.baseUrl, startsWith('https://'));
          expect(
            dio.options.headers.containsKey('x-api-key'),
            isFalse,
          ); // Corrected assertion key
        },
      );

      test(
        'should add API key interceptor to basicDio when API key is present',
        () {
          // Arrange
          const testDomain = 'api.test.com';
          const testApiKey = 'test-basic-dio-key';
          final testConfig = AppConfig.test(
            apiDomain: testDomain,
            apiKey: testApiKey,
          );
          final dioFactory = createFactory(testConfig);

          // Act
          final dio = dioFactory.createBasicDio();

          // Assert
          final apiKeyInterceptors =
              dio.interceptors.whereType<InterceptorsWrapper>();
          expect(apiKeyInterceptors.isNotEmpty, isTrue);

          bool apiKeyHeaderCorrect = false;
          for (final interceptor in apiKeyInterceptors) {
            final options = RequestOptions(path: '/test');
            final handler = RequestInterceptorHandler();
            // ignore: invalid_use_of_internal_member
            interceptor.onRequest.call(options, handler);

            if (options.headers.containsKey('x-api-key') &&
                options.headers['x-api-key'] == testApiKey) {
              apiKeyHeaderCorrect = true;
              break;
            }
          }

          expect(
            apiKeyHeaderCorrect,
            isTrue,
            reason: 'basicDio should now have the API key interceptor',
          );
        },
      );
    });

    group('createAuthenticatedDio', () {
      test(
        'should add AuthInterceptor and API Key interceptor from AppConfig',
        () {
          // Arrange
          const testApiKey = 'test-key-123';
          final testConfig = AppConfig.test(
            apiDomain: 'staging.docjet.ai',
            apiKey: testApiKey,
          );
          final dioFactory = createFactory(testConfig);

          // Act
          final dio = dioFactory.createAuthenticatedDio(
            // Use instance method
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
            interceptor.onRequest.call(
              options,
              handler,
            ); // Use ?.call for safety

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
          final testConfig = AppConfig.test(
            apiDomain: 'staging.docjet.ai',
            apiKey: '', // No API Key
          );
          final dioFactory = createFactory(testConfig);

          // Act
          final dio = dioFactory.createAuthenticatedDio(
            // Use instance method
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
            interceptor.onRequest.call(
              options,
              handler,
            ); // Use ?.call for safety

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
        final testConfig = AppConfig.test(
          apiDomain: testDomain,
          apiKey: 'dummy-key',
        );
        final dioFactory = createFactory(testConfig);

        // Act
        final dio = dioFactory.createAuthenticatedDio(
          // Use instance method
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
  }); // End of Refactored Legacy Tests

  group('Instance-Based DioFactory', () {
    // Keep the new tests as they were
    test('createBasicDio uses apiDomain from injected AppConfig', () {
      // Arrange
      const testDomain = 'instance.test.dev';
      when(mockAppConfig.apiDomain).thenReturn(testDomain);
      when(mockAppConfig.apiKey).thenReturn(''); // Ensure no API key for basic

      // Instantiate the factory directly with the mock config
      final dioFactory = DioFactory(appConfig: mockAppConfig);

      // Act
      final dio = dioFactory.createBasicDio();

      // Assert
      final expectedBaseUrl = ApiConfig.baseUrlFromDomain(testDomain);
      expect(dio.options.baseUrl, expectedBaseUrl);
      expect(
        dio.options.baseUrl,
        startsWith('https://'),
      ); // Assuming test domain is remote
      expect(dio.options.headers.containsKey('x-api-key'), isFalse);
    });

    test(
      'createBasicDio uses http for localhost domain from injected AppConfig',
      () {
        // Arrange
        const testDomain = 'localhost:9999';
        when(mockAppConfig.apiDomain).thenReturn(testDomain);
        when(mockAppConfig.apiKey).thenReturn('');

        final dioFactory = DioFactory(appConfig: mockAppConfig);

        // Act
        final dio = dioFactory.createBasicDio();

        // Assert
        final expectedBaseUrl = ApiConfig.baseUrlFromDomain(testDomain);
        expect(dio.options.baseUrl, expectedBaseUrl);
        expect(dio.options.baseUrl, startsWith('http://'));
      },
    );

    test('createAuthenticatedDio uses apiKey from injected AppConfig', () {
      // Arrange
      const testDomain = 'auth-instance.test.dev';
      const testApiKey = 'instance-api-key-456';
      when(mockAppConfig.apiDomain).thenReturn(testDomain);
      when(mockAppConfig.apiKey).thenReturn(testApiKey);

      final dioFactory = DioFactory(appConfig: mockAppConfig);

      // Act
      final dio = dioFactory.createAuthenticatedDio(
        authApiClient: mockApiClient,
        credentialsProvider: mockCredProvider,
        authEventBus: mockAuthEventBus,
      );

      // Assert
      final expectedBaseUrl = ApiConfig.baseUrlFromDomain(testDomain);
      expect(dio.options.baseUrl, expectedBaseUrl);

      // Verify API Key interceptor
      final apiKeyInterceptors =
          dio.interceptors.whereType<InterceptorsWrapper>();
      expect(apiKeyInterceptors.isNotEmpty, isTrue);
      bool apiKeyHeaderCorrect = false;
      for (final interceptor in apiKeyInterceptors) {
        final options = RequestOptions(path: '/test');
        final handler = RequestInterceptorHandler();
        // ignore: invalid_use_of_internal_member
        interceptor.onRequest.call(
          options,
          handler,
        ); // Check if onRequest is non-null before calling
        if (options.headers['x-api-key'] == testApiKey) {
          apiKeyHeaderCorrect = true;
          break;
        }
      }
      expect(
        apiKeyHeaderCorrect,
        isTrue,
        reason: 'API Key should be injected from AppConfig',
      );

      // Verify Auth interceptor
      expect(dio.interceptors.whereType<AuthInterceptor>().length, equals(1));
    });

    test(
      'createAuthenticatedDio does NOT inject apiKey if missing in AppConfig',
      () {
        // Arrange
        const testDomain = 'no-key-instance.test.dev';
        when(mockAppConfig.apiDomain).thenReturn(testDomain);
        when(mockAppConfig.apiKey).thenReturn(''); // Empty API Key

        final dioFactory = DioFactory(appConfig: mockAppConfig);

        // Act
        final dio = dioFactory.createAuthenticatedDio(
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
          interceptor.onRequest.call(options, handler);
          if (options.headers.containsKey('x-api-key')) {
            headerFound = true;
            break;
          }
        }
        expect(
          headerFound,
          isFalse,
          reason: 'API Key header should NOT be set',
        );
      },
    );
  }); // End of Instance-Based DioFactory tests
}
