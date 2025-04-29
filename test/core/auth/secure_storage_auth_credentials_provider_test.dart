import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart'; // Import for PlatformException
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart';
import 'package:docjet_mobile/core/config/app_config.dart';

import 'package:docjet_mobile/core/auth/secure_storage_auth_credentials_provider.dart';

// Generate mocks for FlutterSecureStorage and JwtValidator
@GenerateMocks([FlutterSecureStorage, JwtValidator, AppConfig])
import 'secure_storage_auth_credentials_provider_test.mocks.dart';

void main() {
  late MockFlutterSecureStorage mockSecureStorage;
  late MockJwtValidator mockJwtValidator;
  late MockAppConfig mockAppConfig;
  late SecureStorageAuthCredentialsProvider provider;

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    mockJwtValidator = MockJwtValidator();
    mockAppConfig = MockAppConfig();
    provider = SecureStorageAuthCredentialsProvider(
      secureStorage: mockSecureStorage,
      jwtValidator: mockJwtValidator,
      appConfig: mockAppConfig,
    );
  });

  group('getAccessToken', () {
    test('should return token from secure storage when it exists', () async {
      // Arrange
      const expectedToken = 'test_access_token';
      when(
        mockSecureStorage.read(key: 'accessToken'),
      ).thenAnswer((_) async => expectedToken);

      // Act
      final result = await provider.getAccessToken();

      // Assert
      expect(result, equals(expectedToken));
      verify(mockSecureStorage.read(key: 'accessToken')).called(1);
    });

    test('should return null when token does not exist', () async {
      // Arrange
      when(
        mockSecureStorage.read(key: 'accessToken'),
      ).thenAnswer((_) async => null);

      // Act
      final result = await provider.getAccessToken();

      // Assert
      expect(result, isNull);
      verify(mockSecureStorage.read(key: 'accessToken')).called(1);
    });
  });

  group('getApiKey', () {
    // This test covers the case where the API_KEY is not defined via --dart-define
    // String.fromEnvironment will return an empty string, triggering the exception.
    test(
      'should throw exception when AppConfig provides an empty API key',
      () async {
        // Arrange
        // Stub AppConfig to return an empty key
        when(mockAppConfig.apiKey).thenReturn('');

        // Act & Assert
        expectLater(
          () => provider.getApiKey(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('API Key not found in AppConfig'),
            ),
          ),
        );
        // Verify apiKey was called
        verify(mockAppConfig.apiKey).called(1);
      },
    );

    // NEW TEST
    test('should return API key from AppConfig when provided', () async {
      // Arrange
      const expectedApiKey = 'api-key-from-config';
      // Setup the mock AppConfig to return the key
      when(mockAppConfig.apiKey).thenReturn(expectedApiKey);

      // Act
      final result = await provider.getApiKey();

      // Assert
      expect(result, equals(expectedApiKey));
      verify(mockAppConfig.apiKey).called(1);

      // TEMPORARY: Mark test as skipped until implementation is ready
      // markTestSkipped('Skipping test until SecureStorageAuthCredentialsProvider is updated to use AppConfig');
    });
  });

  group('setAccessToken', () {
    test('should store token in secure storage', () async {
      // Arrange
      const token = 'new_access_token';
      when(
        mockSecureStorage.write(key: 'accessToken', value: token),
      ).thenAnswer((_) async => {});

      // Act
      await provider.setAccessToken(token);

      // Assert
      verify(
        mockSecureStorage.write(key: 'accessToken', value: token),
      ).called(1);
    });
  });

  group('deleteAccessToken', () {
    test('should delete token from secure storage', () async {
      // Arrange
      when(
        mockSecureStorage.delete(key: 'accessToken'),
      ).thenAnswer((_) async => {});

      // Act
      await provider.deleteAccessToken();

      // Assert
      verify(mockSecureStorage.delete(key: 'accessToken')).called(1);
    });
  });

  group('isAccessTokenValid', () {
    test('should return true if access token exists and is valid', () async {
      // ARRANGE
      when(
        mockSecureStorage.read(key: 'accessToken'),
      ).thenAnswer((_) async => 'valid_token');
      when(mockJwtValidator.isTokenExpired('valid_token')).thenReturn(false);
      // ACT
      final result = await provider.isAccessTokenValid();
      // ASSERT
      expect(result, isTrue);
      verify(mockSecureStorage.read(key: 'accessToken'));
      verify(mockJwtValidator.isTokenExpired('valid_token'));
      verifyNoMoreInteractions(mockSecureStorage);
      verifyNoMoreInteractions(mockJwtValidator);
    });

    test('should return false if access token exists but is expired', () async {
      // ARRANGE
      when(
        mockSecureStorage.read(key: 'accessToken'),
      ).thenAnswer((_) async => 'expired_token');
      when(mockJwtValidator.isTokenExpired('expired_token')).thenReturn(true);
      // ACT
      final result = await provider.isAccessTokenValid();
      // ASSERT
      expect(result, isFalse);
      verify(mockSecureStorage.read(key: 'accessToken'));
      verify(mockJwtValidator.isTokenExpired('expired_token'));
      verifyNoMoreInteractions(mockSecureStorage);
      verifyNoMoreInteractions(mockJwtValidator);
    });

    test('should return false if access token does not exist', () async {
      // ARRANGE
      when(
        mockSecureStorage.read(key: 'accessToken'),
      ).thenAnswer((_) async => null);
      // ACT
      final result = await provider.isAccessTokenValid();
      // ASSERT
      expect(result, isFalse);
      verify(mockSecureStorage.read(key: 'accessToken'));
      verifyNoMoreInteractions(mockSecureStorage);
      verifyZeroInteractions(mockJwtValidator);
    });

    test('should return false if reading token throws error', () async {
      // ARRANGE
      when(
        mockSecureStorage.read(key: 'accessToken'),
      ).thenThrow(PlatformException(code: 'read_error'));
      // ACT
      final result = await provider.isAccessTokenValid();
      // ASSERT
      expect(result, isFalse);
      verify(mockSecureStorage.read(key: 'accessToken'));
      verifyNoMoreInteractions(mockSecureStorage);
      verifyZeroInteractions(mockJwtValidator);
    });

    test('should return false if validator throws error', () async {
      // ARRANGE
      when(
        mockSecureStorage.read(key: 'accessToken'),
      ).thenAnswer((_) async => 'invalid_token');
      when(
        mockJwtValidator.isTokenExpired('invalid_token'),
      ).thenThrow(const FormatException('bad token'));
      // ACT
      final result = await provider.isAccessTokenValid();
      // ASSERT
      expect(result, isFalse);
      verify(mockSecureStorage.read(key: 'accessToken'));
      verify(mockJwtValidator.isTokenExpired('invalid_token'));
      verifyNoMoreInteractions(mockSecureStorage);
      verifyNoMoreInteractions(mockJwtValidator);
    });
  });

  group('isRefreshTokenValid', () {
    test('should return true if refresh token exists and is valid', () async {
      // ARRANGE
      when(
        mockSecureStorage.read(key: 'refreshToken'),
      ).thenAnswer((_) async => 'valid_token');
      when(mockJwtValidator.isTokenExpired('valid_token')).thenReturn(false);
      // ACT
      final result = await provider.isRefreshTokenValid();
      // ASSERT
      expect(result, isTrue);
      verify(mockSecureStorage.read(key: 'refreshToken'));
      verify(mockJwtValidator.isTokenExpired('valid_token'));
      verifyNoMoreInteractions(mockSecureStorage);
      verifyNoMoreInteractions(mockJwtValidator);
    });

    test(
      'should return false if refresh token exists but is expired',
      () async {
        // ARRANGE
        when(
          mockSecureStorage.read(key: 'refreshToken'),
        ).thenAnswer((_) async => 'expired_token');
        when(mockJwtValidator.isTokenExpired('expired_token')).thenReturn(true);
        // ACT
        final result = await provider.isRefreshTokenValid();
        // ASSERT
        expect(result, isFalse);
        verify(mockSecureStorage.read(key: 'refreshToken'));
        verify(mockJwtValidator.isTokenExpired('expired_token'));
        verifyNoMoreInteractions(mockSecureStorage);
        verifyNoMoreInteractions(mockJwtValidator);
      },
    );

    test('should return false if refresh token does not exist', () async {
      // ARRANGE
      when(
        mockSecureStorage.read(key: 'refreshToken'),
      ).thenAnswer((_) async => null);
      // ACT
      final result = await provider.isRefreshTokenValid();
      // ASSERT
      expect(result, isFalse);
      verify(mockSecureStorage.read(key: 'refreshToken'));
      verifyNoMoreInteractions(mockSecureStorage);
      verifyZeroInteractions(mockJwtValidator);
    });
  });
}
