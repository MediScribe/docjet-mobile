import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/domain/repositories/i_user_profile_cache.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/infrastructure/authentication_api_client.dart';
import 'package:docjet_mobile/core/user/infrastructure/user_api_client.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/core/auth/auth_error_type.dart';

/// Implementation of the AuthService interface
///
/// Orchestrates authentication flows by coordinating between
/// the AuthenticationApiClient, UserApiClient, AuthCredentialsProvider, and IUserProfileCache.
class AuthServiceImpl implements AuthService {
  /// Client for making authentication API requests (login, refresh)
  final AuthenticationApiClient authenticationApiClient;

  /// Client for making user-related API requests (profile)
  final UserApiClient userApiClient;

  /// Provider for storing and retrieving authentication credentials
  final AuthCredentialsProvider credentialsProvider;

  /// Event bus for broadcasting authentication events
  final AuthEventBus eventBus;

  /// Cache for storing user profiles
  final IUserProfileCache userProfileCache;

  /// Added logger
  final _logger = LoggerFactory.getLogger('AuthServiceImpl');
  final _tag = logTag('AuthServiceImpl');

  /// Creates an [AuthServiceImpl] with the required dependencies
  AuthServiceImpl({
    required this.authenticationApiClient,
    required this.userApiClient,
    required this.credentialsProvider,
    required this.eventBus,
    required this.userProfileCache,
  });

  @override
  Future<User> login(String email, String password) async {
    try {
      final authResponse = await authenticationApiClient.login(email, password);

      // Store tokens securely
      await credentialsProvider.setAccessToken(authResponse.accessToken);
      await credentialsProvider.setRefreshToken(authResponse.refreshToken);
      await credentialsProvider.setUserId(authResponse.userId);

      // Fire loggedIn event
      eventBus.add(AuthEvent.loggedIn);

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
      // Attempt to refresh the session using the authentication client
      final authResponse = await authenticationApiClient.refreshToken(
        refreshToken,
      );

      // Store the new tokens
      await credentialsProvider.setAccessToken(authResponse.accessToken);
      await credentialsProvider.setRefreshToken(authResponse.refreshToken);
      // Ensure userId is also stored/updated if necessary (depends on API response)
      // REMOVED: userId is not returned on refresh

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
    String? userId;
    try {
      // Get user ID BEFORE clearing credentials, needed for cache clear
      try {
        userId = await credentialsProvider.getUserId();
      } catch (e) {
        _logger.w(
          '$_tag Failed to get user ID during logout, cannot clear specific profile cache: $e',
        );
      }

      // Clear stored tokens
      await credentialsProvider.deleteAccessToken();
      await credentialsProvider.deleteRefreshToken();
      // Don't explicitly delete user ID from creds, rely on token absence

      // Clear the specific user profile cache if we got the ID
      if (userId != null) {
        try {
          await userProfileCache.clearProfile(userId);
          _logger.i(
            '$_tag Cleared profile cache for user $userId during logout.',
          );
        } catch (e) {
          // Log error, but don't prevent logout completion
          _logger.e(
            '$_tag Error clearing profile cache for user $userId during logout: $e',
          );
        }
      } else {
        // Optional: Could try clearAllProfiles if no ID, but riskier
        _logger.w(
          '$_tag Skipping profile cache clear during logout due to missing user ID.',
        );
      }

      // Fire loggedOut event
      eventBus.add(AuthEvent.loggedOut);
      _logger.i('$_tag Logout successful, event fired.');
    } catch (e) {
      // Catch potential errors during credential deletion
      _logger.e('$_tag Error during logout credential cleanup: $e');
      // Ensure the event is still fired if possible, but don't assume eventQueue exists
      try {
        eventBus.add(AuthEvent.loggedOut);
      } catch (eventBusError) {
        _logger.e(
          '$_tag Failed to fire logout event after cleanup error: $eventBusError',
        );
      }
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
  Future<User> getUserProfile({bool acceptOfflineProfile = true}) async {
    String? userId;
    try {
      userId = await _getUserIdOrThrow();
      _logger.d('$_tag Attempting to get profile for user: $userId');

      // Try fetching from network first
      return await _fetchProfileFromNetworkAndCache(userId);
    } on AuthException catch (e) {
      _logger.w(
        '$_tag AuthException caught during profile fetch for user $userId: ${e.type}',
      );
      // Rethrow if not offline or offline not accepted
      if (e.type != AuthErrorType.offlineOperation || !acceptOfflineProfile) {
        _logger.w(
          '$_tag Propagating original AuthException (${e.type}) for user $userId.',
        );
        rethrow;
      }
      // If offline and accepted, try cache (userId must be non-null here)
      _logger.i(
        '$_tag Network unavailable for profile fetch (user $userId), checking cache...',
      );
      return await _fetchProfileFromCacheOrThrow(
        userId!,
        e,
      ); // Pass original exception
    } catch (e) {
      _logger.e('$_tag Unexpected error fetching profile for user $userId: $e');
      throw AuthException.userProfileFetchFailed();
    }
  }

  /// Helper to get user ID, throws AuthException.unauthenticated if null.
  Future<String> _getUserIdOrThrow() async {
    final userId = await credentialsProvider.getUserId();
    if (userId == null) {
      _logger.w('$_tag Cannot get user profile: User ID not found in creds.');
      throw AuthException.unauthenticated(
        'Cannot get user profile: User ID not found.',
      );
    }
    return userId;
  }

  /// Fetches profile from network, caches it, and returns the User.
  Future<User> _fetchProfileFromNetworkAndCache(String userId) async {
    final profileDto = await userApiClient.getUserProfile();
    _logger.i('$_tag Successfully fetched profile for user $userId from API.');

    // Save to cache (best effort)
    try {
      final now = DateTime.now();
      await userProfileCache.saveProfile(profileDto, now);
      _logger.d('$_tag Saved profile for user $userId to cache at $now.');
    } catch (e) {
      _logger.e('$_tag Failed to save profile to cache for user $userId: $e');
    }
    return User(id: profileDto.id);
  }

  /// Attempts to fetch profile from cache during offline scenario.
  /// Checks token validity, clears cache if both invalid, otherwise returns cached User or throws.
  Future<User> _fetchProfileFromCacheOrThrow(
    String userId,
    AuthException originalNetworkException,
  ) async {
    // Check token validity
    bool accessValid = false;
    bool refreshValid = false;
    try {
      accessValid = await credentialsProvider.isAccessTokenValid();
      refreshValid = await credentialsProvider.isRefreshTokenValid();
      _logger.d(
        '$_tag Token validity for offline cache check (user $userId): access=$accessValid, refresh=$refreshValid',
      );
    } catch (tokenError) {
      _logger.e(
        '$_tag Error checking token validity during offline profile check for user $userId: $tokenError',
      );
      // Treat as invalid
    }

    // If BOTH tokens invalid, clear cache and throw
    if (!accessValid && !refreshValid) {
      _logger.w(
        '$_tag Both tokens invalid for user $userId during offline check. Clearing cache and throwing.',
      );
      try {
        await userProfileCache.clearProfile(userId);
      } catch (clearError) {
        _logger.e(
          '$_tag Failed to clear profile cache for user $userId after invalid tokens: $clearError',
        );
      }
      throw AuthException.unauthenticated('Both tokens expired');
    }

    // Try fetching from cache
    try {
      final cachedProfileDto = await userProfileCache.getProfile(userId);
      if (cachedProfileDto != null) {
        _logger.i(
          '$_tag Using cached profile for user $userId due to offline operation.',
        );
        return User(id: cachedProfileDto.id);
      } else {
        _logger.w(
          '$_tag Offline profile fetch failed for user $userId: No profile found in cache.',
        );
        // If no cached profile, throw the original network exception
        throw originalNetworkException;
      }
    } catch (cacheError) {
      _logger.e(
        '$_tag Error reading profile cache for user $userId during offline check: $cacheError',
      );
      // If cache read fails, throw the original network exception
      throw originalNetworkException;
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
