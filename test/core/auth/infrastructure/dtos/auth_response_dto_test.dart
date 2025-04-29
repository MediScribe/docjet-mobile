import 'dart:convert';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthResponseDto', () {
    const testAccessToken = 'test-access-token';
    const testRefreshToken = 'test-refresh-token';
    const testUserId = 'test-user-id';

    final validJson = {
      'access_token': testAccessToken,
      'refresh_token': testRefreshToken,
      'user_id': testUserId,
    };

    test('should parse from valid JSON', () {
      // Act
      final result = AuthResponseDto.fromJson(validJson);

      // Assert
      expect(result.accessToken, equals(testAccessToken));
      expect(result.refreshToken, equals(testRefreshToken));
      expect(result.userId, equals(testUserId));
    });

    test('should convert to JSON', () {
      // Arrange
      const dto = AuthResponseDto(
        accessToken: testAccessToken,
        refreshToken: testRefreshToken,
        userId: testUserId,
      );

      // Act
      final result = dto.toJson();

      // Assert
      expect(result, equals(validJson));
    });

    test('should handle JSON string conversion', () {
      // Arrange
      final jsonString = json.encode(validJson);

      // Act
      final decodedJson = json.decode(jsonString) as Map<String, dynamic>;
      final result = AuthResponseDto.fromJson(decodedJson);

      // Assert
      expect(result.accessToken, equals(testAccessToken));
      expect(result.refreshToken, equals(testRefreshToken));
      expect(result.userId, equals(testUserId));
    });

    test('should parse from the actual API response format', () {
      // Arrange - The format seen in the logs
      final apiResponseJson = {
        'access_token': 'fake-access-token-1745685985613',
        'refresh_token': 'fake-refresh-token-1745685985613',
        'user_id': 'fake-user-id-123',
      };

      // Act
      final result = AuthResponseDto.fromJson(apiResponseJson);

      // Assert
      expect(result.accessToken, equals('fake-access-token-1745685985613'));
      expect(result.refreshToken, equals('fake-refresh-token-1745685985613'));
      expect(result.userId, equals('fake-user-id-123'));
    });
  });
}
