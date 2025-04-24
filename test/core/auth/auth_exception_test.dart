import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthException', () {
    test('should create InvalidCredentials with correct message', () {
      // Act
      final exception = AuthException.invalidCredentials();

      // Assert
      expect(exception.message, equals('Invalid email or password'));
      expect(exception.toString(), contains('Invalid email or password'));
    });

    test('should create NetworkError with correct message', () {
      // Act
      final exception = AuthException.networkError();

      // Assert
      expect(exception.message, equals('Network error occurred'));
      expect(exception.toString(), contains('Network error occurred'));
    });

    test('should create ServerError with correct message and code', () {
      // Act
      final exception = AuthException.serverError(500);

      // Assert
      expect(exception.message, equals('Server error occurred (500)'));
      expect(exception.toString(), contains('Server error occurred (500)'));
    });

    test('should create TokenExpired with correct message', () {
      // Act
      final exception = AuthException.tokenExpired();

      // Assert
      expect(exception.message, equals('Authentication token expired'));
      expect(exception.toString(), contains('Authentication token expired'));
    });

    test('should create Unauthenticated with default message', () {
      // Act
      final exception = AuthException.unauthenticated();

      // Assert
      expect(exception.message, equals('User is not authenticated'));
      expect(exception.toString(), contains('User is not authenticated'));
    });

    test('should create Unauthenticated with custom message', () {
      // Act
      final exception = AuthException.unauthenticated(
        'Custom unauthenticated message',
      );

      // Assert
      expect(exception.message, equals('Custom unauthenticated message'));
      expect(exception.toString(), contains('Custom unauthenticated message'));
    });

    test('should create RefreshTokenInvalid with correct message', () {
      // Act
      final exception = AuthException.refreshTokenInvalid();

      // Assert
      expect(exception.message, equals('Refresh token is invalid or expired'));
      expect(
        exception.toString(),
        contains('Refresh token is invalid or expired'),
      );
    });

    test('should create UserProfileFetchFailed with correct message', () {
      // Act
      final exception = AuthException.userProfileFetchFailed();

      // Assert
      expect(exception.message, equals('Failed to fetch user profile'));
      expect(exception.toString(), contains('Failed to fetch user profile'));
    });

    test('should create UnauthorizedOperation with correct message', () {
      // Act
      final exception = AuthException.unauthorizedOperation();

      // Assert
      expect(
        exception.message,
        equals('User is not authorized to perform this operation'),
      );
      expect(
        exception.toString(),
        contains('User is not authorized to perform this operation'),
      );
    });

    test('should create OfflineOperationFailed with correct message', () {
      // Act
      final exception = AuthException.offlineOperationFailed();

      // Assert
      expect(
        exception.message,
        equals('Operation failed due to being offline'),
      );
      expect(
        exception.toString(),
        contains('Operation failed due to being offline'),
      );
    });
  });
}
