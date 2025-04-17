import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for dependencies
@GenerateMocks([AuthApiClient, AuthCredentialsProvider])
import 'auth_service_impl_test.mocks.dart';

void main() {
  late MockAuthApiClient mockApiClient;
  late MockAuthCredentialsProvider mockCredentialsProvider;
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

  setUp(() {
    mockApiClient = MockAuthApiClient();
    mockCredentialsProvider = MockAuthCredentialsProvider();
    authService = AuthServiceImpl(
      apiClient: mockApiClient,
      credentialsProvider: mockCredentialsProvider,
    );
  });

  group('login', () {
    test('should return User and store tokens on successful login', () async {
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

      // Act
      final result = await authService.login(testEmail, testPassword);

      // Assert
      expect(result, isA<User>());
      expect(result.id, equals(testUserId));
      verify(mockApiClient.login(testEmail, testPassword)).called(1);
      verify(mockCredentialsProvider.setAccessToken(testAccessToken)).called(1);
      verify(
        mockCredentialsProvider.setRefreshToken(testRefreshToken),
      ).called(1);
    });

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
      when(
        mockApiClient.refreshToken(testRefreshToken),
      ).thenThrow(AuthException.tokenExpired());

      // Act
      final result = await authService.refreshSession();

      // Assert
      expect(result, isFalse);
      verify(mockCredentialsProvider.getRefreshToken()).called(1);
      verify(mockApiClient.refreshToken(testRefreshToken)).called(1);
    });
  });

  group('logout', () {
    test('should clear tokens', () async {
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
    });
  });

  group('isAuthenticated', () {
    test('should return true when access token exists', () async {
      // Arrange
      when(
        mockCredentialsProvider.getAccessToken(),
      ).thenAnswer((_) async => testAccessToken);

      // Act
      final result = await authService.isAuthenticated();

      // Assert
      expect(result, isTrue);
      verify(mockCredentialsProvider.getAccessToken()).called(1);
    });

    test('should return false when access token is missing', () async {
      // Arrange
      when(
        mockCredentialsProvider.getAccessToken(),
      ).thenAnswer((_) async => null);

      // Act
      final result = await authService.isAuthenticated();

      // Assert
      expect(result, isFalse);
      verify(mockCredentialsProvider.getAccessToken()).called(1);
    });
  });
}
