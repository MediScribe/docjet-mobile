import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';

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
  /// Implementations should fire [AuthEvent.loggedIn] on success.
  Future<User> login(String email, String password);

  /// Refreshes the current authentication session
  ///
  /// Returns true if refresh was successful, false otherwise.
  Future<bool> refreshSession();

  /// Logs out the current user by clearing stored credentials
  ///
  /// Implementations should fire [AuthEvent.loggedOut].
  Future<void> logout();

  /// Checks if a user is currently authenticated
  ///
  /// - [validateTokenLocally]: If true, performs a local validation of the access
  ///   token's expiry without contacting the server. Defaults to false.
  ///
  /// Returns true if the user is considered authenticated based on the check,
  /// false otherwise.
  Future<bool> isAuthenticated({bool validateTokenLocally = false});

  /// Retrieves the ID of the currently authenticated user
  ///
  /// Returns the user ID if a user is authenticated.
  /// Throws an [AuthException] if no user is authenticated.
  Future<String> getCurrentUserId();

  /// Retrieves the full profile of the currently authenticated user
  ///
  /// Returns the [User] entity containing profile details.
  /// Throws an [AuthException] if the user is not authenticated or the profile
  /// cannot be fetched.
  ///
  /// - [acceptOfflineProfile]: If true (default), allows returning a cached profile
  ///   if the network fetch fails due to being offline.
  Future<User> getUserProfile({bool acceptOfflineProfile = true});
}
