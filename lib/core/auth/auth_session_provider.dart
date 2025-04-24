/// Defines the contract for providing authentication session context
///
/// This interface lives in the domain layer and provides access to the
/// currently authenticated user's context (primarily their ID). It allows
/// repositories and services to access authentication data without direct
/// dependencies on UI or presentation components.
abstract class AuthSessionProvider {
  /// Retrieves the ID of the currently authenticated user
  ///
  /// Returns the authenticated user's ID.
  /// Throws an exception if no user is authenticated.
  Future<String> getCurrentUserId();

  /// Checks if a user is currently authenticated
  ///
  /// Returns true if a user is authenticated, false otherwise.
  Future<bool> isAuthenticated();
}
