import 'package:docjet_mobile/core/auth/auth_error_type.dart';

/// Domain-specific authentication exceptions
///
/// This class provides factory methods for creating specific
/// authentication exception types with appropriate messages.
class AuthException implements Exception {
  /// Human-readable error message
  final String message;

  /// The type of authentication error
  final AuthErrorType type;

  /// Creates an [AuthException] with the given [message] and [type]
  const AuthException._({required this.message, required this.type});

  /// Creates an invalid credentials exception
  factory AuthException.invalidCredentials() {
    return const AuthException._(
      message: 'Invalid email or password',
      type: AuthErrorType.invalidCredentials,
    );
  }

  /// Creates a network error exception
  factory AuthException.networkError() {
    return const AuthException._(
      message: 'Network error occurred',
      type: AuthErrorType.network,
    );
  }

  /// Creates a server error exception with the given [statusCode]
  factory AuthException.serverError(int statusCode) {
    return AuthException._(
      message: 'Server error occurred ($statusCode)',
      type: AuthErrorType.server,
    );
  }

  /// Creates a token expired exception
  factory AuthException.tokenExpired() {
    return const AuthException._(
      message: 'Authentication token expired',
      type: AuthErrorType.tokenExpired,
    );
  }

  /// Creates an unauthenticated exception with an optional custom message
  factory AuthException.unauthenticated([String? customMessage]) {
    return AuthException._(
      message: customMessage ?? 'User is not authenticated',
      type: AuthErrorType.unauthenticated,
    );
  }

  /// Creates a refresh token invalid or expired exception
  factory AuthException.refreshTokenInvalid() {
    return const AuthException._(
      message: 'Refresh token is invalid or expired',
      type: AuthErrorType.refreshTokenInvalid,
    );
  }

  /// Creates a user profile fetch failed exception
  factory AuthException.userProfileFetchFailed() {
    return const AuthException._(
      message: 'Failed to fetch user profile',
      type: AuthErrorType.userProfileFetchFailed,
    );
  }

  /// Creates an unauthorized operation exception
  factory AuthException.unauthorizedOperation() {
    return const AuthException._(
      message: 'User is not authorized to perform this operation',
      type: AuthErrorType.unauthorizedOperation,
    );
  }

  /// Creates an offline operation failed exception
  factory AuthException.offlineOperationFailed() {
    return const AuthException._(
      message: 'Operation failed due to being offline',
      type: AuthErrorType.offlineOperation,
    );
  }

  @override
  String toString() {
    return 'AuthException: $message';
  }
}
