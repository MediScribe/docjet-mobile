import 'package:docjet_mobile/core/auth/auth_error_mapper.dart';
import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Create a mock for testing AuthErrorMapper's direct type access
class MockAuthException extends Mock implements AuthException {
  @override
  final AuthErrorType type;
  @override
  final String message;

  MockAuthException(this.type, this.message);
}

void main() {
  group('AuthErrorMapper', () {
    group('getErrorTypeFromException', () {
      test(
        'should directly return the exception type without string matching',
        () {
          // Arrange - create mock exception with type but unrelated message
          final mockException = MockAuthException(
            AuthErrorType.invalidCredentials,
            'This message should be ignored',
          );

          // Act
          final result = AuthErrorMapper.getErrorTypeFromException(
            mockException,
          );

          // Assert - should use the type field directly
          expect(result, equals(AuthErrorType.invalidCredentials));
        },
      );

      test(
        'should return correct type even when message seems to indicate a different error',
        () {
          // Arrange - create mock exception with a type but message suggesting another type
          final mockException = MockAuthException(
            AuthErrorType.server,
            'Network error occurred', // Message that would match network error
          );

          // Act
          final result = AuthErrorMapper.getErrorTypeFromException(
            mockException,
          );

          // Assert - should use the type field directly, ignoring the message content
          expect(result, equals(AuthErrorType.server));
        },
      );

      test('should map invalidCredentials exception to correct error type', () {
        // Arrange
        final exception = AuthException.invalidCredentials();

        // Act
        final result = AuthErrorMapper.getErrorTypeFromException(exception);

        // Assert
        expect(result, AuthErrorType.invalidCredentials);
      });

      test('should map networkError exception to correct error type', () {
        // Arrange
        final exception = AuthException.networkError();

        // Act
        final result = AuthErrorMapper.getErrorTypeFromException(exception);

        // Assert
        expect(result, AuthErrorType.network);
      });

      test(
        'should map offlineOperationFailed exception to correct error type',
        () {
          // Arrange
          final exception = AuthException.offlineOperationFailed();

          // Act
          final result = AuthErrorMapper.getErrorTypeFromException(exception);

          // Assert
          expect(result, AuthErrorType.offlineOperation);
        },
      );

      test('should map unauthenticated exception to correct error type', () {
        // Arrange
        final exception = AuthException.unauthenticated();

        // Act
        final result = AuthErrorMapper.getErrorTypeFromException(exception);

        // Assert
        expect(result, AuthErrorType.unauthenticated);
      });

      test('should map tokenExpired exception to correct error type', () {
        // Arrange
        final exception = AuthException.tokenExpired();

        // Act
        final result = AuthErrorMapper.getErrorTypeFromException(exception);

        // Assert
        expect(result, AuthErrorType.tokenExpired);
      });

      test('should map serverError exception to correct error type', () {
        // Arrange
        final exception = AuthException.serverError(500);

        // Act
        final result = AuthErrorMapper.getErrorTypeFromException(exception);

        // Assert
        expect(result, AuthErrorType.server);
      });
    });

    group('getErrorTypeFromMessage', () {
      test('should map invalid credentials message to correct error type', () {
        // Arrange
        const message = 'Invalid email or password';

        // Act
        final result = AuthErrorMapper.getErrorTypeFromMessage(message);

        // Assert
        expect(result, AuthErrorType.invalidCredentials);
      });

      test('should map network error message to correct error type', () {
        // Arrange
        const message = 'Network error occurred';

        // Act
        final result = AuthErrorMapper.getErrorTypeFromMessage(message);

        // Assert
        expect(result, AuthErrorType.network);
      });

      test('should map offline message to correct error type', () {
        // Arrange
        const message = 'Operation failed due to being offline';

        // Act
        final result = AuthErrorMapper.getErrorTypeFromMessage(message);

        // Assert
        expect(result, AuthErrorType.offlineOperation);
      });

      test('should map token expired message to correct error type', () {
        // Arrange
        const message = 'Authentication token expired';

        // Act
        final result = AuthErrorMapper.getErrorTypeFromMessage(message);

        // Assert
        expect(result, AuthErrorType.tokenExpired);
      });

      test('should map unknown message to unknown error type', () {
        // Arrange
        const message = 'Some completely unrecognized error message';

        // Act
        final result = AuthErrorMapper.getErrorTypeFromMessage(message);

        // Assert
        expect(result, AuthErrorType.unknown);
      });
    });
  });
}
