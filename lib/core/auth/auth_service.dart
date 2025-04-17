import 'package:docjet_mobile/core/auth/entities/user.dart';

/// Defines the authentication service contract
///
/// This interface provides methods for authentication operations like login, logout,
/// session refresh, and auth status checking. It is independent of any framework
/// or implementation details.
abstract class AuthService {
  /// Authenticates a user with email and password
  ///
  /// Returns a [User] entity if login is successful.
  /// May throw [AuthException] if authentication fails.
  Future<User> login(String email, String password);

  /// Refreshes the current authentication session
  ///
  /// Returns true if refresh was successful, false otherwise.
  Future<bool> refreshSession();

  /// Logs out the current user by clearing stored credentials
  Future<void> logout();

  /// Checks if a user is currently authenticated
  ///
  /// Returns true if the user is authenticated, false otherwise.
  /// This performs a basic check of stored credentials; it does not
  /// validate with the server if the credentials are still valid.
  Future<bool> isAuthenticated();
}
