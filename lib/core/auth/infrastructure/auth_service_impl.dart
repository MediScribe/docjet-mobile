import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';

/// Implementation of the AuthService interface
///
/// Orchestrates authentication flows by coordinating between
/// the AuthApiClient and AuthCredentialsProvider.
class AuthServiceImpl implements AuthService {
  /// Client for making authentication API requests
  final AuthApiClient apiClient;

  /// Provider for storing and retrieving authentication credentials
  final AuthCredentialsProvider credentialsProvider;

  /// Event bus for broadcasting authentication events
  final AuthEventBus eventBus;

  /// Creates an [AuthServiceImpl] with the required dependencies
  AuthServiceImpl({
    required this.apiClient,
    required this.credentialsProvider,
    required this.eventBus,
  });

  @override
  Future<User> login(String email, String password) async {
    try {
      final authResponse = await apiClient.login(email, password);

      // Store tokens securely
      await credentialsProvider.setAccessToken(authResponse.accessToken);
      await credentialsProvider.setRefreshToken(authResponse.refreshToken);
      await credentialsProvider.setUserId(authResponse.userId);

      // Fire loggedIn event
      eventBus.add(AuthEvent.loggedIn);

      // TODO: Implement actual UserProfile fetching during login
      // In the future, we might want to call getUserProfile here
      // and return the full User entity, or handle profile loading separately.

      // Return a domain entity
      return User(id: authResponse.userId);
    } on AuthException {
      // Propagate AuthExceptions directly (e.g., invalidCredentials, offline)
      rethrow;
    } catch (e) {
      // Catch-all for unexpected errors during login flow
      // Consider logging this error
      throw AuthException.unauthenticated('Login failed: ${e.toString()}');
    }
  }

  @override
  Future<bool> refreshSession() async {
    // Get the stored refresh token
    final refreshToken = await credentialsProvider.getRefreshToken();

    // Can't refresh without a refresh token
    if (refreshToken == null) {
      return false;
    }

    try {
      // Attempt to refresh the session
      final authResponse = await apiClient.refreshToken(refreshToken);

      // Store the new tokens
      await credentialsProvider.setAccessToken(authResponse.accessToken);
      await credentialsProvider.setRefreshToken(authResponse.refreshToken);
      // Ensure userId is also stored/updated if necessary (depends on API response)
      await credentialsProvider.setUserId(authResponse.userId);

      return true;
    } on AuthException catch (e) {
      // If token is expired/invalid or offline, refreshing failed
      if (e == AuthException.refreshTokenInvalid() ||
          e == AuthException.tokenExpired()) {
        return false;
      }
      // Propagate other AuthExceptions (like offline, network error)
      rethrow;
    } catch (e) {
      // Catch-all for unexpected errors during refresh
      // Consider logging this error
      return false; // Treat unexpected errors as refresh failure
    }
  }

  @override
  Future<void> logout() async {
    try {
      // Clear stored tokens and user ID
      await credentialsProvider.deleteAccessToken();
      await credentialsProvider.deleteRefreshToken();
      // Assuming we don't explicitly store/delete user ID on logout,
      // but depend on tokens being absent.
      // If user ID needs explicit clearing, add:
      // await credentialsProvider.deleteUserId();

      // Fire loggedOut event
      eventBus.add(AuthEvent.loggedOut);
    } catch (e) {
      // Log error, but don't prevent logout completion
      // Logger.error('Error during logout cleanup: $e');
      // We still consider logout successful from the user's perspective.
      // Ensure the event is still fired if possible, or fire it earlier.
      // If the event bus itself fails, that's a separate issue.
    }
  }

  @override
  Future<bool> isAuthenticated({bool validateTokenLocally = false}) async {
    if (validateTokenLocally) {
      try {
        return await credentialsProvider.isAccessTokenValid();
      } on AuthException {
        // Propagate auth-specific errors (like offline)
        rethrow;
      } catch (e) {
        // Treat other validation errors (e.g., token missing/malformed)
        // as not authenticated.
        // Consider logging this error.
        return false;
      }
    } else {
      // Basic check: does the token exist?
      final accessToken = await credentialsProvider.getAccessToken();
      return accessToken != null;
    }
  }

  @override
  Future<User> getUserProfile() async {
    try {
      final userId = await credentialsProvider.getUserId();
      if (userId == null) {
        throw AuthException.unauthenticated(
          'Cannot get user profile: User ID not found.',
        );
      }

      // TODO: Implement actual DTO and mapping
      // final UserProfileDto profileDto = await apiClient.getUserProfile();
      // For now, assume apiClient.getUserProfile returns a Map
      final profileData =
          await apiClient.getUserProfile(); // Correct call without arguments

      // Basic mapping assuming profileData is Map<String, dynamic>
      return User(
        id: userId, // Use the ID we already confirmed
        // name: profileData['name'] as String?,
        // email: profileData['email'] as String?,
        // Add other fields as needed based on User entity and API response
      );
    } on AuthException {
      // Propagate AuthExceptions (unauthenticated, userProfileFetchFailed, offline, etc.)
      rethrow;
    } catch (e) {
      // Catch-all for unexpected errors during profile fetch
      // Consider logging this error
      // Logger.error('Unexpected error fetching profile: $e');
      throw AuthException.userProfileFetchFailed(); // Corrected: No argument
    }
  }

  @override
  Future<String> getCurrentUserId() async {
    // Delegate directly to the provider
    final userId = await credentialsProvider.getUserId();
    if (userId == null) {
      // If provider returns null (and doesn't throw), throw unauthenticated
      throw AuthException.unauthenticated('No authenticated user ID found');
    }
    return userId;
    // Note: The provider itself should handle token parsing if that's the source.
    // This service layer method simply retrieves the stored/derived ID.
    // Offline exceptions are expected to be thrown by the provider if applicable.
  }
}
