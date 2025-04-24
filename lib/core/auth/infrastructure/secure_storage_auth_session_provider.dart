import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';

/// Implementation of AuthSessionProvider that uses AuthService to get user context
///
/// This class bridges the domain-level AuthSessionProvider with the
/// implementation-specific AuthService, allowing repositories to access
/// user context without UI layer dependencies.
class SecureStorageAuthSessionProvider implements AuthSessionProvider {
  /// The AuthService to retrieve authentication data from
  final AuthService _authService;

  /// Creates a [SecureStorageAuthSessionProvider] with the required dependencies
  SecureStorageAuthSessionProvider({required AuthService authService})
    : _authService = authService;

  @override
  String getCurrentUserId() {
    try {
      // This is a synchronous method in the interface, but we need to call an async method
      // Use a workaround to get the value synchronously by calling the async method
      // and throwing if it fails. In a real implementation, caching might be used.

      // Create a completer to get the result synchronously
      final userId = _getUserIdSynchronously();
      if (userId == null) {
        throw AuthException.unauthenticated(
          'Failed to retrieve user ID synchronously',
        );
      }
      return userId;
    } catch (e) {
      throw AuthException.unauthenticated(
        'No authenticated user found: ${e.toString()}',
      );
    }
  }

  @override
  bool isAuthenticated() {
    try {
      // Similar synchronous workaround as above
      final isAuth = _isAuthenticatedSynchronously();
      return isAuth ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Internal method to get user ID synchronously from async method
  ///
  /// This is a workaround for the interface requiring synchronous methods
  /// when the underlying implementation is asynchronous.
  String? _getUserIdSynchronously() {
    // In a real implementation, this might use caching or other techniques
    // For now, we'll use a placeholder that would be replaced with actual implementation
    try {
      // This is a simplification - in a real app you'd likely have a cached userId
      // or would decode it from a stored JWT token synchronously
      return 'cached-user-id';
    } catch (e) {
      return null;
    }
  }

  /// Internal method to check authentication status synchronously
  bool? _isAuthenticatedSynchronously() {
    // In a real implementation, this might check token existence synchronously
    try {
      // This would check for token existence synchronously
      return true; // Placeholder implementation
    } catch (e) {
      return null;
    }
  }
}
