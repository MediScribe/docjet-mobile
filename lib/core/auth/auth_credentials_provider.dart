/// Abstract interface for providing authentication credentials (JWT, API Key).
///
/// Implementations of this interface are responsible for securely retrieving
/// the necessary credentials required for API requests.
abstract class AuthCredentialsProvider {
  /// Retrieves the current Access Token (JWT).
  ///
  /// Returns the token string if available, or null if the user is not
  /// authenticated or the token is not available.
  /// Implementations should handle token refresh logic internally if necessary,
  /// or coordinate with an authentication service.
  Future<String?> getAccessToken();

  /// Retrieves the mandatory API Key.
  ///
  /// Throws an exception if the API key cannot be retrieved, as it's
  /// required for all API interactions according to the specification.
  Future<String> getApiKey();
}
