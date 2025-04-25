import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';

/// Utility class for mapping between [AuthException]s and [AuthErrorType]s
///
/// This class provides two mapping approaches:
/// 1. Direct field access (preferred, type-safe) with [getErrorTypeFromException]
///    This is the recommended approach for all new code.
/// 2. String content matching (legacy fallback) with [getErrorTypeFromMessage]
///    This should only be used when dealing with raw error messages where
///    the original exception is not available.
class AuthErrorMapper {
  /// Maps an [AuthException] to the corresponding [AuthErrorType]
  ///
  /// This method directly returns the exception's type field,
  /// providing a clean, type-safe way to get the error type.
  ///
  /// IMPORTANT: This method doesn't rely on string matching and
  /// only uses the explicit type field, making it more robust.
  /// Always prefer this method over [getErrorTypeFromMessage].
  static AuthErrorType getErrorTypeFromException(AuthException exception) {
    return exception.type;
  }

  /// Maps an error message string to the best matching [AuthErrorType]
  ///
  /// CAUTION: This is a LEGACY FALLBACK for when we only have an error message
  /// string and not the actual exception object. It's brittle and relies on
  /// string pattern matching which can break if error messages change.
  ///
  /// Only use this method when you cannot access the original [AuthException].
  /// For normal error handling, always use [getErrorTypeFromException] instead.
  static AuthErrorType getErrorTypeFromMessage(String message) {
    // Check for known message patterns
    if (message.contains('Invalid email or password') ||
        message.contains('Invalid credentials')) {
      return AuthErrorType.invalidCredentials;
    } else if (message.contains('Network error') ||
        message.contains('connection')) {
      return AuthErrorType.network;
    } else if (message.contains('Server error') || message.contains('500')) {
      return AuthErrorType.server;
    } else if (message.contains('token expired') ||
        message.contains('Token expired')) {
      return AuthErrorType.tokenExpired;
    } else if (message.contains('not authenticated') ||
        message.contains('unauthenticated')) {
      return AuthErrorType.unauthenticated;
    } else if (message.contains('Refresh token') ||
        message.contains('refresh token')) {
      return AuthErrorType.refreshTokenInvalid;
    } else if (message.contains('user profile') ||
        message.contains('profile fetch')) {
      return AuthErrorType.userProfileFetchFailed;
    } else if (message.contains('not authorized') ||
        message.contains('unauthorized')) {
      return AuthErrorType.unauthorizedOperation;
    } else if (message.contains('offline') || message.contains('Offline')) {
      return AuthErrorType.offlineOperation;
    }

    // Default fallback
    return AuthErrorType.unknown;
  }
}
