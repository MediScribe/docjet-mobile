import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
// TODO: Import UserProfileDto when created
// import 'package:docjet_mobile/core/auth/infrastructure/dtos/user_profile_dto.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'dart:io'; // Import for SocketException

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
  const testAccessToken =
      'test-access-token'; // Assumed handled by interceptor for profile
  const testRefreshToken = 'test-refresh-token';
  const testUserId = 'test-user-id';

  // Sample successful auth response
  final successAuthResponse = {
    'accessToken': testAccessToken,
    'refreshToken': testRefreshToken,
    'userId': testUserId,
  };

  // Sample successful user profile response (placeholder)
  // This response will be used in future tests when UserProfileDto is implemented
  // ignore: unused_local_variable
  final successProfileResponse = {
    'id': testUserId,
    'name': 'Test User',
    'email': testEmail,
    // Add other fields as needed by UserProfileDto
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
        (server) => server.reply(200, successAuthResponse),
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

    test('should throw InvalidCredentials exception on 401 (login)', () async {
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
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.invalidCredentials().message,
          ),
        ),
      );
      verify(mockCredentialsProvider.getApiKey()).called(1);
    });

    test(
      'should throw NetworkError exception on connection error (login)',
      () async {
        // Arrange - simulate connection error
        dioAdapter.onPost(
          ApiConfig.loginEndpoint,
          (server) => server.throws(
            408, // Status code doesn't matter much here
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
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              AuthException.networkError().message,
            ),
          ),
        );
        verify(mockCredentialsProvider.getApiKey()).called(1);
      },
    );

    test('should throw ServerError exception on 500 (login)', () async {
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
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.serverError(500).message,
          ),
        ),
      );
      verify(mockCredentialsProvider.getApiKey()).called(1);
    });
  });

  group('refreshToken', () {
    test('should return AuthResponseDto on successful token refresh', () async {
      // Arrange
      dioAdapter.onPost(
        ApiConfig.refreshEndpoint,
        (server) => server.reply(200, successAuthResponse),
        data: {'refreshToken': testRefreshToken},
        headers: {'x-api-key': testApiKey},
      );

      // Act
      final result = await authApiClient.refreshToken(testRefreshToken);

      // Assert
      expect(result, isA<AuthResponseDto>());
      // Assert fields match...
      verify(mockCredentialsProvider.getApiKey()).called(1);
    });

    test(
      'should throw RefreshTokenInvalid exception on 401 (refresh)',
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
        verify(mockCredentialsProvider.getApiKey()).called(1);
      },
    );

    test('should throw NetworkError on connection error (refresh)', () async {
      // Arrange
      dioAdapter.onPost(
        ApiConfig.refreshEndpoint,
        (server) => server.throws(
          500,
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
      verify(mockCredentialsProvider.getApiKey()).called(1);
    });

    test('should throw ServerError on 500 error (refresh)', () async {
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
      verify(mockCredentialsProvider.getApiKey()).called(1);
    });
  });

  // Group for the new getUserProfile method
  group('getUserProfile', () {
    // TODO: Uncomment when UserProfileDto is implemented
    // test('should return UserProfileDto on successful profile fetch', () async {
    //   // Arrange
    //   dioAdapter.onGet(
    //     ApiConfig.userProfileEndpoint,
    //     (server) => server.reply(200, successProfileResponse),
    //     headers: {
    //       'x-api-key': testApiKey,
    //       // Assume Authorization header is added by interceptor
    //     },
    //   );

    //   // Act
    //   final result = await authApiClient.getUserProfile();

    //   // Assert
    //   expect(result, isA<UserProfileDto>());
    //   // Add checks for DTO fields...
    //   verify(mockCredentialsProvider.getApiKey()).called(1);
    // });

    test('should throw UserProfileFetchFailed on 401 (profile)', () async {
      // Arrange
      dioAdapter.onGet(
        ApiConfig.userProfileEndpoint,
        (server) => server.reply(401, {'message': 'Unauthorized'}),
        headers: {'x-api-key': testApiKey},
      );

      // Act & Assert
      expect(
        () => authApiClient.getUserProfile(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            // Should map to profile fetch failed, as 401 usually means token expired/invalid
            // which should be handled by interceptor first. If it *still* fails,
            // treat it as inability to fetch profile.
            AuthException.userProfileFetchFailed().message,
          ),
        ),
      );
      verify(mockCredentialsProvider.getApiKey()).called(1);
    });

    test('should throw UnauthorizedOperation on 403 (profile)', () async {
      // Arrange
      dioAdapter.onGet(
        ApiConfig.userProfileEndpoint,
        (server) => server.reply(403, {'message': 'Forbidden'}),
        headers: {'x-api-key': testApiKey},
      );

      // Act & Assert
      expect(
        () => authApiClient.getUserProfile(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.unauthorizedOperation().message,
          ),
        ),
      );
      verify(mockCredentialsProvider.getApiKey()).called(1);
    });

    test('should throw UserProfileFetchFailed on 500 (profile)', () async {
      // Arrange
      dioAdapter.onGet(
        ApiConfig.userProfileEndpoint,
        (server) => server.reply(500, {'message': 'Server error'}),
        headers: {'x-api-key': testApiKey},
      );

      // Act & Assert
      expect(
        () => authApiClient.getUserProfile(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.userProfileFetchFailed().message,
          ),
        ),
      );
      verify(mockCredentialsProvider.getApiKey()).called(1);
    });

    test(
      'should throw OfflineOperationFailed on SocketException (profile)',
      () async {
        // Arrange
        dioAdapter.onGet(
          ApiConfig.userProfileEndpoint,
          (server) => server.throws(
            500, // Status code is irrelevant for socket error
            DioException(
              requestOptions: RequestOptions(
                path: ApiConfig.userProfileEndpoint,
              ),
              type:
                  DioExceptionType
                      .connectionError, // Or DioExceptionType.unknown
              error: const SocketException('Failed host lookup'),
            ),
          ),
          headers: {'x-api-key': testApiKey},
        );

        // Act & Assert
        expect(
          () => authApiClient.getUserProfile(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              AuthException.offlineOperationFailed().message,
            ),
          ),
        );
        verify(mockCredentialsProvider.getApiKey()).called(1);
      },
    );

    test(
      'should throw NetworkError on other connection errors (profile)',
      () async {
        // Arrange
        dioAdapter.onGet(
          ApiConfig.userProfileEndpoint,
          (server) => server.throws(
            500, // Status code is irrelevant for timeout
            DioException(
              requestOptions: RequestOptions(
                path: ApiConfig.userProfileEndpoint,
              ),
              type: DioExceptionType.connectionTimeout,
            ),
          ),
          headers: {'x-api-key': testApiKey},
        );

        // Act & Assert
        expect(
          () => authApiClient.getUserProfile(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              AuthException.networkError().message,
            ),
          ),
        );
        verify(mockCredentialsProvider.getApiKey()).called(1);
      },
    );
  });

  // Group for testing _handleDioException mapping logic directly
  group('_handleDioException mapping', () {
    // Helper function to create DioException
    DioException createDioError({
      required String path,
      required int statusCode,
      dynamic responseData = const {'message': 'Error'},
      DioExceptionType type = DioExceptionType.badResponse,
      Object? error,
    }) {
      return DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: statusCode,
          data: responseData,
        ),
        type: type,
        error: error,
      );
    }

    test('should map 401 on login to InvalidCredentials', () {
      final error = createDioError(
        path: ApiConfig.loginEndpoint,
        statusCode: 401,
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
      final error = createDioError(
        path: ApiConfig.refreshEndpoint,
        statusCode: 401,
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

    test('should map 401 on profile to UserProfileFetchFailed', () {
      // If 401 happens on profile fetch, it means token might be invalid/expired
      // but wasn't caught/refreshed by interceptor, so profile fetch failed.
      final error = createDioError(
        path: ApiConfig.userProfileEndpoint,
        statusCode: 401,
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

    test('should map 403 on profile to UnauthorizedOperation', () {
      final error = createDioError(
        path: ApiConfig.userProfileEndpoint,
        statusCode: 403,
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

    test('should map 403 on other endpoint to UnauthorizedOperation', () {
      final error = createDioError(path: '/some/other/path', statusCode: 403);
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

    test('should map 500 on profile to UserProfileFetchFailed', () {
      final error = createDioError(
        path: ApiConfig.userProfileEndpoint,
        statusCode: 500,
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

    test('should map 5xx on other endpoint to ServerError', () {
      final error = createDioError(
        path: ApiConfig.loginEndpoint,
        statusCode: 503,
      );
      expect(
        () => authApiClient.testHandleDioException(error),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.serverError(503).message,
          ),
        ),
      );
    });

    test('should map SocketException to OfflineOperationFailed', () {
      final error = DioException(
        requestOptions: RequestOptions(path: ApiConfig.loginEndpoint),
        type: DioExceptionType.connectionError, // or .unknown
        error: const SocketException('Failed host lookup'),
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

    test('should map ConnectionTimeout to NetworkError', () {
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

    test(
      'should map unknown Dio error without SocketException to NetworkError',
      () {
        final error = DioException(
          requestOptions: RequestOptions(path: ApiConfig.loginEndpoint),
          type: DioExceptionType.unknown,
          error: Exception('Some other weird error'),
        );
        expect(
          () => authApiClient.testHandleDioException(error),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              AuthException.networkError()
                  .message, // Fallback for generic unknown connection issues
            ),
          ),
        );
      },
    );

    test(
      'should map BadResponse with non-standard code on profile to UserProfileFetchFailed',
      () {
        final error = createDioError(
          path: ApiConfig.userProfileEndpoint,
          statusCode: 418,
        ); // I'm a teapot
        expect(
          () => authApiClient.testHandleDioException(error),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              AuthException.userProfileFetchFailed()
                  .message, // Default error for profile fetch issues
            ),
          ),
        );
      },
    );

    test(
      'should map BadResponse with non-standard code on other path to ServerError',
      () {
        final error = createDioError(
          path: ApiConfig.loginEndpoint,
          statusCode: 418,
        ); // I'm a teapot
        expect(
          () => authApiClient.testHandleDioException(error),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              AuthException.serverError(
                418,
              ).message, // Default server error mapping
            ),
          ),
        );
      },
    );
  });
}

// Helper matcher for AuthException types
// Usage: expect(..., throwsAuthException(AuthException.invalidCredentials()))
// TypeMatcher<AuthException> throwsAuthException(AuthException expected) {
//   return isA<AuthException>().having(
//     (e) => e.message == expected.message,
//     'matches expected message',
//     true,
//   );
// }
