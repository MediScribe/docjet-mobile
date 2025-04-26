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

  /// Original stack trace if available
  final StackTrace? stackTrace;

  /// Creates an [AuthException] with the given [message] and [type]
  const AuthException._({
    required this.message,
    required this.type,
    this.stackTrace,
  });

  /// Creates an invalid credentials exception
  factory AuthException.invalidCredentials([StackTrace? stackTrace]) {
    return AuthException._(
      message: 'Invalid email or password',
      type: AuthErrorType.invalidCredentials,
      stackTrace: stackTrace,
    );
  }

  /// Creates a network error exception
  ///
  /// Optionally includes the requested path for better debug context
  factory AuthException.networkError([
    String? requestPath,
    StackTrace? stackTrace,
  ]) {
    final pathInfo = requestPath != null ? ' (path: $requestPath)' : '';
    return AuthException._(
      message: 'Network error occurred$pathInfo',
      type: AuthErrorType.network,
      stackTrace: stackTrace,
    );
  }

  /// Creates a server error exception with the given [statusCode]
  ///
  /// Optionally includes the requested path for better debug context
  factory AuthException.serverError(
    int statusCode, [
    String? requestPath,
    StackTrace? stackTrace,
  ]) {
    final pathInfo = requestPath != null ? ' (path: $requestPath)' : '';
    return AuthException._(
      message: 'Server error occurred ($statusCode)$pathInfo',
      type: AuthErrorType.server,
      stackTrace: stackTrace,
    );
  }

  /// Creates a token expired exception
  factory AuthException.tokenExpired([StackTrace? stackTrace]) {
    return AuthException._(
      message: 'Authentication token expired',
      type: AuthErrorType.tokenExpired,
      stackTrace: stackTrace,
    );
  }

  /// Creates an unauthenticated exception with an optional custom message
  factory AuthException.unauthenticated([
    String? customMessage,
    StackTrace? stackTrace,
  ]) {
    return AuthException._(
      message: customMessage ?? 'User is not authenticated',
      type: AuthErrorType.unauthenticated,
      stackTrace: stackTrace,
    );
  }

  /// Creates a refresh token invalid or expired exception
  factory AuthException.refreshTokenInvalid([StackTrace? stackTrace]) {
    return AuthException._(
      message: 'Refresh token is invalid or expired',
      type: AuthErrorType.refreshTokenInvalid,
      stackTrace: stackTrace,
    );
  }

  /// Creates a user profile fetch failed exception
  factory AuthException.userProfileFetchFailed([StackTrace? stackTrace]) {
    return AuthException._(
      message: 'Failed to fetch user profile',
      type: AuthErrorType.userProfileFetchFailed,
      stackTrace: stackTrace,
    );
  }

  /// Creates an unauthorized operation exception
  factory AuthException.unauthorizedOperation([StackTrace? stackTrace]) {
    return AuthException._(
      message: 'User is not authorized to perform this operation',
      type: AuthErrorType.unauthorizedOperation,
      stackTrace: stackTrace,
    );
  }

  /// Creates an offline operation failed exception
  factory AuthException.offlineOperationFailed([StackTrace? stackTrace]) {
    return AuthException._(
      message: 'Operation failed due to being offline',
      type: AuthErrorType.offlineOperation,
      stackTrace: stackTrace,
    );
  }

  /// Creates a missing API key exception
  factory AuthException.missingApiKey(
    String? endpoint, [
    StackTrace? stackTrace,
  ]) {
    final pathInfo = endpoint != null ? ' for endpoint $endpoint' : '';
    return AuthException._(
      message: 'API key is missing$pathInfo - check your app configuration',
      type: AuthErrorType.missingApiKey,
      stackTrace: stackTrace,
    );
  }

  /// Creates a malformed URL path exception
  factory AuthException.malformedUrl(String path, [StackTrace? stackTrace]) {
    return AuthException._(
      message:
          'URL path error: $path might be malformed - check path formatting',
      type: AuthErrorType.malformedUrl,
      stackTrace: stackTrace,
    );
  }

  /// Creates an appropriate exception based on HTTP status code
  ///
  /// This factory method provides a consistent way to map HTTP status codes
  /// to domain-specific auth exceptions.
  factory AuthException.fromStatusCode(
    int statusCode,
    String path, {
    bool hasApiKey = true,
    bool isRefreshEndpoint = false,
    bool isProfileEndpoint = false,
    StackTrace? stackTrace,
  }) {
    // API key missing check
    if (statusCode == 401 && !hasApiKey) {
      return AuthException.missingApiKey(path, stackTrace);
    }

    // Handle different status codes with context
    switch (statusCode) {
      case 401:
        if (isRefreshEndpoint) {
          return AuthException.refreshTokenInvalid(stackTrace);
        }
        if (isProfileEndpoint) {
          return AuthException.userProfileFetchFailed(stackTrace);
        }
        return AuthException.invalidCredentials(stackTrace);

      case 403:
        return AuthException.unauthorizedOperation(stackTrace);

      case 404:
        // Check for malformed URL patters
        if (path.contains('/api/v1auth/') || path.contains('api/v1auth/')) {
          return AuthException.malformedUrl(path, stackTrace);
        }
        return AuthException.serverError(statusCode, path, stackTrace);

      case 500:
      case 502:
      case 503:
      case 504:
        if (isProfileEndpoint) {
          return AuthException.userProfileFetchFailed(stackTrace);
        }
        return AuthException.serverError(statusCode, path, stackTrace);

      default:
        if (isProfileEndpoint) {
          return AuthException.userProfileFetchFailed(stackTrace);
        }
        return AuthException.serverError(statusCode, path, stackTrace);
    }
  }

  @override
  String toString() {
    return 'AuthException: $message';
  }

  /// Override equality operator to compare only by type, not message
  ///
  /// This makes tests comparing against factory-created AuthExceptions
  /// backward compatible with our enhanced error messages that include
  /// path details, since many tests only care about the type of error.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AuthException) return false;
    return type == other.type;
  }

  @override
  int get hashCode => type.hashCode;

  /// Determines if two exceptions are exactly the same including message
  ///
  /// Unlike the equality operator which only compares by type, this method
  /// performs a full comparison including the message content.
  bool exactlyEquals(AuthException other) {
    return type == other.type && message == other.message;
  }

  /// Creates a diagnostic string with stack trace (if available)
  String diagnosticString() {
    if (stackTrace == null) {
      return toString();
    }
    return '$this\n$stackTrace';
  }
}
