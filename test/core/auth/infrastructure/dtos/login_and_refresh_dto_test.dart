import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/login_response_dto.dart'; // Will fail initially
import 'package:docjet_mobile/core/auth/infrastructure/dtos/refresh_response_dto.dart'; // Will fail initially

void main() {
  group('LoginResponseDto', () {
    test('fromJson should correctly parse valid login JSON', () {
      // Arrange
      final json = {
        'access_token': 'mock_access_token',
        'refresh_token': 'mock_refresh_token',
        'user_id': 'mock_user_id',
      };

      // Act
      final dto = LoginResponseDto.fromJson(json);

      // Assert
      expect(dto.accessToken, 'mock_access_token');
      expect(dto.refreshToken, 'mock_refresh_token');
      expect(dto.userId, 'mock_user_id');
    });

    test('fromJson should throw when login JSON is missing fields', () {
      // Arrange
      final jsonMissingAccess = {
        'refresh_token': 'mock_refresh_token',
        'user_id': 'mock_user_id',
      };
      final jsonMissingRefresh = {
        'access_token': 'mock_access_token',
        'user_id': 'mock_user_id',
      };
      final jsonMissingUser = {
        'access_token': 'mock_access_token',
        'refresh_token': 'mock_refresh_token',
      };

      // Act & Assert
      expect(
        () => LoginResponseDto.fromJson(jsonMissingAccess),
        throwsA(isA<TypeError>()),
      ); // Or specific error
      expect(
        () => LoginResponseDto.fromJson(jsonMissingRefresh),
        throwsA(isA<TypeError>()),
      ); // Or specific error
      expect(
        () => LoginResponseDto.fromJson(jsonMissingUser),
        throwsA(isA<TypeError>()),
      ); // Or specific error
    });
  });

  group('RefreshResponseDto', () {
    test('fromJson should correctly parse valid refresh JSON', () {
      // Arrange
      final json = {
        'access_token': 'new_mock_access_token',
        'refresh_token': 'new_mock_refresh_token',
      };

      // Act
      final dto = RefreshResponseDto.fromJson(json);

      // Assert
      expect(dto.accessToken, 'new_mock_access_token');
      expect(dto.refreshToken, 'new_mock_refresh_token');
      // IMPORTANT: No userId expected here
    });

    test('fromJson should throw when refresh JSON is missing fields', () {
      // Arrange
      final jsonMissingAccess = {'refresh_token': 'new_mock_refresh_token'};
      final jsonMissingRefresh = {'access_token': 'new_mock_access_token'};

      // Act & Assert
      expect(
        () => RefreshResponseDto.fromJson(jsonMissingAccess),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => RefreshResponseDto.fromJson(jsonMissingRefresh),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson should ignore extra fields like user_id', () {
      // Arrange
      final jsonWithExtra = {
        'access_token': 'new_mock_access_token',
        'refresh_token': 'new_mock_refresh_token',
        'user_id': 'should_be_ignored', // Extra field
      };

      // Act
      final dto = RefreshResponseDto.fromJson(jsonWithExtra);

      // Assert
      expect(dto.accessToken, 'new_mock_access_token');
      expect(dto.refreshToken, 'new_mock_refresh_token');
      // No assertion for userId, confirming it's ignored
    });
  });
}
