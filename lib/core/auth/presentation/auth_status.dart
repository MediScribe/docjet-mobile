/// Represents the current state of authentication
enum AuthStatus {
  /// User is currently being authenticated
  loading,

  /// User is authenticated successfully
  authenticated,

  /// User is not authenticated
  unauthenticated,

  /// Authentication attempt resulted in an error
  error,
}
