import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
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
        ApiConfig.loginEndpoint,
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
        ApiConfig.loginEndpoint,
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
        ApiConfig.loginEndpoint,
        (server) => server.throws(
          408,
          DioException(
            requestOptions: RequestOptions(path: ApiConfig.loginEndpoint),
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
        ApiConfig.loginEndpoint,
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
        ApiConfig.refreshEndpoint,
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
      'should throw RefreshTokenInvalid exception when refresh token is invalid (401)',
      () async {
        // Arrange
        dioAdapter.onPost(
          ApiConfig.refreshEndpoint,
          (server) => server.reply(401, {'message': 'Invalid refresh token'}),
          data: {'refreshToken': testRefreshToken},
          headers: {'x-api-key': testApiKey},
        );

        // Act & Assert
        expect(
          () => authApiClient.refreshToken(testRefreshToken),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              AuthException.refreshTokenInvalid().message,
            ),
          ),
        );
      },
    );

    test(
      'should throw NetworkError on connection error during refresh',
      () async {
        // Arrange
        dioAdapter.onPost(
          ApiConfig.refreshEndpoint,
          (server) => server.throws(
            500, // Status code doesn't matter much for connection error
            DioException(
              requestOptions: RequestOptions(path: ApiConfig.refreshEndpoint),
              type: DioExceptionType.connectionTimeout,
            ),
          ),
          data: {'refreshToken': testRefreshToken},
          headers: {'x-api-key': testApiKey},
        );

        // Act & Assert
        expect(
          () => authApiClient.refreshToken(testRefreshToken),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              AuthException.networkError().message,
            ),
          ),
        );
      },
    );

    test('should throw ServerError on 500 error during refresh', () async {
      // Arrange
      dioAdapter.onPost(
        ApiConfig.refreshEndpoint,
        (server) => server.reply(500, {'message': 'Internal server error'}),
        data: {'refreshToken': testRefreshToken},
        headers: {'x-api-key': testApiKey},
      );

      // Act & Assert
      expect(
        () => authApiClient.refreshToken(testRefreshToken),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.serverError(500).message,
          ),
        ),
      );
    });
  });

  // Group for the new getUserProfile method
  group('getUserProfile', () {
    test('should throw AuthException on 500 error', () async {
      // Arrange
      dioAdapter.onGet(
        ApiConfig.userProfileEndpoint,
        (server) => server.reply(500, {'message': 'Server error'}),
        headers: {'x-api-key': testApiKey},
      );

      // Act & Assert
      expect(
        () => authApiClient.getUserProfile(),
        throwsA(isA<AuthException>()), // General check, specific below
      );
    });
  });

  // Re-added group for general error handling via test helper
  group('_handleDioException mapping', () {
    test('should map 401 on login to InvalidCredentials', () {
      final error = DioException(
        requestOptions: RequestOptions(path: ApiConfig.loginEndpoint),
        response: Response(
          statusCode: 401,
          requestOptions: RequestOptions(path: ApiConfig.loginEndpoint),
        ),
      );
      expect(
        () => authApiClient.testHandleDioException(error),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.invalidCredentials().message,
          ),
        ),
      );
    });

    test('should map 401 on refresh to RefreshTokenInvalid', () {
      final error = DioException(
        requestOptions: RequestOptions(path: ApiConfig.refreshEndpoint),
        response: Response(
          statusCode: 401,
          requestOptions: RequestOptions(path: ApiConfig.refreshEndpoint),
        ),
      );
      expect(
        () => authApiClient.testHandleDioException(error),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.refreshTokenInvalid().message,
          ),
        ),
      );
    });

    test('should map 403 to UnauthorizedOperation', () {
      final error = DioException(
        requestOptions: RequestOptions(
          path: ApiConfig.userProfileEndpoint,
        ), // Test with profile path
        response: Response(
          statusCode: 403,
          requestOptions: RequestOptions(path: ApiConfig.userProfileEndpoint),
        ),
      );
      expect(
        () => authApiClient.testHandleDioException(error),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.unauthorizedOperation().message,
          ),
        ),
      );
    });

    test('should map connection timeout to NetworkError', () {
      final error = DioException(
        requestOptions: RequestOptions(path: ApiConfig.loginEndpoint),
        type: DioExceptionType.connectionTimeout,
      );
      expect(
        () => authApiClient.testHandleDioException(error),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.networkError().message,
          ),
        ),
      );
    });

    test('should map specific connection errors to OfflineOperationFailed', () {
      final error = DioException(
        requestOptions: RequestOptions(path: ApiConfig.loginEndpoint),
        type: DioExceptionType.connectionError,
        message: 'SocketException: Failed host lookup',
      );
      expect(
        () => authApiClient.testHandleDioException(error),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.offlineOperationFailed().message,
          ),
        ),
      );
    });

    test('should map other connection errors to NetworkError', () {
      final error = DioException(
        requestOptions: RequestOptions(path: ApiConfig.loginEndpoint),
        type: DioExceptionType.connectionError,
        message: 'Some other connection error', // Different message
      );
      expect(
        () => authApiClient.testHandleDioException(error),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.networkError().message,
          ),
        ),
      );
    });

    test('should map 500 errors on generic path to ServerError', () {
      final error = DioException(
        requestOptions: RequestOptions(path: ApiConfig.loginEndpoint),
        response: Response(
          statusCode: 500,
          requestOptions: RequestOptions(path: ApiConfig.loginEndpoint),
        ),
      );
      expect(
        () => authApiClient.testHandleDioException(error),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.serverError(500).message,
          ),
        ),
      );
    });

    test('should map errors on profile path to UserProfileFetchFailed', () {
      final error = DioException(
        requestOptions: RequestOptions(path: ApiConfig.userProfileEndpoint),
        response: Response(
          statusCode: 500, // Example: 500 error on profile path
          requestOptions: RequestOptions(path: ApiConfig.userProfileEndpoint),
        ),
      );
      expect(
        () => authApiClient.testHandleDioException(error),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.userProfileFetchFailed().message,
          ),
        ),
      );
    });
  });
}
