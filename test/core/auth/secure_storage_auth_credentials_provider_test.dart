import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:docjet_mobile/core/auth/secure_storage_auth_credentials_provider.dart';

// Generate mocks
@GenerateMocks([FlutterSecureStorage, EnvReader])
import 'secure_storage_auth_credentials_provider_test.mocks.dart';

void main() {
  late MockFlutterSecureStorage mockSecureStorage;
  late MockEnvReader mockEnvReader;
  late SecureStorageAuthCredentialsProvider provider;

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    mockEnvReader = MockEnvReader();
    provider = SecureStorageAuthCredentialsProvider(
      secureStorage: mockSecureStorage,
      envReader: mockEnvReader,
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
    test('should return API key from environment when it exists', () async {
      // Arrange
      const expectedApiKey = 'test_api_key';
      when(mockEnvReader.get('API_KEY')).thenReturn(expectedApiKey);

      // Act
      final result = await provider.getApiKey();

      // Assert
      expect(result, equals(expectedApiKey));
      verify(mockEnvReader.get('API_KEY')).called(1);
    });

    test('should throw exception when API key does not exist', () async {
      // Arrange
      when(mockEnvReader.get('API_KEY')).thenReturn(null);

      // Act & Assert
      expect(() => provider.getApiKey(), throwsException);
      verify(mockEnvReader.get('API_KEY')).called(1);
    });

    test('should throw exception when API key is empty', () async {
      // Arrange
      when(mockEnvReader.get('API_KEY')).thenReturn('');

      // Act & Assert
      expect(() => provider.getApiKey(), throwsException);
      verify(mockEnvReader.get('API_KEY')).called(1);
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
