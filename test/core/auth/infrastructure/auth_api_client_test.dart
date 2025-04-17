import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for dependencies
@GenerateMocks([AuthCredentialsProvider])
import 'auth_api_client_test.mocks.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late MockAuthCredentialsProvider mockCredentialsProvider;
  late AuthApiClient authApiClient;

  const testApiKey = 'test-api-key';
  const testEmail = 'test@example.com';
  const testPassword = 'password123';
  const testAccessToken = 'test-access-token';
  const testRefreshToken = 'test-refresh-token';
  const testUserId = 'test-user-id';

  // Sample successful response
  final successResponse = {
    'accessToken': testAccessToken,
    'refreshToken': testRefreshToken,
    'userId': testUserId,
  };

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    mockCredentialsProvider = MockAuthCredentialsProvider();
    authApiClient = AuthApiClient(
      httpClient: dio,
      credentialsProvider: mockCredentialsProvider,
    );

    // Configure the mock auth credentials provider
    when(
      mockCredentialsProvider.getApiKey(),
    ).thenAnswer((_) async => testApiKey);
  });

  group('login', () {
    test('should return AuthResponseDto on successful login', () async {
      // Arrange
      dioAdapter.onPost(
        '/api/v1/auth/login',
        (server) => server.reply(200, successResponse),
        data: {'email': testEmail, 'password': testPassword},
        headers: {'x-api-key': testApiKey},
      );

      // Act
      final result = await authApiClient.login(testEmail, testPassword);

      // Assert
      expect(result, isA<AuthResponseDto>());
      expect(result.accessToken, equals(testAccessToken));
      expect(result.refreshToken, equals(testRefreshToken));
      expect(result.userId, equals(testUserId));
      verify(mockCredentialsProvider.getApiKey()).called(1);
    });

    test('should throw InvalidCredentials exception on 401', () async {
      // Arrange
      dioAdapter.onPost(
        '/api/v1/auth/login',
        (server) => server.reply(401, {'message': 'Invalid credentials'}),
        data: {'email': testEmail, 'password': testPassword},
        headers: {'x-api-key': testApiKey},
      );

      // Act & Assert
      expect(
        () => authApiClient.login(testEmail, testPassword),
        throwsA(isA<AuthException>()),
      );
    });

    test('should throw NetworkError exception on connection error', () async {
      // Arrange - simulate connection error
      dioAdapter.onPost(
        '/api/v1/auth/login',
        (server) => server.throws(
          408,
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/auth/login'),
            type: DioExceptionType.connectionTimeout,
          ),
        ),
        data: {'email': testEmail, 'password': testPassword},
        headers: {'x-api-key': testApiKey},
      );

      // Act & Assert
      expect(
        () => authApiClient.login(testEmail, testPassword),
        throwsA(isA<AuthException>()),
      );
    });

    test('should throw ServerError exception on server error', () async {
      // Arrange
      dioAdapter.onPost(
        '/api/v1/auth/login',
        (server) => server.reply(500, {'message': 'Internal server error'}),
        data: {'email': testEmail, 'password': testPassword},
        headers: {'x-api-key': testApiKey},
      );

      // Act & Assert
      expect(
        () => authApiClient.login(testEmail, testPassword),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('refreshToken', () {
    test('should return AuthResponseDto on successful token refresh', () async {
      // Arrange
      dioAdapter.onPost(
        '/api/v1/auth/refresh-session',
        (server) => server.reply(200, successResponse),
        data: {'refreshToken': testRefreshToken},
        headers: {'x-api-key': testApiKey},
      );

      // Act
      final result = await authApiClient.refreshToken(testRefreshToken);

      // Assert
      expect(result, isA<AuthResponseDto>());
      expect(result.accessToken, equals(testAccessToken));
      expect(result.refreshToken, equals(testRefreshToken));
      expect(result.userId, equals(testUserId));
      verify(mockCredentialsProvider.getApiKey()).called(1);
    });

    test(
      'should throw TokenExpired exception when refresh token is invalid',
      () async {
        // Arrange
        dioAdapter.onPost(
          '/api/v1/auth/refresh-session',
          (server) => server.reply(401, {'message': 'Invalid refresh token'}),
          data: {'refreshToken': testRefreshToken},
          headers: {'x-api-key': testApiKey},
        );

        // Act & Assert
        expect(
          () => authApiClient.refreshToken(testRefreshToken),
          throwsA(isA<AuthException>()),
        );
      },
    );
  });
}
