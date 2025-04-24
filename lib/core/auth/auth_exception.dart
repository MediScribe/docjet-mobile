/// Domain-specific authentication exceptions
///
/// This class provides factory methods for creating specific
/// authentication exception types with appropriate messages.
class AuthException implements Exception {
  /// Human-readable error message
  final String message;

  /// Creates an [AuthException] with the given [message]
  const AuthException._({required this.message});

  /// Creates an invalid credentials exception
  factory AuthException.invalidCredentials() {
    return const AuthException._(message: 'Invalid email or password');
  }

  /// Creates a network error exception
  factory AuthException.networkError() {
    return const AuthException._(message: 'Network error occurred');
  }

  /// Creates a server error exception with the given [statusCode]
  factory AuthException.serverError(int statusCode) {
    return AuthException._(message: 'Server error occurred ($statusCode)');
  }

  /// Creates a token expired exception
  factory AuthException.tokenExpired() {
    return const AuthException._(message: 'Authentication token expired');
  }

  /// Creates an unauthenticated exception with an optional custom message
  factory AuthException.unauthenticated([String? customMessage]) {
    return AuthException._(
      message: customMessage ?? 'User is not authenticated',
    );
  }

  /// Creates a refresh token invalid or expired exception
  factory AuthException.refreshTokenInvalid() {
    return const AuthException._(
      message: 'Refresh token is invalid or expired',
    );
  }

  /// Creates a user profile fetch failed exception
  factory AuthException.userProfileFetchFailed() {
    return const AuthException._(message: 'Failed to fetch user profile');
  }

  /// Creates an unauthorized operation exception
  factory AuthException.unauthorizedOperation() {
    return const AuthException._(
      message: 'User is not authorized to perform this operation',
    );
  }

  /// Creates an offline operation failed exception
  factory AuthException.offlineOperationFailed() {
    return const AuthException._(
      message: 'Operation failed due to being offline',
    );
  }

  @override
  String toString() {
    return 'AuthException: $message';
  }
}
