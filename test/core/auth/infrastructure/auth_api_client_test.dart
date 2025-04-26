import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_error_type.dart';
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
import 'package:stack_trace/stack_trace.dart';

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
    'access_token': testAccessToken,
    'refresh_token': testRefreshToken,
    'user_id': testUserId,
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

    // Add interceptor to mimic API key injection for tests
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['x-api-key'] = testApiKey;
          return handler.next(options);
        },
      ),
    );

    mockCredentialsProvider = MockAuthCredentialsProvider();
    authApiClient = AuthApiClient(
      httpClient: dio, // Now uses Dio instance with test interceptor
      credentialsProvider: mockCredentialsProvider,
    );

    // Configure the mock auth credentials provider
    // This when() seems redundant now if the interceptor always adds the key,
    // but let's leave it for now as AuthApiClient still requires the provider.
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
              AuthException.networkError(ApiConfig.loginEndpoint).message,
            ),
          ),
        );
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
            AuthException.serverError(500, ApiConfig.loginEndpoint).message,
          ),
        ),
      );
    });
  });

  group('refreshToken', () {
    test('should return AuthResponseDto on successful token refresh', () async {
      // Arrange
      dioAdapter.onPost(
        ApiConfig.refreshEndpoint,
        (server) => server.reply(200, successAuthResponse),
        data: {'refresh_token': testRefreshToken},
        headers: {'x-api-key': testApiKey},
      );

      // Act
      final result = await authApiClient.refreshToken(testRefreshToken);

      // Assert
      expect(result, isA<AuthResponseDto>());
      // Assert fields match...
    });

    test(
      'should throw RefreshTokenInvalid exception on 401 (refresh)',
      () async {
        // Arrange
        dioAdapter.onPost(
          ApiConfig.refreshEndpoint,
          (server) => server.reply(401, {'message': 'Invalid refresh token'}),
          data: {'refresh_token': testRefreshToken},
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
        data: {'refresh_token': testRefreshToken},
        headers: {'x-api-key': testApiKey},
      );

      // Act & Assert
      expect(
        () => authApiClient.refreshToken(testRefreshToken),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.networkError(ApiConfig.refreshEndpoint).message,
          ),
        ),
      );
    });

    test('should throw ServerError on 500 error (refresh)', () async {
      // Arrange
      dioAdapter.onPost(
        ApiConfig.refreshEndpoint,
        (server) => server.reply(500, {'message': 'Internal server error'}),
        data: {'refresh_token': testRefreshToken},
        headers: {'x-api-key': testApiKey},
      );

      // Act & Assert
      expect(
        () => authApiClient.refreshToken(testRefreshToken),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.serverError(500, ApiConfig.refreshEndpoint).message,
          ),
        ),
      );
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
              AuthException.networkError(ApiConfig.userProfileEndpoint).message,
            ),
          ),
        );
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

      // Add x-api-key to headers to avoid triggering the missingApiKey check
      error.requestOptions.headers = {'x-api-key': testApiKey};

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

      // Add x-api-key to headers to avoid triggering the missingApiKey check
      error.requestOptions.headers = {'x-api-key': testApiKey};

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

      // Add x-api-key to headers to avoid triggering the missingApiKey check
      error.requestOptions.headers = {'x-api-key': testApiKey};

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
            AuthException.serverError(503, ApiConfig.loginEndpoint).message,
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
            AuthException.networkError(ApiConfig.loginEndpoint).message,
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
              AuthException.networkError(ApiConfig.loginEndpoint).message,
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
              AuthException.serverError(418, ApiConfig.loginEndpoint).message,
            ),
          ),
        );
      },
    );

    // New tests for Phase 4: Improved Error Messages

    group('Phase 4: Improved Error Messages', () {
      test('should detect missing API key in 401 error', () {
        final error = createDioError(
          path: ApiConfig.loginEndpoint,
          statusCode: 401,
          responseData: {'message': 'Missing API key'},
        );

        // Set headers to NOT include x-api-key
        error.requestOptions.headers = {};

        expect(
          () => authApiClient.testHandleDioException(error),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('API key is missing'),
            ),
          ),
        );
      });

      test('should provide specific error for malformed URL path (404)', () {
        final error = createDioError(
          path: '/api/v1auth/login', // Missing slash between v1 and auth
          statusCode: 404,
        );

        expect(
          () => authApiClient.testHandleDioException(error),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('URL path error'),
            ),
          ),
        );
      });

      test(
        'should include request path in network errors for better context',
        () {
          final path = ApiConfig.loginEndpoint;
          final error = DioException(
            requestOptions: RequestOptions(path: path),
            type: DioExceptionType.connectionTimeout,
          );

          expect(
            () => authApiClient.testHandleDioException(error),
            throwsA(
              isA<AuthException>().having(
                (e) => e.message,
                'message',
                AuthException.networkError(path).message,
              ),
            ),
          );
        },
      );
    });
  });

  // Add a new group to test the improved AuthException features
  group('Improved AuthException Features', () {
    test('should preserve stack trace when provided', () {
      // Arrange: Mock stack trace for testing
      final mockStackTrace = Trace.current();

      // Act: Create exceptions with stack trace
      final networkError = AuthException.networkError(
        'test/path',
        mockStackTrace,
      );
      final serverError = AuthException.serverError(
        500,
        'test/path',
        mockStackTrace,
      );

      // Assert: Stack traces are preserved
      expect(networkError.stackTrace, equals(mockStackTrace));
      expect(serverError.stackTrace, equals(mockStackTrace));
    });

    test('exactlyEquals compares both type and message', () {
      // Arrange: Create exceptions with different paths but same type
      final error1 = AuthException.networkError('path1');
      final error2 = AuthException.networkError('path2');
      final error3 = AuthException.networkError('path1'); // Same as error1
      final error4 = AuthException.serverError(500, 'path1'); // Different type

      // Act & Assert: Check equality behavior
      expect(error1 == error2, isTrue); // Basic == only checks type
      expect(error1.exactlyEquals(error2), isFalse); // exact checks message too
      expect(error1.exactlyEquals(error3), isTrue); // Same message and type
      expect(error1 == error4, isFalse); // Different types
      expect(error1.exactlyEquals(error4), isFalse); // Different everything
    });

    test('diagnosticString includes stack trace when available', () {
      // Arrange: Create exceptions with and without stack trace
      final mockStackTrace = Trace.parse(
        'at function (file:1:2)\nat other (file:3:4)',
      );
      final withStack = AuthException.networkError('test/path', mockStackTrace);
      final withoutStack = AuthException.networkError('test/path');

      // Act & Assert: Check diagnostic string format
      expect(
        withoutStack.diagnosticString(),
        equals('AuthException: Network error occurred (path: test/path)'),
      );
      expect(
        withStack.diagnosticString(),
        contains('AuthException: Network error occurred (path: test/path)'),
      );
      expect(withStack.diagnosticString(), contains('at function (file:1:2)'));
    });

    group('fromStatusCode factory method', () {
      test('should detect missing API key for 401 errors', () {
        // Act: Create exception using factory
        final exception = AuthException.fromStatusCode(
          401,
          'api/v1/auth/login',
          hasApiKey: false,
        );

        // Assert: Right type of exception is created
        expect(exception.type, equals(AuthErrorType.missingApiKey));
        expect(exception.message, contains('API key is missing'));
        expect(exception.message, contains('api/v1/auth/login'));
      });

      test('should create refreshTokenInvalid for 401 on refresh endpoint', () {
        // Act: Create exception using factory
        final exception = AuthException.fromStatusCode(
          401,
          'api/v1/auth/refresh-session',
          isRefreshEndpoint: true,
        );

        // Assert: Right type of exception is created
        expect(exception.type, equals(AuthErrorType.refreshTokenInvalid));
      });

      test(
        'should create userProfileFetchFailed for 401 on profile endpoint',
        () {
          // Act: Create exception using factory
          final exception = AuthException.fromStatusCode(
            401,
            'api/v1/users/profile',
            isProfileEndpoint: true,
          );

          // Assert: Right type of exception is created
          expect(exception.type, equals(AuthErrorType.userProfileFetchFailed));
        },
      );

      test(
        'should create malformedUrl for 404 with incorrect path pattern',
        () {
          // Act: Create exception using factory
          final exception = AuthException.fromStatusCode(
            404,
            'api/v1auth/login', // Missing slash
          );

          // Assert: Right type of exception is created
          expect(exception.type, equals(AuthErrorType.malformedUrl));
          expect(exception.message, contains('URL path error'));
        },
      );

      test('should preserve stack trace when provided', () {
        // Arrange: Mock stack trace
        final mockStackTrace = Trace.current();

        // Act: Create exception with stack trace
        final exception = AuthException.fromStatusCode(
          500,
          'api/v1/endpoint',
          stackTrace: mockStackTrace,
        );

        // Assert: Stack trace is preserved
        expect(exception.stackTrace, equals(mockStackTrace));
      });

      test('should handle server errors with correct status code', () {
        // Act: Create exception for server error
        final exception = AuthException.fromStatusCode(503, 'api/v1/endpoint');

        // Assert: Contains correct status code
        expect(exception.type, equals(AuthErrorType.server));
        expect(exception.message, contains('Server error occurred (503)'));
      });
    });
  });

  group('AuthApiClient._handleDioException with enhanced errors', () {
    // Helper function to create DioException with stacktrace
    DioException createDioErrorWithStack({
      required String path,
      required int statusCode,
      dynamic responseData = const {'message': 'Error'},
      DioExceptionType type = DioExceptionType.badResponse,
      Object? error,
      StackTrace? stackTrace,
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
        stackTrace: stackTrace,
      );
    }

    test('should preserve stack trace in handled exceptions', () {
      // Arrange: Create error with stack trace
      final mockStackTrace = Trace.current();
      final error = createDioErrorWithStack(
        path: ApiConfig.loginEndpoint,
        statusCode: 500,
        stackTrace: mockStackTrace,
      );

      try {
        // Act: Let the API client handle the exception
        authApiClient.testHandleDioException(error);
        fail('Exception was not thrown');
      } catch (e) {
        // Assert: Stack trace is preserved in resulting exception
        expect(e, isA<AuthException>());
        final authException = e as AuthException;
        expect(authException.stackTrace, equals(mockStackTrace));
      }
    });

    test('should correctly use fromStatusCode for HTTP errors', () {
      // Arrange: Create a 404 with malformed path
      final error = createDioErrorWithStack(
        path: 'api/v1auth/login', // Missing slash
        statusCode: 404,
      );

      // Act & Assert: Verify correct exception type
      expect(
        () => authApiClient.testHandleDioException(error),
        throwsA(
          isA<AuthException>().having(
            (e) => e.type,
            'type',
            equals(AuthErrorType.malformedUrl),
          ),
        ),
      );
    });
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
