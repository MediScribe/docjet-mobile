import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_interceptor.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
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
    test(
      'createBasicDio should return configured Dio instance with default URL',
      () {
        // Act
        final dio = DioFactory.createBasicDio();

        // Assert
        expect(dio, isA<Dio>());
        // Verify default base URL is constructed correctly using the staging domain
        final expectedBaseUrl = ApiConfig.baseUrlFromDomain(
          'staging.docjet.ai',
        );
        expect(dio.options.baseUrl, expectedBaseUrl);
        expect(dio.options.connectTimeout, equals(const Duration(seconds: 30)));
        expect(dio.options.receiveTimeout, equals(const Duration(seconds: 30)));
        expect(dio.options.contentType, equals('application/json'));
      },
    );

    test('createAuthenticatedDio should add AuthInterceptor', () {
      // Arrange
      when(
        mockCredProvider.getApiKey(),
      ).thenAnswer((_) async => 'test-api-key');

      // Act
      final dio = DioFactory.createAuthenticatedDio(
        authApiClient: mockApiClient,
        credentialsProvider: mockCredProvider,
        authEventBus: mockAuthEventBus,
      );

      // Assert
      expect(dio, isA<Dio>());

      // Verify auth interceptor was added
      final hasAuthInterceptor = dio.interceptors.any(
        (i) => i is AuthInterceptor,
      );
      expect(hasAuthInterceptor, isTrue);

      // Verify API key interceptor was added
      final hasApiKeyInterceptor = dio.interceptors.any(
        (i) => i is InterceptorsWrapper || i is QueuedInterceptorsWrapper,
      );
      expect(hasApiKeyInterceptor, isTrue);
    });
  });
}
