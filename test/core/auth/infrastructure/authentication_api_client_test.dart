import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/infrastructure/authentication_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/login_response_dto.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/refresh_response_dto.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([Dio, AuthCredentialsProvider])
import 'authentication_api_client_test.mocks.dart';

void main() {
  final logger = LoggerFactory.getLogger('AuthenticationApiClientTest');
  final tag = logTag('AuthenticationApiClientTest');

  late MockDio mockBasicDio;
  late MockAuthCredentialsProvider mockCredentialsProvider;
  late AuthenticationApiClient authenticationApiClient;

  const testApiKey = 'test-api-key';
  const testEmail = 'test@example.com';
  const testPassword = 'password123';
  const testRefreshToken = 'refresh-token-123';

  setUp(() {
    logger.i('$tag Setting up test dependencies');
    mockBasicDio = MockDio();
    mockCredentialsProvider = MockAuthCredentialsProvider();

    // Set up credential provider to return API key
    when(
      mockCredentialsProvider.getApiKey(),
    ).thenAnswer((_) async => testApiKey);

    // Create the API client with the basic Dio
    authenticationApiClient = AuthenticationApiClient(
      basicHttpClient: mockBasicDio,
      credentialsProvider: mockCredentialsProvider,
    );
  });

  group('AuthenticationApiClient', () {
    test('login should use basicDio with API key', () async {
      // Arrange
      when(
        mockBasicDio.post(
          ApiConfig.loginEndpoint,
          data: {'email': testEmail, 'password': testPassword},
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'access_token': 'access-token-123',
            'refresh_token': 'refresh-token-123',
            'user_id': 'user-123',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ApiConfig.loginEndpoint),
        ),
      );

      // Act
      final result = await authenticationApiClient.login(
        testEmail,
        testPassword,
      );

      // Assert
      expect(result, isA<LoginResponseDto>());
      expect(result.accessToken, 'access-token-123');
      expect(result.refreshToken, 'refresh-token-123');
      expect(result.userId, 'user-123');

      // Verify basicDio was used
      verify(
        mockBasicDio.post(
          ApiConfig.loginEndpoint,
          data: {'email': testEmail, 'password': testPassword},
        ),
      ).called(1);
    });

    test('refreshToken should use basicDio with API key', () async {
      // Arrange
      when(
        mockBasicDio.post(
          ApiConfig.refreshEndpoint,
          data: {'refresh_token': testRefreshToken},
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'access_token': 'new-access-token',
            'refresh_token': 'new-refresh-token',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ApiConfig.refreshEndpoint),
        ),
      );

      // Act
      final result = await authenticationApiClient.refreshToken(
        testRefreshToken,
      );

      // Assert
      expect(result, isA<RefreshResponseDto>());
      expect(result.accessToken, 'new-access-token');
      expect(result.refreshToken, 'new-refresh-token');

      // Verify basicDio was used
      verify(
        mockBasicDio.post(
          ApiConfig.refreshEndpoint,
          data: {'refresh_token': testRefreshToken},
        ),
      ).called(1);
    });

    test('login should handle network errors properly', () async {
      // Arrange - simulate network error
      when(
        mockBasicDio.post(
          ApiConfig.loginEndpoint,
          data: {'email': testEmail, 'password': testPassword},
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.connectionError,
          error: 'Network error',
          requestOptions: RequestOptions(path: ApiConfig.loginEndpoint),
        ),
      );

      // Act & Assert
      expect(
        () => authenticationApiClient.login(testEmail, testPassword),
        throwsA(isA<AuthException>()),
      );
    });

    test('refreshToken should handle server errors properly', () async {
      // Arrange - simulate server error
      when(
        mockBasicDio.post(
          ApiConfig.refreshEndpoint,
          data: {'refresh_token': testRefreshToken},
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 500,
            requestOptions: RequestOptions(path: ApiConfig.refreshEndpoint),
          ),
          requestOptions: RequestOptions(path: ApiConfig.refreshEndpoint),
        ),
      );

      // Act & Assert
      expect(
        () => authenticationApiClient.refreshToken(testRefreshToken),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
