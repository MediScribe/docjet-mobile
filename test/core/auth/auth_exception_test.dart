import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_trace/stack_trace.dart';

void main() {
  group('AuthException', () {
    test('should create InvalidCredentials with correct message and type', () {
      // Act
      final exception = AuthException.invalidCredentials();

      // Assert
      expect(exception.message, equals('Invalid email or password'));
      expect(exception.type, equals(AuthErrorType.invalidCredentials));
      expect(exception.toString(), contains('Invalid email or password'));
    });

    test('should create NetworkError with correct message and type', () {
      // Act
      final exception = AuthException.networkError();

      // Assert
      expect(exception.message, equals('Network error occurred'));
      expect(exception.type, equals(AuthErrorType.network));
      expect(exception.toString(), contains('Network error occurred'));
    });

    test('should create ServerError with correct message, code, and type', () {
      // Act
      final exception = AuthException.serverError(500);

      // Assert
      expect(exception.message, equals('Server error occurred (500)'));
      expect(exception.type, equals(AuthErrorType.server));
      expect(exception.toString(), contains('Server error occurred (500)'));
    });

    test('should create TokenExpired with correct message and type', () {
      // Act
      final exception = AuthException.tokenExpired();

      // Assert
      expect(exception.message, equals('Authentication token expired'));
      expect(exception.type, equals(AuthErrorType.tokenExpired));
      expect(exception.toString(), contains('Authentication token expired'));
    });

    test('should create Unauthenticated with default message and type', () {
      // Act
      final exception = AuthException.unauthenticated();

      // Assert
      expect(exception.message, equals('User is not authenticated'));
      expect(exception.type, equals(AuthErrorType.unauthenticated));
      expect(exception.toString(), contains('User is not authenticated'));
    });

    test('should create Unauthenticated with custom message and type', () {
      // Act
      final exception = AuthException.unauthenticated(
        'Custom unauthenticated message',
      );

      // Assert
      expect(exception.message, equals('Custom unauthenticated message'));
      expect(exception.type, equals(AuthErrorType.unauthenticated));
      expect(exception.toString(), contains('Custom unauthenticated message'));
    });

    test('should create RefreshTokenInvalid with correct message and type', () {
      // Act
      final exception = AuthException.refreshTokenInvalid();

      // Assert
      expect(exception.message, equals('Refresh token is invalid or expired'));
      expect(exception.type, equals(AuthErrorType.refreshTokenInvalid));
      expect(
        exception.toString(),
        contains('Refresh token is invalid or expired'),
      );
    });

    test(
      'should create UserProfileFetchFailed with correct message and type',
      () {
        // Act
        final exception = AuthException.userProfileFetchFailed();

        // Assert
        expect(exception.message, equals('Failed to fetch user profile'));
        expect(exception.type, equals(AuthErrorType.userProfileFetchFailed));
        expect(exception.toString(), contains('Failed to fetch user profile'));
      },
    );

    test(
      'should create UnauthorizedOperation with correct message and type',
      () {
        // Act
        final exception = AuthException.unauthorizedOperation();

        // Assert
        expect(
          exception.message,
          equals('User is not authorized to perform this operation'),
        );
        expect(exception.type, equals(AuthErrorType.unauthorizedOperation));
        expect(
          exception.toString(),
          contains('User is not authorized to perform this operation'),
        );
      },
    );

    test(
      'should create OfflineOperationFailed with correct message and type',
      () {
        // Act
        final exception = AuthException.offlineOperationFailed();

        // Assert
        expect(
          exception.message,
          equals('Operation failed due to being offline'),
        );
        expect(exception.type, equals(AuthErrorType.offlineOperation));
        expect(
          exception.toString(),
          contains('Operation failed due to being offline'),
        );
      },
    );

    // New tests for enhanced AuthException features

    group('Enhanced AuthException Features', () {
      test('should preserve stack trace when provided', () {
        // Arrange: Create a stack trace
        final mockStackTrace = Trace.current();

        // Act: Create exceptions with stack trace
        final networkError = AuthException.networkError(
          'test/path',
          mockStackTrace,
        );
        final serverError = AuthException.serverError(
          500,
          'test/path',
          mockStackTrace,
        );

        // Assert: Stack traces are preserved
        expect(networkError.stackTrace, equals(mockStackTrace));
        expect(serverError.stackTrace, equals(mockStackTrace));
      });

      test('operator== should compare only by type, not message', () {
        // Arrange: Create exceptions with different paths but same type
        final error1 = AuthException.networkError('path1');
        final error2 = AuthException.networkError('path2');
        final error3 = AuthException.serverError(500, 'path1');

        // Act & Assert: Check equality behavior
        expect(error1 == error2, isTrue); // Path doesn't matter for ==
        expect(error1 == error3, isFalse); // Different types are not equal
      });

      test('exactlyEquals should compare both type and message', () {
        // Arrange: Create exceptions with different paths but same type
        final error1 = AuthException.networkError('path1');
        final error2 = AuthException.networkError('path2');
        final error3 = AuthException.networkError('path1'); // Same as error1

        // Act & Assert: Check exactlyEquals behavior
        expect(error1.exactlyEquals(error2), isFalse); // Different messages
        expect(error1.exactlyEquals(error3), isTrue); // Same type and message
      });

      test('diagnosticString includes stack trace when available', () {
        // Arrange: Create exceptions with and without stack trace
        final mockStackTrace = Trace.parse(
          'at function (file:1:2)\nat other (file:3:4)',
        );
        final withStack = AuthException.networkError(
          'test/path',
          mockStackTrace,
        );
        final withoutStack = AuthException.networkError('test/path');

        // Act & Assert: Check diagnostic string format
        expect(
          withoutStack.diagnosticString(),
          equals('AuthException: Network error occurred (path: test/path)'),
        );
        expect(
          withStack.diagnosticString(),
          contains('AuthException: Network error occurred (path: test/path)'),
        );
        expect(
          withStack.diagnosticString(),
          contains('at function (file:1:2)'),
        );
      });

      group('fromStatusCode factory method', () {
        test('should detect missing API key for 401 errors', () {
          // Act: Create exception using fromStatusCode
          final exception = AuthException.fromStatusCode(
            401,
            'api/v1/auth/login',
            hasApiKey: false,
          );

          // Assert: Check type and message
          expect(exception.type, equals(AuthErrorType.missingApiKey));
          expect(exception.message, contains('API key is missing'));
          expect(exception.message, contains('api/v1/auth/login'));
        });

        test(
          'should create refreshTokenInvalid for 401 on refresh endpoint',
          () {
            // Act: Create exception using fromStatusCode
            final exception = AuthException.fromStatusCode(
              401,
              'api/v1/auth/refresh-session',
              isRefreshEndpoint: true,
            );

            // Assert: Check type
            expect(exception.type, equals(AuthErrorType.refreshTokenInvalid));
          },
        );

        test(
          'should create userProfileFetchFailed for 401 on profile endpoint',
          () {
            // Act: Create exception using fromStatusCode
            final exception = AuthException.fromStatusCode(
              401,
              'api/v1/users/profile',
              isProfileEndpoint: true,
            );

            // Assert: Check type
            expect(
              exception.type,
              equals(AuthErrorType.userProfileFetchFailed),
            );
          },
        );

        test('should create invalidCredentials for standard 401', () {
          // Act: Create exception using fromStatusCode for standard login
          final exception = AuthException.fromStatusCode(
            401,
            'api/v1/auth/login',
          );

          // Assert: Check type
          expect(exception.type, equals(AuthErrorType.invalidCredentials));
        });

        test('should create unauthorizedOperation for 403 errors', () {
          // Act: Create exception using fromStatusCode
          final exception = AuthException.fromStatusCode(
            403,
            'api/v1/some/endpoint',
          );

          // Assert: Check type
          expect(exception.type, equals(AuthErrorType.unauthorizedOperation));
        });

        test('should detect malformed URL patterns on 404', () {
          // Act: Create exception using fromStatusCode with malformed path
          final exception = AuthException.fromStatusCode(
            404,
            'api/v1auth/login', // Missing slash
          );

          // Assert: Check type and message
          expect(exception.type, equals(AuthErrorType.malformedUrl));
          expect(exception.message, contains('URL path error'));
          expect(exception.message, contains('api/v1auth/login'));
        });

        test('should handle standard 404 as server error', () {
          // Act: Create exception for regular 404
          final exception = AuthException.fromStatusCode(
            404,
            'api/v1/some/nonexistent/path',
          );

          // Assert: Check type
          expect(exception.type, equals(AuthErrorType.server));
          expect(exception.message, contains('Server error occurred (404)'));
        });

        test(
          'should handle server errors (5xx) with profile endpoint special case',
          () {
            // Act: Create exceptions for server errors
            final profileException = AuthException.fromStatusCode(
              500,
              'api/v1/users/profile',
              isProfileEndpoint: true,
            );

            final regularException = AuthException.fromStatusCode(
              500,
              'api/v1/some/endpoint',
            );

            // Assert: Check types
            expect(
              profileException.type,
              equals(AuthErrorType.userProfileFetchFailed),
            );
            expect(regularException.type, equals(AuthErrorType.server));
            expect(
              regularException.message,
              contains('Server error occurred (500)'),
            );
          },
        );

        test('should preserve stack trace throughout factory method', () {
          // Arrange: Create stack trace
          final mockStackTrace = Trace.current();

          // Act: Create exception with stack trace
          final exception = AuthException.fromStatusCode(
            500,
            'api/v1/endpoint',
            stackTrace: mockStackTrace,
          );

          // Assert: Stack trace is preserved
          expect(exception.stackTrace, equals(mockStackTrace));
        });
      });
    });
  });
}
