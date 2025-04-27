import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/infrastructure/authentication_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
import 'package:docjet_mobile/core/user/infrastructure/dtos/user_profile_dto.dart';
import 'package:docjet_mobile/core/user/infrastructure/user_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for dependencies
@GenerateMocks([
  AuthenticationApiClient,
  UserApiClient,
  AuthCredentialsProvider,
  AuthEventBus,
  Dio,
])
import 'auth_service_impl_test.mocks.dart';

void main() {
  late MockAuthenticationApiClient mockAuthenticationApiClient;
  late MockUserApiClient mockUserApiClient;
  late MockAuthCredentialsProvider mockCredentialsProvider;
  late MockAuthEventBus mockAuthEventBus;
  late AuthService authService;

  const testEmail = 'test@example.com';
  const testPassword = 'password123';
  const testAccessToken = 'test-access-token';
  const testRefreshToken = 'test-refresh-token';
  const testUserId = 'test-user-id';

  // Sample auth response
  final authResponse = AuthResponseDto(
    accessToken: testAccessToken,
    refreshToken: testRefreshToken,
    userId: testUserId,
  );

  // Sample user profile DTO
  final userProfileDto = UserProfileDto(
    id: testUserId,
    email: testEmail,
    name: 'Test User',
  );

  setUp(() {
    mockAuthenticationApiClient = MockAuthenticationApiClient();
    mockUserApiClient = MockUserApiClient();
    mockCredentialsProvider = MockAuthCredentialsProvider();
    mockAuthEventBus = MockAuthEventBus();

    authService = AuthServiceImpl(
      authenticationApiClient: mockAuthenticationApiClient,
      userApiClient: mockUserApiClient,
      credentialsProvider: mockCredentialsProvider,
      eventBus: mockAuthEventBus,
    );
  });

  group('login', () {
    test(
      'should return User, store tokens, and fire loggedIn event on successful login',
      () async {
        // Arrange
        when(
          mockAuthenticationApiClient.login(testEmail, testPassword),
        ).thenAnswer((_) async => authResponse);
        when(
          mockCredentialsProvider.setAccessToken(testAccessToken),
        ).thenAnswer((_) async => {});
        when(
          mockCredentialsProvider.setRefreshToken(testRefreshToken),
        ).thenAnswer((_) async => {});
        when(
          mockCredentialsProvider.setUserId(testUserId),
        ).thenAnswer((_) async => {});

        // Act
        final result = await authService.login(testEmail, testPassword);

        // Assert
        expect(result, isA<User>());
        expect(result.id, equals(testUserId));
        verify(
          mockAuthenticationApiClient.login(testEmail, testPassword),
        ).called(1);
        verify(
          mockCredentialsProvider.setAccessToken(testAccessToken),
        ).called(1);
        verify(
          mockCredentialsProvider.setRefreshToken(testRefreshToken),
        ).called(1);
        verify(mockCredentialsProvider.setUserId(testUserId)).called(1);
        verify(mockAuthEventBus.add(AuthEvent.loggedIn)).called(1);
      },
    );

    test('should propagate authentication exceptions', () async {
      // Arrange
      when(
        mockAuthenticationApiClient.login(testEmail, testPassword),
      ).thenThrow(AuthException.invalidCredentials());

      // Act & Assert
      expect(
        () => authService.login(testEmail, testPassword),
        throwsA(isA<AuthException>()),
      );
      verifyNever(mockAuthEventBus.add(any));
    });

    test('should propagate offline exceptions during login', () async {
      // Arrange
      when(
        mockAuthenticationApiClient.login(testEmail, testPassword),
      ).thenThrow(AuthException.offlineOperationFailed());

      // Act & Assert
      expect(
        () => authService.login(testEmail, testPassword),
        throwsA(
          predicate(
            (e) =>
                e is AuthException &&
                e == AuthException.offlineOperationFailed(),
          ),
        ),
      );
      verifyNever(mockAuthEventBus.add(any));
    });
  });

  group('refreshSession', () {
    test(
      'should successfully refresh tokens when valid refresh token exists',
      () async {
        // Arrange
        when(
          mockCredentialsProvider.getRefreshToken(),
        ).thenAnswer((_) async => testRefreshToken);
        when(
          mockAuthenticationApiClient.refreshToken(testRefreshToken),
        ).thenAnswer((_) async => authResponse);
        when(
          mockCredentialsProvider.setAccessToken(testAccessToken),
        ).thenAnswer((_) async => {});
        when(
          mockCredentialsProvider.setRefreshToken(testRefreshToken),
        ).thenAnswer((_) async => {});
        when(
          mockCredentialsProvider.setUserId(testUserId),
        ).thenAnswer((_) async => {});

        // Act
        final result = await authService.refreshSession();

        // Assert
        expect(result, isTrue);
        verify(mockCredentialsProvider.getRefreshToken()).called(1);
        verify(
          mockAuthenticationApiClient.refreshToken(testRefreshToken),
        ).called(1);
        verify(
          mockCredentialsProvider.setAccessToken(testAccessToken),
        ).called(1);
        verify(
          mockCredentialsProvider.setRefreshToken(testRefreshToken),
        ).called(1);
        verify(mockCredentialsProvider.setUserId(testUserId)).called(1);
      },
    );

    test('should return false when refresh token is missing', () async {
      // Arrange
      when(
        mockCredentialsProvider.getRefreshToken(),
      ).thenAnswer((_) async => null);

      // Act
      final result = await authService.refreshSession();

      // Assert
      expect(result, isFalse);
      verify(mockCredentialsProvider.getRefreshToken()).called(1);
      verifyNever(mockAuthenticationApiClient.refreshToken(any));
    });

    test('should return false when refresh token is invalid', () async {
      // Arrange
      when(
        mockCredentialsProvider.getRefreshToken(),
      ).thenAnswer((_) async => testRefreshToken);
      when(
        mockAuthenticationApiClient.refreshToken(testRefreshToken),
      ).thenThrow(AuthException.refreshTokenInvalid());

      // Act
      final result = await authService.refreshSession();

      // Assert
      expect(result, isFalse);
      verify(mockCredentialsProvider.getRefreshToken()).called(1);
      verify(
        mockAuthenticationApiClient.refreshToken(testRefreshToken),
      ).called(1);
    });

    test('should propagate offline exceptions during refresh', () async {
      // Arrange
      when(
        mockCredentialsProvider.getRefreshToken(),
      ).thenAnswer((_) async => testRefreshToken);
      when(
        mockAuthenticationApiClient.refreshToken(testRefreshToken),
      ).thenThrow(AuthException.offlineOperationFailed());

      // Act & Assert
      expect(
        () => authService.refreshSession(),
        throwsA(
          predicate(
            (e) =>
                e is AuthException &&
                e == AuthException.offlineOperationFailed(),
          ),
        ),
      );
    });
  });

  group('logout', () {
    test('should clear tokens and fire loggedOut event', () async {
      // Arrange
      when(
        mockCredentialsProvider.deleteAccessToken(),
      ).thenAnswer((_) async => {});
      when(
        mockCredentialsProvider.deleteRefreshToken(),
      ).thenAnswer((_) async => {});

      // Act
      await authService.logout();

      // Assert
      verify(mockCredentialsProvider.deleteAccessToken()).called(1);
      verify(mockCredentialsProvider.deleteRefreshToken()).called(1);
      verify(mockAuthEventBus.add(AuthEvent.loggedOut)).called(1);
    });
  });

  group('isAuthenticated', () {
    test(
      'should return true when access token exists (no validation)',
      () async {
        // Arrange
        when(
          mockCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => testAccessToken);

        // Act
        final result =
            await authService.isAuthenticated(); // Default: validate = false

        // Assert
        expect(result, isTrue);
        verify(mockCredentialsProvider.getAccessToken()).called(1);
        verifyNever(mockCredentialsProvider.isAccessTokenValid());
      },
    );

    test(
      'should return false when access token is missing (no validation)',
      () async {
        // Arrange
        when(
          mockCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => null);

        // Act
        final result =
            await authService.isAuthenticated(); // Default: validate = false

        // Assert
        expect(result, isFalse);
        verify(mockCredentialsProvider.getAccessToken()).called(1);
        verifyNever(mockCredentialsProvider.isAccessTokenValid());
      },
    );
  });

  group('isAuthenticated (with local validation)', () {
    test('should return true when token exists and is valid', () async {
      // Arrange
      when(
        mockCredentialsProvider.isAccessTokenValid(),
      ).thenAnswer((_) async => true);

      // Act
      final result = await authService.isAuthenticated(
        validateTokenLocally: true,
      );

      // Assert
      expect(result, isTrue);
      verify(mockCredentialsProvider.isAccessTokenValid()).called(1);
      verifyNever(mockCredentialsProvider.getAccessToken());
    });

    test('should return false when token exists but is invalid', () async {
      // Arrange
      when(
        mockCredentialsProvider.isAccessTokenValid(),
      ).thenAnswer((_) async => false);

      // Act
      final result = await authService.isAuthenticated(
        validateTokenLocally: true,
      );

      // Assert
      expect(result, isFalse);
      verify(mockCredentialsProvider.isAccessTokenValid()).called(1);
    });
  });

  group('getUserProfile', () {
    test('should return User when API call is successful', () async {
      // Arrange
      when(
        mockCredentialsProvider.getUserId(),
      ).thenAnswer((_) async => testUserId);
      when(
        mockUserApiClient.getUserProfile(),
      ).thenAnswer((_) async => userProfileDto);

      // Act
      final result = await authService.getUserProfile();

      // Assert
      expect(result, isA<User>());
      expect(result.id, testUserId);
      verify(mockCredentialsProvider.getUserId()).called(1);
      verify(mockUserApiClient.getUserProfile()).called(1);
    });

    test(
      'should throw unauthenticated if user ID cannot be determined',
      () async {
        // Arrange
        when(mockCredentialsProvider.getUserId()).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => authService.getUserProfile(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.toString(),
              'toString',
              'AuthException: Cannot get user profile: User ID not found.',
            ),
          ),
        );
        verify(mockCredentialsProvider.getUserId()).called(1);
        verifyNever(mockUserApiClient.getUserProfile());
      },
    );

    test('should throw userProfileFetchFailed on API client error', () async {
      // Arrange
      when(
        mockCredentialsProvider.getUserId(),
      ).thenAnswer((_) async => testUserId);
      when(
        mockUserApiClient.getUserProfile(),
      ).thenThrow(AuthException.userProfileFetchFailed());

      // Act & Assert
      expect(
        () => authService.getUserProfile(),
        throwsA(
          predicate(
            (e) =>
                e is AuthException &&
                e == AuthException.userProfileFetchFailed(),
          ),
        ),
      );
    });
  });

  group('getCurrentUserId', () {
    test('should retrieve user ID from credentials provider', () async {
      // Arrange
      when(
        mockCredentialsProvider.getUserId(),
      ).thenAnswer((_) async => testUserId);

      // Act
      final result = await authService.getCurrentUserId();

      // Assert
      expect(result, testUserId);
      verify(mockCredentialsProvider.getUserId()).called(1);
    });

    test('should throw unauthenticated if provider returns null', () async {
      // Arrange
      when(mockCredentialsProvider.getUserId()).thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => authService.getCurrentUserId(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.toString(),
            'toString',
            'AuthException: No authenticated user ID found',
          ),
        ),
      );
      verify(mockCredentialsProvider.getUserId()).called(1);
    });
  });
}
