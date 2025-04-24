import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_interceptor.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';

@GenerateMocks([AuthApiClient, AuthCredentialsProvider, AuthEventBus])
import 'dio_factory_test.mocks.dart';

void main() {
  late MockAuthApiClient mockApiClient;
  late MockAuthCredentialsProvider mockCredProvider;
  late MockAuthEventBus mockAuthEventBus;

  setUp(() {
    mockApiClient = MockAuthApiClient();
    mockCredProvider = MockAuthCredentialsProvider();
    mockAuthEventBus = MockAuthEventBus();
  });

  group('DioFactory', () {
    group('createBasicDio', () {
      test(
        'should return configured Dio instance with default staging URL when no env provided',
        () {
          // Act
          final dio = DioFactory.createBasicDio(); // No environment override

          // Assert
          expect(dio, isA<Dio>());
          final expectedBaseUrl = ApiConfig.baseUrlFromDomain(
            'staging.docjet.ai', // Default domain
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
        'should use API_DOMAIN from environment when available (localhost -> http)',
        () {
          // Arrange
          const testDomain = 'localhost:8080';
          final mockEnvironment = {'API_DOMAIN': testDomain};

          // Act
          final dio = DioFactory.createBasicDio(environment: mockEnvironment);

          // Assert
          final expectedBaseUrl = ApiConfig.baseUrlFromDomain(testDomain);
          expect(dio.options.baseUrl, expectedBaseUrl);
          expect(dio.options.baseUrl, startsWith('http://'));
          expect(dio.options.headers.containsKey('X-API-Key'), isFalse);
        },
      );

      test(
        'should use API_DOMAIN from environment when available (remote -> https)',
        () {
          // Arrange
          const testDomain = 'api.test.com';
          final mockEnvironment = {'API_DOMAIN': testDomain};

          // Act
          final dio = DioFactory.createBasicDio(environment: mockEnvironment);

          // Assert
          final expectedBaseUrl = ApiConfig.baseUrlFromDomain(testDomain);
          expect(dio.options.baseUrl, expectedBaseUrl);
          expect(dio.options.baseUrl, startsWith('https://'));
          expect(dio.options.headers.containsKey('X-API-Key'), isFalse);
        },
      );
    });

    group('createAuthenticatedDio', () {
      test('should add AuthInterceptor and API Key interceptor', () {
        // Arrange
        const testApiKey = 'test-key-123';
        final mockEnvironment = {
          'API_KEY': testApiKey,
          'API_DOMAIN': 'staging.docjet.ai',
        };

        // Act
        final dio = DioFactory.createAuthenticatedDio(
          authApiClient: mockApiClient,
          credentialsProvider: mockCredProvider,
          authEventBus: mockAuthEventBus,
          environment: mockEnvironment,
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
          reason: 'Should have at least one InterceptorsWrapper',
        );

        // Create a request and pass it through each interceptor to find the one that sets our header
        final handler = RequestInterceptorHandler();

        for (final interceptor in apiKeyInterceptors) {
          // Create fresh options for each test
          final options = RequestOptions(path: '/test');
          // ignore: invalid_use_of_internal_member
          interceptor.onRequest(options, handler);

          // If this is the API key interceptor, the header will be set
          if (options.headers.containsKey('x-api-key')) {
            expect(options.headers['x-api-key'], equals(testApiKey));
            // Found it, no need to continue
            break;
          }
        }
      });

      test('should NOT add X-API-Key header if API_KEY env var is missing', () {
        // Arrange
        final mockEnvironment = {
          'API_DOMAIN': 'staging.docjet.ai',
        }; // No API_KEY

        // Act
        final dio = DioFactory.createAuthenticatedDio(
          authApiClient: mockApiClient,
          credentialsProvider: mockCredProvider,
          authEventBus: mockAuthEventBus,
          environment: mockEnvironment,
        );

        // Assert
        final apiKeyInterceptors =
            dio.interceptors.whereType<InterceptorsWrapper>();
        expect(
          apiKeyInterceptors.isNotEmpty,
          isTrue,
          reason: 'Should have at least one InterceptorsWrapper',
        );

        // Create a request and pass it through each interceptor
        bool headerFound = false;
        for (final interceptor in apiKeyInterceptors) {
          // Create fresh options for each test
          final options = RequestOptions(path: '/test');
          final handler = RequestInterceptorHandler();
          // ignore: invalid_use_of_internal_member
          interceptor.onRequest(options, handler);

          // Check if any interceptor set our header
          if (options.headers.containsKey('x-api-key')) {
            headerFound = true;
            break;
          }
        }

        // Verify the header was never set
        expect(
          headerFound,
          isFalse,
          reason: 'x-api-key header should not be set',
        );
      });

      test('should use API_DOMAIN from environment for base URL', () {
        // Arrange
        const testDomain = 'auth.test.com';
        final mockEnvironment = {
          'API_DOMAIN': testDomain,
          'API_KEY': 'dummy-key', // Need some key for authenticated setup
        };

        // Act
        final dio = DioFactory.createAuthenticatedDio(
          authApiClient: mockApiClient,
          credentialsProvider: mockCredProvider,
          authEventBus: mockAuthEventBus,
          environment: mockEnvironment,
        );

        // Assert
        final expectedBaseUrl = ApiConfig.baseUrlFromDomain(testDomain);
        expect(dio.options.baseUrl, expectedBaseUrl);
        expect(dio.options.baseUrl, startsWith('https://'));
      });
    });

    // Remove or update the old integration test placeholder
    // test(
    //   'integration test - auth notifier correctly uses proper auth service from injection container',
    //   () {
    //     markTestSkipped('Needs to be implemented as an integration test');
    //   },
    //   skip: 'Needs to be implemented as an integration test',
    // );
  });
}
