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
import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/network/connectivity_error.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// Enum representing token validation states
enum TokenValidationResult { noneValid, accessOnly, refreshOnly, bothValid }

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
  /// Checks authentication status for the current session.
  ///
  /// If [validateTokenLocally] is `true`, performs a *full* local token
  /// validation (both access & refresh) without any network requests – used by
  /// offline-aware code paths.
  ///
  /// Otherwise follows a lightweight **fast-path**:
  ///  • Returns `false` when no access token exists or the token is already
  ///    expired.
  ///  • If the token expires within the next **30 seconds** (clock-skew
  ///    buffer) it tries a *single* silent [refreshSession] call and
  ///    returns that result.
  ///  • Returns `true` for clearly valid tokens outside the skew window.
  ///
  /// Any parsing, storage, or refresh error results in `false` to avoid
  /// mis-classifying an unauthenticated state.
  Future<bool> isAuthenticated({bool validateTokenLocally = false}) async {
    // FULL LOCAL VALIDATION ────────────────────────────────────────────────
    if (validateTokenLocally) {
      try {
        final bool isAccessValid =
            await credentialsProvider.isAccessTokenValid();
        if (isAccessValid) return true;

        // Fallback to refresh token validity – useful for offline mode.
        final bool isRefreshValid =
            await credentialsProvider.isRefreshTokenValid();
        return isRefreshValid;
      } on AuthException {
        rethrow; // Propagate as before
      } catch (_) {
        return false; // Any other error → unauthenticated
      }
    }

    // FAST-PATH ROUTE ──────────────────────────────────────────────────────
    // For calls WITHOUT explicit local validation we only do lightweight JWT
    // inspection plus optional silent refresh.

    // Fetch token; bail early if none is present.
    final accessToken = await credentialsProvider.getAccessToken();
    if (accessToken == null) {
      _logger.d('$_tag No access token present – unauthenticated (fast-path).');
      return false;
    }

    return _fastPathIsAuthenticated(accessToken);
  }

  /// Lightweight token inspection used by [isAuthenticated] when
  /// [validateTokenLocally] is `false`.
  ///
  /// Applies a 30-second clock-skew buffer and performs a *single* silent
  /// refresh if the token is near expiry.  Returns `true` when the token is
  /// clearly valid, otherwise `false`.
  Future<bool> _fastPathIsAuthenticated(String accessToken) async {
    try {
      final DateTime exp = JwtDecoder.getExpirationDate(accessToken);
      final DateTime now = DateTime.now();
      const Duration skew = Duration(seconds: 30);

      // Immediate expiry check.
      if (now.isAfter(exp)) {
        _logger.i('$_tag JWT expired at $exp – unauthenticated.');
        return false;
      }

      final Duration timeToExpiry = exp.difference(now);
      if (timeToExpiry <= skew) {
        _logger.i(
          '$_tag JWT expires in ${timeToExpiry.inSeconds}s (≤30s). Attempting silent refresh…',
        );
        final bool refreshed = await refreshSession();
        _logger.i(
          '$_tag Silent refresh ${refreshed ? "succeeded" : "failed"}.',
        );
        return refreshed;
      }

      // Token is definitively valid.
      _logger.d(
        '$_tag JWT valid (expires in ${timeToExpiry.inSeconds}s) – authenticated.',
      );
      return true;
    } catch (e) {
      _logger.w('$_tag Failed to parse JWT exp claim: $e – returning false.');
      return false;
    }
  }

  @override
  Future<User> getUserProfile({bool acceptOfflineProfile = true}) async {
    String? userId;
    _logger.i(
      '$_tag getUserProfile called (acceptOfflineProfile: $acceptOfflineProfile)',
    );
    try {
      userId = await _getUserIdOrThrow();
      _logger.d('$_tag Attempting to get profile for user: $userId');

      // Try fetching from network first
      _logger.d('$_tag Attempting online profile fetch for user: $userId');
      return await _fetchProfileFromNetworkAndCache(userId);
    } on AuthException catch (e) {
      _logger.w(
        '$_tag AuthException caught during profile fetch for user $userId: ${e.type}',
      );
      // Rethrow if not offline or offline not accepted
      if (e.type != AuthErrorType.offlineOperation || !acceptOfflineProfile) {
        _logger.w(
          '$_tag Propagating original AuthException (${e.type}) for user $userId (offline accepted: $acceptOfflineProfile).',
        );
        rethrow;
      }
      // If offline and accepted, try cache (userId must be non-null here)
      _logger.i(
        '$_tag Network unavailable for profile fetch (user $userId), checking cache...',
      );
      return await _fetchProfileFromCacheOrThrow(userId!, e);
    } on DioException catch (e) {
      _logger.w('$_tag DioException during profile fetch: ${e.type}');

      if (_isConnectivityError(e.type)) {
        _logger.w(
          '$_tag Classifying DioException as offline operation: ${e.message}',
        );
        final offlineException = AuthException.offlineOperationFailed(
          e.stackTrace,
        );

        // If offline profiles not accepted, just throw the offline error
        if (!acceptOfflineProfile) {
          _logger.w(
            '$_tag Offline profile not accepted, throwing AuthException.offlineOperationFailed for user $userId.',
          );
          throw offlineException;
        }

        // Otherwise try the cache
        _logger.i(
          '$_tag DioException indicates offline, trying cache for user $userId...',
        );
        // Ensure userId is retrieved before proceeding
        userId ??= await credentialsProvider.getUserId();
        if (userId == null) {
          _logger.e(
            '$_tag Cannot fetch profile from cache: User ID is null after DioException.',
          );
          throw AuthException.unauthenticated(
            'User ID not found after network failure.',
          );
        }
        return await _fetchProfileFromCacheOrThrow(userId, offlineException);
      }

      // For other DioExceptions, throw a profile fetch failed error
      _logger.e(
        '$_tag Non-connectivity DioException: ${e.type} - ${e.message}',
      );
      throw AuthException.userProfileFetchFailed(e.stackTrace);
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error fetching profile for user $userId: $e',
        stackTrace: stackTrace,
      );
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

  /// Fetches profile from network, updates cache on success.
  Future<User> _fetchProfileFromNetworkAndCache(String userId) async {
    _logger.d(
      '$_tag [_fetchProfileFromNetworkAndCache] Fetching profile online for user $userId...',
    );
    // Corrected: Call getUserProfile() with NO arguments
    final profileDto = await userApiClient.getUserProfile();

    // Verify the fetched profile ID matches the expected userId
    if (profileDto.id != userId) {
      _logger.e(
        '$_tag [_fetchProfileFromNetworkAndCache] Mismatched User ID! Expected $userId but API returned ${profileDto.id}. Throwing.',
      );
      // This indicates a serious inconsistency, treat as unauthenticated
      throw AuthException.unauthenticated(
        'Mismatched user ID returned from API.',
      );
    }

    try {
      _logger.d(
        '$_tag [_fetchProfileFromNetworkAndCache] Saving fetched profile DTO to cache for $userId...',
      );
      await userProfileCache.saveProfile(profileDto, DateTime.now());
      _logger.i(
        '$_tag [_fetchProfileFromNetworkAndCache] Profile DTO for $userId saved to cache.',
      );
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag [_fetchProfileFromNetworkAndCache] Failed to cache profile DTO for $userId after network fetch',
        error: e,
        stackTrace: stackTrace,
      );
    }
    // Corrected: Construct User using its standard constructor with the ID from DTO
    return User(id: profileDto.id);
  }

  /// Validates both tokens and returns their validation state
  Future<TokenValidationResult> _validateTokens() async {
    _logger.d('$_tag [_validateTokens] Retrieving tokens for validation...');

    // Get tokens just once and cache them for both validation and logging
    final accessToken = await credentialsProvider.getAccessToken();
    final refreshToken = await credentialsProvider.getRefreshToken();

    // Only log token presence in debug mode
    if (kDebugMode) {
      _logger.d(
        '$_tag [_validateTokens] Raw Access Token: ${accessToken == null ? "NULL" : "PRESENT"}',
      );
      _logger.d(
        '$_tag [_validateTokens] Raw Refresh Token: ${refreshToken == null ? "NULL" : "PRESENT"}',
      );
    }

    _logger.d('$_tag [_validateTokens] Validating Access Token...');
    final isAccessTokenValid = await credentialsProvider.isAccessTokenValid();
    _logger.d(
      '$_tag [_validateTokens] Access Token validation result: $isAccessTokenValid',
    );

    _logger.d('$_tag [_validateTokens] Validating Refresh Token...');
    final isRefreshTokenValid = await credentialsProvider.isRefreshTokenValid();
    _logger.d(
      '$_tag [_validateTokens] Refresh Token validation result: $isRefreshTokenValid',
    );

    if (isAccessTokenValid && isRefreshTokenValid) {
      return TokenValidationResult.bothValid;
    } else if (isAccessTokenValid) {
      return TokenValidationResult.accessOnly;
    } else if (isRefreshTokenValid) {
      return TokenValidationResult.refreshOnly;
    } else {
      return TokenValidationResult.noneValid;
    }
  }

  /// Attempts to get the profile from cache, returns null if not found
  Future<dynamic> _getCachedProfileOrThrow(String userId) async {
    _logger.d(
      '$_tag [_getCachedProfileOrThrow] Attempting to retrieve profile from cache for $userId.',
    );
    final cachedProfileDto = await userProfileCache.getProfile(userId);
    if (cachedProfileDto != null) {
      _logger.d(
        '$_tag [_getCachedProfileOrThrow] Found profile DTO in cache for user $userId.',
      );
      return cachedProfileDto;
    } else {
      _logger.w(
        '$_tag [_getCachedProfileOrThrow] Profile DTO not found in cache for $userId.',
      );
      return null;
    }
  }

  /// Fetches profile from cache, validates tokens, throws if invalid/expired.
  Future<User> _fetchProfileFromCacheOrThrow(
    String userId,
    AuthException originalException,
  ) async {
    _logger.d(
      '$_tag [_fetchProfileFromCacheOrThrow] Attempting fetch from cache for user $userId.',
    );

    // First, validate tokens to determine if we should use the cache
    final tokenValidationResult = await _validateTokens();

    // If neither token is valid, clear cache and throw unauthenticated
    if (tokenValidationResult == TokenValidationResult.noneValid) {
      _logger.e(
        '$_tag [_fetchProfileFromCacheOrThrow] Both tokens invalid for user $userId during offline check. Clearing cache and throwing.',
      );
      try {
        await userProfileCache.clearProfile(userId);
        _logger.d(
          '$_tag [_fetchProfileFromCacheOrThrow] Cleared cached profile for user $userId',
        );
      } catch (e, stackTrace) {
        _logger.e(
          '$_tag [_fetchProfileFromCacheOrThrow] Failed to clear profile cache for $userId after invalid tokens',
          error: e,
          stackTrace: stackTrace,
        );
        // Don't hide the original auth error
      }
      // Throw unauthenticated, as neither token is good
      _logger.w(
        '$_tag [_fetchProfileFromCacheOrThrow] Throwing AuthException.unauthenticated as fallback.',
      );
      throw AuthException.unauthenticated(
        'Offline check failed: Both tokens invalid.',
      );
    }

    // At least one token is valid, try to get profile from cache
    _logger.d(
      '$_tag [_fetchProfileFromCacheOrThrow] At least one token valid, attempting to retrieve profile from cache.',
    );
    final cachedProfileDto = await _getCachedProfileOrThrow(userId);

    if (cachedProfileDto != null) {
      // Corrected: Construct User using its standard constructor with the ID from DTO
      return User(id: cachedProfileDto.id);
    } else {
      _logger.w(
        '$_tag [_fetchProfileFromCacheOrThrow] Profile DTO not found in cache for $userId despite valid token(s). Rethrowing original error: ${originalException.type}',
      );
      throw originalException;
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

  /// Checks if a DioException type represents a connectivity issue.
  bool _isConnectivityError(DioExceptionType type) {
    return isNetworkConnectivityError(type);
  }
}
