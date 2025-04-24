import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
// import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';

/// Implementation of AuthSessionProvider that uses AuthCredentialsProvider to get user context
///
/// This class bridges the domain-level AuthSessionProvider with the
/// implementation-specific AuthCredentialsProvider, allowing repositories to access
/// user context without UI layer dependencies.
class SecureStorageAuthSessionProvider implements AuthSessionProvider {
  /// The AuthCredentialsProvider to retrieve authentication data from
  final AuthCredentialsProvider _credentialsProvider;

  /// Creates a [SecureStorageAuthSessionProvider] with the required dependencies
  SecureStorageAuthSessionProvider({
    required AuthCredentialsProvider credentialsProvider,
  }) : _credentialsProvider = credentialsProvider;

  /// Retrieves the ID of the currently authenticated user asynchronously
  ///
  /// Returns the authenticated user's ID.
  /// Throws an [AuthException.unauthenticated] if no user ID is found.
  @override
  Future<String> getCurrentUserId() async {
    try {
      final userId = await _credentialsProvider.getUserId();
      if (userId == null) {
        throw AuthException.unauthenticated('No authenticated user ID found.');
      }
      return userId;
    } catch (e) {
      // Rethrow specific AuthExceptions, wrap others.
      if (e is AuthException) rethrow;
      throw AuthException.unauthenticated(
        'Failed to retrieve user ID: ${e.toString()}',
      );
    }
  }

  /// Checks if a user is currently authenticated asynchronously
  ///
  /// Returns true if an access token exists, false otherwise.
  /// Does not validate the token's expiry.
  @override
  Future<bool> isAuthenticated() async {
    try {
      final accessToken = await _credentialsProvider.getAccessToken();
      return accessToken != null;
    } catch (e) {
      // If checking fails for any reason, assume not authenticated
      // Consider logging the error here
      return false;
    }
  }
}
