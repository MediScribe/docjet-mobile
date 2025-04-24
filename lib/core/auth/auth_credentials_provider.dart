/// Defines the contract for authentication credential management
///
/// This interface is responsible for providing access to and storing
/// authentication-related credentials (API key, tokens).
/// It lives in the domain layer since the auth service depends on it
/// conceptually, but implementations will use specific storage solutions.
abstract class AuthCredentialsProvider {
  /// Retrieves the API key from secure storage or environment
  Future<String?> getApiKey();

  /// Stores the access token in secure storage
  Future<void> setAccessToken(String token);

  /// Retrieves the stored access token
  Future<String?> getAccessToken();

  /// Deletes the stored access token
  Future<void> deleteAccessToken();

  /// Stores the refresh token in secure storage
  Future<void> setRefreshToken(String token);

  /// Retrieves the stored refresh token
  Future<String?> getRefreshToken();

  /// Deletes the stored refresh token
  Future<void> deleteRefreshToken();

  /// Stores the user ID in secure storage
  Future<void> setUserId(String userId);

  /// Retrieves the stored user ID
  Future<String?> getUserId();

  /// Checks if the stored access token is present and not expired.
  Future<bool> isAccessTokenValid();

  /// Checks if the stored refresh token is present and not expired.
  Future<bool> isRefreshTokenValid();
}
