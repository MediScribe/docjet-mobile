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

  @override
  String toString() {
    return 'AuthException: $message';
  }
}
