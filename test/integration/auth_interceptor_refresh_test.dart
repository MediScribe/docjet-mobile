import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/infrastructure/authentication_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_interceptor.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for dependencies
@GenerateMocks([
  AuthCredentialsProvider,
  AuthenticationApiClient,
  AuthEventBus,
  RequestInterceptorHandler,
  ErrorInterceptorHandler,
  Dio,
  Response,
])
import 'auth_interceptor_refresh_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late MockAuthCredentialsProvider mockCredentialsProvider;
  late MockAuthenticationApiClient mockApiClient;
  late MockAuthEventBus mockAuthEventBus;
  late AuthInterceptor authInterceptor;
  late MockErrorInterceptorHandler mockErrorHandler;

  // Test constants
  const String testApiKey = 'test-api-key';
  const String testExpiredAccessToken = 'test-expired-access-token';
  const String testRefreshToken = 'test-refresh-token';
  const String testNewAccessToken = 'new-access-token';
  const String testNewRefreshToken = 'new-refresh-token';
  const String testUserId = 'test-user-id';
  const String testApiEndpoint = '${ApiConfig.versionedApiPath}/test-endpoint';

  /// Helper to create a DioException for 401 unauthorized
  DioException createUnauthorizedError() {
    final requestOptions = RequestOptions(
      path: testApiEndpoint,
      headers: {
        'Authorization': 'Bearer $testExpiredAccessToken',
        'x-api-key': testApiKey,
      },
    );

    final unauthorizedResponse = Response(
      requestOptions: requestOptions,
      statusCode: 401,
      data: {'message': 'Unauthorized'},
    );

    return DioException(
      requestOptions: requestOptions,
      response: unauthorizedResponse,
      type: DioExceptionType.badResponse,
    );
  }

  /// Helper to create a success response
  Response<dynamic> createSuccessResponse(RequestOptions options) {
    return Response(
      requestOptions: options,
      statusCode: 200,
      data: {'success': true},
    );
  }

  /// Helper to set up common test mocks
  void setupCommonMocks() {
    // Common credential provider setup
    when(
      mockCredentialsProvider.getApiKey(),
    ).thenAnswer((_) async => testApiKey);
    when(
      mockCredentialsProvider.getAccessToken(),
    ).thenAnswer((_) async => testExpiredAccessToken);
    when(
      mockCredentialsProvider.getRefreshToken(),
    ).thenAnswer((_) async => testRefreshToken);
  }

  /// Helper to set up token refresh success
  void setupTokenRefreshSuccess() {
    when(
      mockCredentialsProvider.setAccessToken(testNewAccessToken),
    ).thenAnswer((_) async => {});
    when(
      mockCredentialsProvider.setRefreshToken(testNewRefreshToken),
    ).thenAnswer((_) async => {});

    when(mockApiClient.refreshToken(testRefreshToken)).thenAnswer(
      (_) async => const AuthResponseDto(
        accessToken: testNewAccessToken,
        refreshToken: testNewRefreshToken,
        userId: testUserId,
      ),
    );
  }

  setUp(() {
    // Set up mocks
    mockDio = MockDio();
    mockCredentialsProvider = MockAuthCredentialsProvider();
    mockApiClient = MockAuthenticationApiClient();
    mockAuthEventBus = MockAuthEventBus();
    mockErrorHandler = MockErrorInterceptorHandler();

    // Initialize the AuthInterceptor with mocks
    authInterceptor = AuthInterceptor(
      refreshTokenFunction:
          (refreshToken) => mockApiClient.refreshToken(refreshToken),
      credentialsProvider: mockCredentialsProvider,
      dio: mockDio,
      authEventBus: mockAuthEventBus,
    );

    // Set up common mocks
    setupCommonMocks();
  });

  group('AuthInterceptor Token Refresh Integration Tests', () {
    group('Successful Token Refresh', () {
      test('should handle 401 and refresh token successfully', () async {
        // Arrange
        // Create a 401 error
        final dioError = createUnauthorizedError();
        final successResponse = createSuccessResponse(dioError.requestOptions);

        // Set up token refresh success
        setupTokenRefreshSuccess();

        // Mock Dio to return a success response when retried
        when(
          mockDio.fetch<dynamic>(any),
        ).thenAnswer((_) async => successResponse);

        // Act - call the error interceptor directly with the 401 error
        await authInterceptor.onError(dioError, mockErrorHandler);

        // Assert
        // Verify the refresh token flow
        verify(mockCredentialsProvider.getRefreshToken()).called(1);
        verify(mockApiClient.refreshToken(testRefreshToken)).called(1);
        verify(
          mockCredentialsProvider.setAccessToken(testNewAccessToken),
        ).called(1);
        verify(
          mockCredentialsProvider.setRefreshToken(testNewRefreshToken),
        ).called(1);

        // Verify the request was retried with new token
        final captured = verify(mockDio.fetch<dynamic>(captureAny)).captured;
        expect(captured.length, 1);
        RequestOptions retryOptions = captured.first;
        expect(
          retryOptions.headers['Authorization'],
          'Bearer $testNewAccessToken',
        );

        // Verify the success response was resolved
        verify(mockErrorHandler.resolve(successResponse)).called(1);

        // Verify no logout event was triggered
        verifyNever(mockAuthEventBus.add(AuthEvent.loggedOut));
      });
    });

    group('Refresh Token Failures', () {
      test('should trigger logout on refresh token invalid error', () async {
        // Arrange
        final dioError = createUnauthorizedError();

        // Mock API client to throw refresh token invalid exception
        when(
          mockApiClient.refreshToken(testRefreshToken),
        ).thenThrow(AuthException.refreshTokenInvalid());

        // Act - call the error interceptor directly with the 401 error
        await authInterceptor.onError(dioError, mockErrorHandler);

        // Assert
        // Verify the refresh token flow was attempted
        verify(mockCredentialsProvider.getRefreshToken()).called(1);
        verify(mockApiClient.refreshToken(testRefreshToken)).called(1);

        // Verify logout event was triggered
        verify(mockAuthEventBus.add(AuthEvent.loggedOut)).called(1);

        // Verify no token saving occurred
        verifyNever(mockCredentialsProvider.setAccessToken(any));
        verifyNever(mockCredentialsProvider.setRefreshToken(any));

        // Verify the original error was propagated
        verify(mockErrorHandler.next(dioError)).called(1);
      });

      test(
        'should create a new error and trigger logout for unexpected errors',
        () async {
          // Arrange
          final dioError = createUnauthorizedError();
          final unexpectedError = Exception('Unexpected error during refresh');

          // Mock API client to throw an unexpected error
          when(
            mockApiClient.refreshToken(testRefreshToken),
          ).thenThrow(unexpectedError);

          // Act - call the error interceptor directly with the 401 error
          await authInterceptor.onError(dioError, mockErrorHandler);

          // Assert
          // Verify the refresh token flow was attempted
          verify(mockCredentialsProvider.getRefreshToken()).called(1);
          verify(mockApiClient.refreshToken(testRefreshToken)).called(1);

          // Verify logout event was triggered for unexpected error
          verify(mockAuthEventBus.add(AuthEvent.loggedOut)).called(1);

          // Verify no token saving occurred
          verifyNever(mockCredentialsProvider.setAccessToken(any));
          verifyNever(mockCredentialsProvider.setRefreshToken(any));

          // Verify a new error was propagated (not the original one)
          final captor = verify(mockErrorHandler.next(captureAny)).captured;
          expect(captor.length, 1);
          final propagatedError = captor.first as DioException;
          expect(propagatedError.error, equals(unexpectedError));
          expect(propagatedError.type, equals(DioExceptionType.unknown));
          expect(
            propagatedError.message,
            contains('Unexpected error during refresh'),
          );
        },
      );
    });

    group('Retry Logic', () {
      test(
        'should retry with exponential backoff on network errors and eventually succeed',
        () async {
          // Arrange
          final dioError = createUnauthorizedError();
          final successResponse = createSuccessResponse(
            dioError.requestOptions,
          );

          when(
            mockCredentialsProvider.setAccessToken(testNewAccessToken),
          ).thenAnswer((_) async => {});
          when(
            mockCredentialsProvider.setRefreshToken(testNewRefreshToken),
          ).thenAnswer((_) async => {});

          // Set up network error for first two refresh attempts, then success
          var refreshAttempts = 0;
          when(mockApiClient.refreshToken(testRefreshToken)).thenAnswer((
            _,
          ) async {
            refreshAttempts++;
            if (refreshAttempts < 3) {
              throw AuthException.networkError();
            }
            return const AuthResponseDto(
              accessToken: testNewAccessToken,
              refreshToken: testNewRefreshToken,
              userId: testUserId,
            );
          });

          // Mock Dio to return a success response when retried
          when(
            mockDio.fetch<dynamic>(any),
          ).thenAnswer((_) async => successResponse);

          // Act - call the error interceptor with timing measurement
          final startTime = DateTime.now();
          await authInterceptor.onError(dioError, mockErrorHandler);
          final endTime = DateTime.now();

          // Assert
          // Verify timing for exponential backoff
          final duration = endTime.difference(startTime);
          expect(
            duration.inMilliseconds,
            greaterThan(1300),
          ); // Expected minimum delay: 500ms + 1000ms

          // Verify number of refresh attempts
          verify(mockApiClient.refreshToken(testRefreshToken)).called(3);

          // Verify tokens were saved after successful refresh
          verify(
            mockCredentialsProvider.setAccessToken(testNewAccessToken),
          ).called(1);
          verify(
            mockCredentialsProvider.setRefreshToken(testNewRefreshToken),
          ).called(1);

          // Verify the request was retried with new token
          final captured = verify(mockDio.fetch<dynamic>(captureAny)).captured;
          expect(captured.length, 1);
          RequestOptions retryOptions = captured.first;
          expect(
            retryOptions.headers['Authorization'],
            'Bearer $testNewAccessToken',
          );

          // Verify the success response was resolved
          verify(mockErrorHandler.resolve(successResponse)).called(1);

          // Verify no logout event
          verifyNever(mockAuthEventBus.add(AuthEvent.loggedOut));
        },
      );

      test(
        'should trigger logout after max retries with network errors',
        () async {
          // Arrange
          final dioError = createUnauthorizedError();

          // Mock API client to always throw network error
          when(
            mockApiClient.refreshToken(testRefreshToken),
          ).thenThrow(AuthException.networkError());

          // Act - call the error interceptor with the 401 error
          await authInterceptor.onError(dioError, mockErrorHandler);

          // Assert
          // Verify refresh was attempted the maximum number of times
          verify(mockApiClient.refreshToken(testRefreshToken)).called(3);

          // Verify logout event was triggered after max retries
          verify(mockAuthEventBus.add(AuthEvent.loggedOut)).called(1);

          // Verify no token saving occurred
          verifyNever(mockCredentialsProvider.setAccessToken(any));
          verifyNever(mockCredentialsProvider.setRefreshToken(any));

          // Verify no request retry was attempted
          verifyNever(mockDio.fetch<dynamic>(any));

          // Verify the original error was propagated
          verify(mockErrorHandler.next(dioError)).called(1);
        },
      );
    });

    group('Mutex Lock', () {
      test('should release the mutex lock even when errors occur', () async {
        // Arrange
        final dioError = createUnauthorizedError();

        // Mock getRefreshToken to throw an unexpected error
        when(
          mockCredentialsProvider.getRefreshToken(),
        ).thenThrow(Exception('Unexpected error before refresh'));

        // Act - first call should acquire the lock
        await authInterceptor.onError(dioError, mockErrorHandler);

        // Reset the mock for the second call
        reset(mockCredentialsProvider);
        when(
          mockCredentialsProvider.getApiKey(),
        ).thenAnswer((_) async => testApiKey);
        when(
          mockCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => testExpiredAccessToken);
        when(
          mockCredentialsProvider.getRefreshToken(),
        ).thenAnswer((_) async => testRefreshToken);

        // Set up for successful refresh on second attempt
        setupTokenRefreshSuccess();
        final successResponse = createSuccessResponse(dioError.requestOptions);
        when(
          mockDio.fetch<dynamic>(any),
        ).thenAnswer((_) async => successResponse);

        // Act - second call should succeed because the lock was released
        await authInterceptor.onError(dioError, mockErrorHandler);

        // Assert - verify the second call was successful
        verify(mockApiClient.refreshToken(testRefreshToken)).called(1);
        verify(
          mockCredentialsProvider.setAccessToken(testNewAccessToken),
        ).called(1);
        verify(mockErrorHandler.resolve(any)).called(1);
      });
    });
  });
}
