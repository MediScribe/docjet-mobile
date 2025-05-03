import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/infrastructure/authentication_api_client.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/domain/repositories/i_user_profile_cache.dart';
import 'package:docjet_mobile/core/user/infrastructure/user_api_client.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'auth_service_impl_test.mocks.dart';

// Re-using mocks from auth_service_impl_test
@GenerateMocks([
  AuthenticationApiClient,
  UserApiClient,
  AuthCredentialsProvider,
  AuthEventBus,
  IUserProfileCache,
])
void main() {
  group('AuthService Offline Error Classification Tests', () {
    late MockAuthenticationApiClient mockAuthenticationApiClient;
    late MockUserApiClient mockUserApiClient;
    late MockAuthCredentialsProvider mockCredentialsProvider;
    late MockAuthEventBus mockEventBus;
    late MockIUserProfileCache mockUserProfileCache;
    late AuthServiceImpl authService;

    const testUserId = 'test-user-id';

    setUp(() {
      mockAuthenticationApiClient = MockAuthenticationApiClient();
      mockUserApiClient = MockUserApiClient();
      mockCredentialsProvider = MockAuthCredentialsProvider();
      mockEventBus = MockAuthEventBus();
      mockUserProfileCache = MockIUserProfileCache();

      // Wire up the service with our mocks
      authService = AuthServiceImpl(
        authenticationApiClient: mockAuthenticationApiClient,
        userApiClient: mockUserApiClient,
        credentialsProvider: mockCredentialsProvider,
        eventBus: mockEventBus,
        userProfileCache: mockUserProfileCache,
      );

      // Default setup: User is authenticated
      when(
        mockCredentialsProvider.getUserId(),
      ).thenAnswer((_) async => testUserId);
    });

    group('UserApiClient DioException Classification', () {
      test('SHOULD classify connection errors as offlineOperation', () async {
        // Arrange
        final connectionError = DioException(
          requestOptions: RequestOptions(path: '/users/profile'),
          error: 'Connection refused',
          type: DioExceptionType.connectionError,
        );

        when(mockUserApiClient.getUserProfile()).thenThrow(connectionError);

        // Act
        try {
          await authService.getUserProfile(acceptOfflineProfile: false);
          fail('Should have thrown an exception');
        } on AuthException catch (e) {
          // Assert
          expect(e.type, equals(AuthErrorType.offlineOperation));
          expect(e.message, contains('Operation failed due to being offline'));
        }
      });

      test('SHOULD classify send timeout as offlineOperation', () async {
        // Arrange
        final timeoutError = DioException(
          requestOptions: RequestOptions(path: '/users/profile'),
          error: 'Send timeout',
          type: DioExceptionType.sendTimeout,
        );

        when(mockUserApiClient.getUserProfile()).thenThrow(timeoutError);

        // Act
        try {
          await authService.getUserProfile(acceptOfflineProfile: false);
          fail('Should have thrown an exception');
        } on AuthException catch (e) {
          // Assert
          expect(e.type, equals(AuthErrorType.offlineOperation));
          expect(e.message, contains('Operation failed due to being offline'));
        }
      });

      test('SHOULD classify receive timeout as offlineOperation', () async {
        // Arrange
        final timeoutError = DioException(
          requestOptions: RequestOptions(path: '/users/profile'),
          error: 'Receive timeout',
          type: DioExceptionType.receiveTimeout,
        );

        when(mockUserApiClient.getUserProfile()).thenThrow(timeoutError);

        // Act
        try {
          await authService.getUserProfile(acceptOfflineProfile: false);
          fail('Should have thrown an exception');
        } on AuthException catch (e) {
          // Assert
          expect(e.type, equals(AuthErrorType.offlineOperation));
          expect(e.message, contains('Operation failed due to being offline'));
        }
      });

      test('SHOULD classify connection timeout as offlineOperation', () async {
        // Arrange
        final timeoutError = DioException(
          requestOptions: RequestOptions(path: '/users/profile'),
          error: 'Connection timeout',
          type: DioExceptionType.connectionTimeout,
        );

        when(mockUserApiClient.getUserProfile()).thenThrow(timeoutError);

        // Act
        try {
          await authService.getUserProfile(acceptOfflineProfile: false);
          fail('Should have thrown an exception');
        } on AuthException catch (e) {
          // Assert
          expect(e.type, equals(AuthErrorType.offlineOperation));
          expect(e.message, contains('Operation failed due to being offline'));
        }
      });

      test(
        'should keep badCertificate as userProfileFetchFailed (control)',
        () async {
          // Arrange
          final certError = DioException(
            requestOptions: RequestOptions(path: '/users/profile'),
            error: 'Bad certificate',
            type: DioExceptionType.badCertificate,
          );

          when(mockUserApiClient.getUserProfile()).thenThrow(certError);

          // Act
          try {
            await authService.getUserProfile(acceptOfflineProfile: false);
            fail('Should have thrown an exception');
          } on AuthException catch (e) {
            // Assert
            expect(e.type, equals(AuthErrorType.userProfileFetchFailed));
            expect(e.message, contains('Failed to fetch user profile'));
          }
        },
      );

      test(
        'should keep HTTP 500 as userProfileFetchFailed (control)',
        () async {
          // Arrange
          final serverError = DioException(
            requestOptions: RequestOptions(path: '/users/profile'),
            response: Response(
              statusCode: 500,
              requestOptions: RequestOptions(path: '/users/profile'),
            ),
            type: DioExceptionType.badResponse,
          );

          when(mockUserApiClient.getUserProfile()).thenThrow(serverError);

          // Act
          try {
            await authService.getUserProfile(acceptOfflineProfile: false);
            fail('Should have thrown an exception');
          } on AuthException catch (e) {
            // Assert
            expect(e.type, equals(AuthErrorType.userProfileFetchFailed));
            expect(e.message, contains('Failed to fetch user profile'));
          }
        },
      );
    });
  });
}
