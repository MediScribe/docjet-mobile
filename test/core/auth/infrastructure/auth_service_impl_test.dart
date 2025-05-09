import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/infrastructure/authentication_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/login_response_dto.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/refresh_response_dto.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/domain/repositories/i_user_profile_cache.dart';
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
  IUserProfileCache,
  Dio,
])
import 'auth_service_impl_test.mocks.dart';

void main() {
  late MockAuthenticationApiClient mockAuthenticationApiClient;
  late MockUserApiClient mockUserApiClient;
  late MockAuthCredentialsProvider mockCredentialsProvider;
  late MockAuthEventBus mockAuthEventBus;
  late MockIUserProfileCache mockUserProfileCache;
  late AuthService authService;

  const testEmail = 'test@example.com';
  const testPassword = 'password123';
  const testAccessToken = 'test-access-token';
  const testRefreshToken = 'test-refresh-token';
  const testUserId = 'test-user-id';

  // Sample auth response
  const authResponse = LoginResponseDto(
    accessToken: testAccessToken,
    refreshToken: testRefreshToken,
    userId: testUserId,
  );

  // Sample user profile DTO
  const userProfileDto = UserProfileDto(
    id: testUserId,
    email: testEmail,
    name: 'Test User',
  );

  setUp(() {
    mockAuthenticationApiClient = MockAuthenticationApiClient();
    mockUserApiClient = MockUserApiClient();
    mockCredentialsProvider = MockAuthCredentialsProvider();
    mockAuthEventBus = MockAuthEventBus();
    mockUserProfileCache = MockIUserProfileCache();

    // Provide default stubs for token retrieval to avoid MissingStubError in tests
    when(
      mockCredentialsProvider.getAccessToken(),
    ).thenAnswer((_) async => 'dummy-access-token');
    when(
      mockCredentialsProvider.getRefreshToken(),
    ).thenAnswer((_) async => 'dummy-refresh-token');

    authService = AuthServiceImpl(
      authenticationApiClient: mockAuthenticationApiClient,
      userApiClient: mockUserApiClient,
      credentialsProvider: mockCredentialsProvider,
      eventBus: mockAuthEventBus,
      userProfileCache: mockUserProfileCache,
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
        const correctRefreshResponse = RefreshResponseDto(
          accessToken: testAccessToken,
          refreshToken: testRefreshToken,
        );
        when(
          mockAuthenticationApiClient.refreshToken(testRefreshToken),
        ).thenAnswer((_) async => correctRefreshResponse);
        when(
          mockCredentialsProvider.setAccessToken(testAccessToken),
        ).thenAnswer((_) async => {});
        when(
          mockCredentialsProvider.setRefreshToken(testRefreshToken),
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
        verifyNever(mockCredentialsProvider.setUserId(any));
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

    test(
      'refreshSession should return true and update tokens on success (using specific vars)',
      () async {
        // Arrange
        const oldRefreshToken = 'old-refresh-token';
        const newAccessToken = 'new-access-token';
        const newRefreshToken = 'new-refresh-token';

        // Use RefreshResponseDto for the refresh mock response
        const refreshResponse = RefreshResponseDto(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );

        when(
          mockCredentialsProvider.getRefreshToken(),
        ).thenAnswer((_) async => oldRefreshToken);
        when(
          mockAuthenticationApiClient.refreshToken(oldRefreshToken),
        ).thenAnswer((_) async => refreshResponse);
        when(
          mockCredentialsProvider.setAccessToken(newAccessToken),
        ).thenAnswer((_) async => {});
        when(
          mockCredentialsProvider.setRefreshToken(newRefreshToken),
        ).thenAnswer((_) async => {});

        // Act
        final result = await authService.refreshSession();

        // Assert
        expect(result, isTrue);
        verify(mockCredentialsProvider.getRefreshToken()).called(1);
        verify(
          mockAuthenticationApiClient.refreshToken(oldRefreshToken),
        ).called(1);
        verify(
          mockCredentialsProvider.setAccessToken(newAccessToken),
        ).called(1);
        verify(
          mockCredentialsProvider.setRefreshToken(newRefreshToken),
        ).called(1);
        verifyNever(mockCredentialsProvider.setUserId(any));
      },
    );
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
      // Need user ID to clear specific cache
      when(
        mockCredentialsProvider.getUserId(),
      ).thenAnswer((_) async => testUserId);
      // Mock cache clear
      when(
        mockUserProfileCache.clearProfile(testUserId),
      ).thenAnswer((_) async => {});

      // Act
      await authService.logout();

      // Assert
      verify(mockCredentialsProvider.deleteAccessToken()).called(1);
      verify(mockCredentialsProvider.deleteRefreshToken()).called(1);
      // Verify cache was cleared AFTER getting user ID
      verify(mockCredentialsProvider.getUserId()).called(1);
      verify(mockUserProfileCache.clearProfile(testUserId)).called(1);
      verify(mockAuthEventBus.add(AuthEvent.loggedOut)).called(1);
    });

    test(
      'should still fire loggedOut event even if cache clear fails',
      () async {
        // Arrange
        when(
          mockCredentialsProvider.deleteAccessToken(),
        ).thenAnswer((_) async => {});
        when(
          mockCredentialsProvider.deleteRefreshToken(),
        ).thenAnswer((_) async => {});
        when(
          mockCredentialsProvider.getUserId(),
        ).thenAnswer((_) async => testUserId);
        // Mock cache clear to throw an error
        when(
          mockUserProfileCache.clearProfile(testUserId),
        ).thenThrow(Exception('Cache clear failed'));

        // Act
        // Should not throw, logout is best effort for cleanup
        await authService.logout();

        // Assert
        // Verify token deletion attempted
        verify(mockCredentialsProvider.deleteAccessToken()).called(1);
        verify(mockCredentialsProvider.deleteRefreshToken()).called(1);
        // Verify cache clear was attempted
        verify(mockCredentialsProvider.getUserId()).called(1);
        verify(mockUserProfileCache.clearProfile(testUserId)).called(1);
        // Crucially, verify event was still fired
        verify(mockAuthEventBus.add(AuthEvent.loggedOut)).called(1);
      },
    );
  });

  group('isAuthenticated', () {
    test('should return true when access token exists (no validation)', () async {
      // Arrange
      // Generate a token that expires in 1 hour to ensure it's outside the 30s skew window
      String validJwt() {
        final header = base64Url.encode(
          utf8.encode('{"alg":"HS256","typ":"JWT"}'),
        );
        final payload = base64Url.encode(
          utf8.encode(
            '{"exp":${(DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000)}}',
          ),
        );
        return '$header.$payload.signature';
      }

      when(
        mockCredentialsProvider.getAccessToken(),
      ).thenAnswer((_) async => validJwt());

      // Act
      final result =
          await authService.isAuthenticated(); // Default: validate = false

      // Assert
      expect(result, isTrue);
      verify(mockCredentialsProvider.getAccessToken()).called(1);
      verifyNever(mockCredentialsProvider.isAccessTokenValid());
      verifyNever(mockCredentialsProvider.isRefreshTokenValid());
      verifyNever(mockAuthenticationApiClient.refreshToken(any));
    });

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
        verifyNever(mockCredentialsProvider.isRefreshTokenValid());
        verifyNever(mockAuthenticationApiClient.refreshToken(any));
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

  group('isAuthenticated (expiry fast-path with 30s skew)', () {
    /// Helper to generate a fake JWT with a given expiration time.
    String generateJwt({required DateTime exp}) {
      final header = base64Url.encode(
        utf8.encode('{"alg":"HS256","typ":"JWT"}'),
      );
      final payload = base64Url.encode(
        utf8.encode('{"exp":${(exp.millisecondsSinceEpoch ~/ 1000)}}'),
      );
      // Use a dummy signature – the app never verifies it locally.
      return '$header.$payload.signature';
    }

    test(
      'returns false when access token already expired (>=30s past)',
      () async {
        // Arrange – token expired 1 minute ago
        final expiredToken = generateJwt(
          exp: DateTime.now().subtract(const Duration(minutes: 1)),
        );
        when(
          mockCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => expiredToken);

        // Act
        final result = await authService.isAuthenticated();

        // Assert
        expect(result, isFalse);
        verify(mockCredentialsProvider.getAccessToken()).called(1);
        verifyNever(mockCredentialsProvider.isAccessTokenValid());
        verifyNever(mockCredentialsProvider.isRefreshTokenValid());
        verifyNever(mockAuthenticationApiClient.refreshToken(any));
      },
    );

    test(
      'triggers refresh when access token expires within next 30s',
      () async {
        // Arrange – token expires in 15 seconds (inside skew window)
        final nearExpiryToken = generateJwt(
          exp: DateTime.now().add(const Duration(seconds: 15)),
        );
        when(
          mockCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => nearExpiryToken);
        // Provide refresh token for refresh flow
        const testRefreshToken = 'dummyRefreshToken';
        when(
          mockCredentialsProvider.getRefreshToken(),
        ).thenAnswer((_) async => testRefreshToken);
        // Stub refreshToken API response
        final newTokens = RefreshResponseDto(
          accessToken: 'newAccess',
          refreshToken: 'newRefresh',
        );
        when(
          mockAuthenticationApiClient.refreshToken(testRefreshToken),
        ).thenAnswer((_) async => newTokens);
        // Allow credential writes to succeed
        when(
          mockCredentialsProvider.setAccessToken(any),
        ).thenAnswer((_) async => {});
        when(
          mockCredentialsProvider.setRefreshToken(any),
        ).thenAnswer((_) async => {});

        // Act
        final result = await authService.isAuthenticated();

        // Assert
        expect(result, isTrue);
        // Verify refresh path triggered exactly once
        verify(mockCredentialsProvider.getRefreshToken()).called(1);
        verify(
          mockAuthenticationApiClient.refreshToken(testRefreshToken),
        ).called(1);
      },
    );

    test('returns false when JWT parsing fails (malformed token)', () async {
      // Arrange
      when(
        mockCredentialsProvider.getAccessToken(),
      ).thenAnswer((_) async => 'not.a.jwt');

      // Act
      final result = await authService.isAuthenticated();

      // Assert
      expect(result, isFalse);
      verify(mockCredentialsProvider.getAccessToken()).called(1);
      verifyNever(mockCredentialsProvider.isAccessTokenValid());
      verifyNever(mockCredentialsProvider.isRefreshTokenValid());
      verifyNever(mockAuthenticationApiClient.refreshToken(any));
    });

    test('returns false when near-expiry refresh fails', () async {
      // Arrange – token expires in 10 seconds (inside skew window)
      final nearExpiryToken = generateJwt(
        exp: DateTime.now().add(const Duration(seconds: 10)),
      );
      when(
        mockCredentialsProvider.getAccessToken(),
      ).thenAnswer((_) async => nearExpiryToken);

      // Provide refresh token but simulate API failure
      const testRefreshToken = 'dummyRefreshToken';
      when(
        mockCredentialsProvider.getRefreshToken(),
      ).thenAnswer((_) async => testRefreshToken);
      when(
        mockAuthenticationApiClient.refreshToken(testRefreshToken),
      ).thenThrow(AuthException.refreshTokenInvalid());

      // Act
      final result = await authService.isAuthenticated();

      // Assert
      expect(result, isFalse);
      verify(mockCredentialsProvider.getRefreshToken()).called(1);
      verify(
        mockAuthenticationApiClient.refreshToken(testRefreshToken),
      ).called(1);
      verifyNever(mockCredentialsProvider.isAccessTokenValid());
      verifyNever(mockCredentialsProvider.isRefreshTokenValid());
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

  // NEW: Group for getUserProfile with caching logic
  group('getUserProfile (with caching)', () {
    test(
      'should save profile to cache with current timestamp on successful API fetch',
      () async {
        // Arrange
        when(
          mockCredentialsProvider.getUserId(),
        ).thenAnswer((_) async => testUserId);
        when(
          mockUserApiClient.getUserProfile(),
        ).thenAnswer((_) async => userProfileDto);
        when(
          mockUserProfileCache.saveProfile(any, any),
        ).thenAnswer((_) async => {});

        // Act
        final result = await authService.getUserProfile();

        // Assert
        expect(result, isA<User>());
        expect(result.id, testUserId);
        verify(mockCredentialsProvider.getUserId()).called(1);
        verify(mockUserApiClient.getUserProfile()).called(1);

        // Verify cache save was called with the correct DTO and a recent timestamp
        final verificationResult =
            verify(
              mockUserProfileCache.saveProfile(captureAny, captureAny),
            ).captured;

        final capturedDto = verificationResult[0] as UserProfileDto;
        final capturedTimestamp = verificationResult[1] as DateTime;

        expect(capturedDto.id, userProfileDto.id);
        expect(capturedDto.email, userProfileDto.email);
        // Check timestamp is recent (e.g., within the last 5 seconds)
        expect(
          DateTime.now().difference(capturedTimestamp).inSeconds,
          lessThan(5),
        );
      },
    );

    test(
      'should return User from cache when API fails (offline) and acceptOfflineProfile is true',
      () async {
        // Arrange
        final offlineException = AuthException.offlineOperationFailed();
        when(
          mockCredentialsProvider.getUserId(),
        ).thenAnswer((_) async => testUserId);
        when(mockUserApiClient.getUserProfile()).thenThrow(offlineException);
        when(
          mockCredentialsProvider.isAccessTokenValid(),
        ).thenAnswer((_) async => true);
        when(
          mockCredentialsProvider.isRefreshTokenValid(),
        ).thenAnswer((_) async => true);
        when(
          mockUserProfileCache.getProfile(testUserId),
        ).thenAnswer((_) async => userProfileDto);

        // Act
        final result = await authService.getUserProfile(
          acceptOfflineProfile: true,
        );

        // Assert FIRST verify calls, THEN check result
        verify(mockCredentialsProvider.getUserId()).called(1);
        verify(mockUserApiClient.getUserProfile()).called(1);
        verify(mockCredentialsProvider.isAccessTokenValid()).called(1);
        verify(mockCredentialsProvider.isRefreshTokenValid()).called(1);
        verify(mockUserProfileCache.getProfile(testUserId)).called(1);
        verifyNever(mockUserProfileCache.saveProfile(any, any));
        verifyNever(mockUserProfileCache.clearProfile(any));

        // THEN check result
        expect(result, isA<User>());
        expect(result.id, userProfileDto.id);
      },
    );

    test(
      'should throw offline exception when API fails (offline) and acceptOfflineProfile is false',
      () async {
        // Arrange
        final offlineException = AuthException.offlineOperationFailed();
        when(
          mockCredentialsProvider.getUserId(),
        ).thenAnswer((_) async => testUserId);
        when(mockUserApiClient.getUserProfile()).thenThrow(offlineException);

        // Act
        AuthException? thrownException;
        try {
          await authService.getUserProfile(acceptOfflineProfile: false);
        } on AuthException catch (e) {
          thrownException = e;
        }

        // Assert
        expect(thrownException, isNotNull);
        expect(thrownException, equals(offlineException));

        // Verify API was called, but cache and token checks were NOT
        verify(mockCredentialsProvider.getUserId()).called(1);
        verify(mockUserApiClient.getUserProfile()).called(1); // Restored verify
        verifyNever(mockCredentialsProvider.isAccessTokenValid());
        verifyNever(mockCredentialsProvider.isRefreshTokenValid());
        verifyNever(mockUserProfileCache.getProfile(any));
        verifyNever(mockUserProfileCache.saveProfile(any, any));
        verifyNever(mockUserProfileCache.clearProfile(any));
      },
    );

    test(
      'should clear cache and throw unauthenticated when API fails (offline) and both tokens are invalid',
      () async {
        // Arrange
        final offlineException = AuthException.offlineOperationFailed();
        when(
          mockCredentialsProvider.getUserId(),
        ).thenAnswer((_) async => testUserId);
        when(mockUserApiClient.getUserProfile()).thenThrow(offlineException);
        when(
          mockCredentialsProvider.isAccessTokenValid(),
        ).thenAnswer((_) async => false);
        when(
          mockCredentialsProvider.isRefreshTokenValid(),
        ).thenAnswer((_) async => false);
        when(
          mockUserProfileCache.clearProfile(testUserId),
        ).thenAnswer((_) async => {});

        // Act
        AuthException? thrownException;
        try {
          await authService.getUserProfile(acceptOfflineProfile: true);
        } on AuthException catch (e) {
          thrownException = e;
        }

        // Assert
        expect(
          thrownException,
          isA<AuthException>().having(
            (e) => e.toString(),
            'toString',
            contains('Offline check failed'),
          ),
        );

        // Verify API was called, then token checks, then cache clear
        verify(mockCredentialsProvider.getUserId()).called(1);
        verify(mockUserApiClient.getUserProfile()).called(1);
        verify(mockCredentialsProvider.isAccessTokenValid()).called(1);
        verify(mockCredentialsProvider.isRefreshTokenValid()).called(1);
        verify(
          mockUserProfileCache.clearProfile(testUserId),
        ).called(1); // Restored verify
        verifyNever(mockUserProfileCache.getProfile(any));
        verifyNever(mockUserProfileCache.saveProfile(any, any));
      },
    );

    test(
      'should NOT clear cache but return cached profile when API fails (offline) and only one token is invalid',
      () async {
        // Arrange
        final offlineException = AuthException.offlineOperationFailed();
        when(
          mockCredentialsProvider.getUserId(),
        ).thenAnswer((_) async => testUserId);
        when(mockUserApiClient.getUserProfile()).thenThrow(offlineException);
        // Access token invalid, Refresh token VALID
        when(
          mockCredentialsProvider.isAccessTokenValid(),
        ).thenAnswer((_) async => false);
        when(
          mockCredentialsProvider.isRefreshTokenValid(),
        ).thenAnswer((_) async => true); // Refresh token is still good!
        // Cache has the profile
        when(
          mockUserProfileCache.getProfile(testUserId),
        ).thenAnswer((_) async => userProfileDto);

        // Act
        final result = await authService.getUserProfile(
          acceptOfflineProfile: true,
        );

        // Assert FIRST verify calls, THEN check result
        verify(mockCredentialsProvider.getUserId()).called(1);
        verify(mockUserApiClient.getUserProfile()).called(1);
        verify(mockCredentialsProvider.isAccessTokenValid()).called(1);
        verify(mockCredentialsProvider.isRefreshTokenValid()).called(1);
        verify(mockUserProfileCache.getProfile(testUserId)).called(1);
        verifyNever(mockUserProfileCache.clearProfile(any));
        verifyNever(mockUserProfileCache.saveProfile(any, any));

        // THEN check result
        expect(result, isA<User>());
        expect(result.id, userProfileDto.id);
      },
    );
  });
}
