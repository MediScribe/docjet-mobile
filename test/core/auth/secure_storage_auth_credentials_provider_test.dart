import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:docjet_mobile/core/auth/secure_storage_auth_credentials_provider.dart';

// Generate mocks for FlutterSecureStorage only
@GenerateMocks([FlutterSecureStorage])
import 'secure_storage_auth_credentials_provider_test.mocks.dart';

void main() {
  late MockFlutterSecureStorage mockSecureStorage;
  late SecureStorageAuthCredentialsProvider provider;

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    provider = SecureStorageAuthCredentialsProvider(
      secureStorage: mockSecureStorage,
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
    test('should throw exception when API key is not provided', () async {
      // Arrange
      // No arrangement needed, relies on API_KEY not being defined during test execution.

      // Act & Assert
      // Use expectLater for async throws check
      expectLater(() => provider.getApiKey(), throwsA(isA<Exception>()));
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
}
