import 'dart:convert';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthResponseDto', () {
    const testAccessToken = 'test-access-token';
    const testRefreshToken = 'test-refresh-token';
    const testUserId = 'test-user-id';

    final validJson = {
      'accessToken': testAccessToken,
      'refreshToken': testRefreshToken,
      'userId': testUserId,
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
      final dto = AuthResponseDto(
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
  });
}
