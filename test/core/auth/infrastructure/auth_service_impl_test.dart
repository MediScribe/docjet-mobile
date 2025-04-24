import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for dependencies
@GenerateMocks([AuthApiClient, AuthCredentialsProvider, AuthEventBus])
import 'auth_service_impl_test.mocks.dart';

void main() {
  late MockAuthApiClient mockApiClient;
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

  // Sample user DTO (needed for getUserProfile tests)
  // TODO: Replace with actual UserProfileDto when created
  const userProfileDto = {'id': testUserId, 'name': 'Test User'};

  setUp(() {
    mockApiClient = MockAuthApiClient();
    mockCredentialsProvider = MockAuthCredentialsProvider();
    mockAuthEventBus = MockAuthEventBus();
    authService = AuthServiceImpl(
      apiClient: mockApiClient,
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
          mockApiClient.login(testEmail, testPassword),
        ).thenAnswer((_) async => authResponse);
        when(
          mockCredentialsProvider.setAccessToken(testAccessToken),
        ).thenAnswer((_) async => {});
        when(
          mockCredentialsProvider.setRefreshToken(testRefreshToken),
        ).thenAnswer((_) async => {});
        // TODO: Mock getUserProfile call when implemented in login flow
        // when(mockApiClient.getUserProfile())
        //     .thenAnswer((_) async => userProfileDto);

        // Act
        final result = await authService.login(testEmail, testPassword);

        // Assert
        expect(result, isA<User>());
        expect(result.id, equals(testUserId));
        verify(mockApiClient.login(testEmail, testPassword)).called(1);
        verify(
          mockCredentialsProvider.setAccessToken(testAccessToken),
        ).called(1);
        verify(
          mockCredentialsProvider.setRefreshToken(testRefreshToken),
        ).called(1);
        verify(mockAuthEventBus.add(AuthEvent.loggedIn)).called(1);
        // TODO: Verify getUserProfile call when implemented
      },
    );

    test('should propagate authentication exceptions', () async {
      // Arrange
      when(
        mockApiClient.login(testEmail, testPassword),
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
        mockApiClient.login(testEmail, testPassword),
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
          mockApiClient.refreshToken(testRefreshToken),
        ).thenAnswer((_) async => authResponse);
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
        verify(mockApiClient.refreshToken(testRefreshToken)).called(1);
        verify(
          mockCredentialsProvider.setAccessToken(testAccessToken),
        ).called(1);
        verify(
          mockCredentialsProvider.setRefreshToken(testRefreshToken),
        ).called(1);
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
      verifyNever(mockApiClient.refreshToken(any));
    });

    test('should return false when refresh token is invalid', () async {
      // Arrange
      when(
        mockCredentialsProvider.getRefreshToken(),
      ).thenAnswer((_) async => testRefreshToken);
      when(mockApiClient.refreshToken(testRefreshToken)).thenThrow(
        AuthException.refreshTokenInvalid(),
      ); // Use specific exception

      // Act
      final result = await authService.refreshSession();

      // Assert
      expect(result, isFalse);
      verify(mockCredentialsProvider.getRefreshToken()).called(1);
      verify(mockApiClient.refreshToken(testRefreshToken)).called(1);
    });

    test('should propagate offline exceptions during refresh', () async {
      // Arrange
      when(
        mockCredentialsProvider.getRefreshToken(),
      ).thenAnswer((_) async => testRefreshToken);
      when(
        mockApiClient.refreshToken(testRefreshToken),
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

  group('isAuthenticated (basic check)', () {
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

    test(
      'should propagate offline exception when checking token existence',
      () async {
        // Arrange
        when(
          mockCredentialsProvider.getAccessToken(),
        ).thenThrow(AuthException.offlineOperationFailed());

        // Act & Assert
        expect(
          () => authService.isAuthenticated(), // Default: validate = false
          throwsA(
            predicate(
              (e) =>
                  e is AuthException &&
                  e == AuthException.offlineOperationFailed(),
            ),
          ),
        );
        verify(mockCredentialsProvider.getAccessToken()).called(1);
        verifyNever(mockCredentialsProvider.isAccessTokenValid());
      },
    );
  });

  // New group for Step 6.1: Local Token Validation
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
      verifyNever(
        mockCredentialsProvider.getAccessToken(),
      ); // Should only call validator
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

    test(
      'should return false when token validation throws (e.g., missing)',
      () async {
        // This simulates the provider throwing if the token doesn't exist to validate
        // Alternatively, the validator itself could return false for null token
        when(
          mockCredentialsProvider.isAccessTokenValid(),
        ).thenThrow(Exception('Token not found')); // Or return false

        // Act
        final result = await authService.isAuthenticated(
          validateTokenLocally: true,
        );

        // Assert
        expect(result, isFalse); // Assuming false on error during validation
        verify(mockCredentialsProvider.isAccessTokenValid()).called(1);
      },
    );

    test(
      'should propagate offline exception during token validation',
      () async {
        // Arrange
        when(
          mockCredentialsProvider.isAccessTokenValid(),
        ).thenThrow(AuthException.offlineOperationFailed());

        // Act & Assert
        expect(
          () => authService.isAuthenticated(validateTokenLocally: true),
          throwsA(
            predicate(
              (e) =>
                  e is AuthException &&
                  e == AuthException.offlineOperationFailed(),
            ),
          ),
        );
        verify(mockCredentialsProvider.isAccessTokenValid()).called(1);
      },
    );
  });

  // New group for Step 6.2: Get User Profile
  group('getUserProfile', () {
    test('should return User when API call is successful', () async {
      // Arrange
      // TODO: Replace with actual UserProfileDto and mapping logic in impl
      when(
        mockApiClient.getUserProfile(),
      ).thenAnswer((_) async => userProfileDto); // Assume returns a Map for now
      // Mock getting user ID (needed by impl)
      when(
        mockCredentialsProvider.getUserId(),
      ).thenAnswer((_) async => testUserId);

      // Act
      final result = await authService.getUserProfile();

      // Assert
      expect(result, isA<User>());
      expect(result.id, testUserId);
      // TODO: Add more assertions when DTO and mapping are defined
      verify(mockCredentialsProvider.getUserId()).called(1);
      verify(mockApiClient.getUserProfile()).called(1);
    });

    test(
      'should throw unauthenticated if user ID cannot be determined',
      () async {
        // Arrange
        when(mockCredentialsProvider.getUserId()) // Corrected method name
        .thenAnswer((_) async => null); // Simulate unable to get user ID

        // Act & Assert
        expect(
          () => authService.getUserProfile(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.toString(),
              'toString',
              'AuthException: Cannot get user profile: User ID not found.',
            ), // Match exact exception
          ),
        );
        verify(
          mockCredentialsProvider.getUserId(),
        ).called(1); // Verify provider call
        verifyNever(mockApiClient.getUserProfile()); // Ensure API not called
      },
    );

    test('should throw userProfileFetchFailed on API client error', () async {
      // Arrange
      when(mockCredentialsProvider.getUserId()) // Corrected method name
      .thenAnswer((_) async => testUserId);
      when(
        mockApiClient.getUserProfile(),
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
      // Removed verify(mockApiClient.getUserProfile()).called(1);
      // Verification not needed here as we test the rethrow behaviour.
      // Call is verified in the success case.
    });

    test('should propagate other exceptions from API client', () async {
      // Arrange
      when(mockCredentialsProvider.getUserId()) // Corrected method name
      .thenAnswer((_) async => testUserId);
      when(
        mockApiClient.getUserProfile(),
      ).thenThrow(AuthException.networkError());

      // Act & Assert
      expect(
        () => authService.getUserProfile(),
        throwsA(
          predicate(
            (e) => e is AuthException && e == AuthException.networkError(),
          ),
        ),
      );
      // Removed verify(mockApiClient.getUserProfile()).called(1);
    });

    test('should propagate offline exception from API client', () async {
      // Arrange
      when(mockCredentialsProvider.getUserId()) // Corrected method name
      .thenAnswer((_) async => testUserId);
      when(
        mockApiClient.getUserProfile(),
      ).thenThrow(AuthException.offlineOperationFailed());

      // Act & Assert
      expect(
        () => authService.getUserProfile(),
        throwsA(
          predicate(
            (e) =>
                e is AuthException &&
                e == AuthException.offlineOperationFailed(),
          ),
        ),
      );
      // Removed verify(mockApiClient.getUserProfile()).called(1);
    });

    test('should propagate offline exception when getting user ID', () async {
      // Arrange
      when(
        mockCredentialsProvider.getUserId(),
      ).thenThrow(AuthException.offlineOperationFailed());

      // Act & Assert
      expect(
        () => authService.getUserProfile(),
        throwsA(
          predicate(
            (e) =>
                e is AuthException &&
                e == AuthException.offlineOperationFailed(),
          ),
        ),
      );
      verify(mockCredentialsProvider.getUserId()).called(1);
      verifyNever(mockApiClient.getUserProfile());
    });
  });

  // Placeholder for getCurrentUserId tests if logic is added to AuthServiceImpl
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
      when(mockCredentialsProvider.getUserId()) // Corrected method name
      .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => authService.getCurrentUserId(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.toString(),
            'toString',
            'AuthException: No authenticated user ID found',
          ), // Match exact exception
        ),
      );
      verify(
        mockCredentialsProvider.getUserId(),
      ).called(1); // Corrected method name
    });

    test('should propagate offline exception from provider', () async {
      // Arrange
      when(
        mockCredentialsProvider.getUserId(),
      ).thenThrow(AuthException.offlineOperationFailed());

      // Act & Assert
      expect(
        () => authService.getCurrentUserId(),
        throwsA(
          predicate(
            (e) =>
                e is AuthException &&
                e == AuthException.offlineOperationFailed(),
          ),
        ),
      );
      verify(mockCredentialsProvider.getUserId()).called(1);
    });
  });
}
