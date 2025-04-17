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
  });
}
