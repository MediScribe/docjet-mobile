/// Enum representing different types of authentication errors
///
/// Used for consistent error handling and UI presentation across the app
enum AuthErrorType {
  /// Invalid credentials (wrong email/password)
  invalidCredentials,

  /// Network connectivity issues
  network,

  /// Server errors (500, etc.)
  server,

  /// Token expired
  tokenExpired,

  /// User not authenticated
  unauthenticated,

  /// Refresh token invalid
  refreshTokenInvalid,

  /// Failed to fetch user profile
  userProfileFetchFailed,

  /// Unauthorized operation
  unauthorizedOperation,

  /// Offline operation failed
  offlineOperation,

  /// API key missing
  missingApiKey,

  /// Malformed URL path
  malformedUrl,

  /// Generic/unknown error
  unknown,
}
