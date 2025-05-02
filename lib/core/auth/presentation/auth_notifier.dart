import 'dart:async';

import 'package:docjet_mobile/core/auth/auth_error_mapper.dart';
import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/auth/utils/api_path_matcher.dart';
import 'package:docjet_mobile/core/common/notifiers/app_notifier_service.dart';
import 'package:docjet_mobile/core/common/models/app_message.dart';
import 'package:docjet_mobile/core/services/autofill_service.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
// Import for TextInput

part 'auth_notifier.g.dart';

/// Manages authentication state for the application
///
/// This notifier connects the UI layer to the domain service
/// and encapsulates authentication state management.
@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  /// Logger setup
  static final String _tag = logTag(AuthNotifier);
  final Logger _logger = LoggerFactory.getLogger(AuthNotifier);

  /// Standard error message for profile fetch failures
  static const String _profileFetchErrorMessage =
      'Unable to fetch your profile. Please try again later.';

  /// The authentication service used to perform authentication operations
  late final AuthService _authService;
  late final AuthEventBus _authEventBus;
  late final AutofillService _autofillService; // Add AutofillService
  late final AppNotifierService
  _appNotifierService; // Add AppNotifierService field
  StreamSubscription? _eventSubscription;

  @override
  AuthState build() {
    _logger.d('$_tag Building AuthNotifier...');
    // Get the auth service from the container
    _authService = ref.read(authServiceProvider);
    _authEventBus = ref.read(authEventBusProvider);
    _autofillService = ref.read(autofillServiceProvider);
    _appNotifierService = ref.read(appNotifierServiceProvider.notifier);

    // Listen to auth events
    _listenToAuthEvents();

    // Initial auth check
    _checkAuthStatus();

    // Register dispose callback
    ref.onDispose(() {
      _logger.d('$_tag Disposing AuthNotifier, cancelling subscription.');
      _eventSubscription?.cancel();
      // Cancel any pending profile refresh timers to avoid leaks.
      _cancelProfileRefreshTimer();
    });

    // Return initial state
    return AuthState.initial();
  }

  void _listenToAuthEvents() {
    _eventSubscription?.cancel(); // Cancel previous subscription if any
    _eventSubscription = _authEventBus.stream.listen((event) {
      // --- HARDCORE DEBUG LOG ---
      _logger.f('$_tag !!! RECEIVED EVENT VIA BUS: $event !!!');
      // --- END HARDCORE DEBUG LOG ---
      _logger.d('$_tag Received auth event: $event');
      switch (event) {
        case AuthEvent.loggedOut:
          if (state.status != AuthStatus.unauthenticated) {
            _logger.i('$_tag Received loggedOut event, resetting state.');
            state = AuthState.initial();
          }
          break;

        case AuthEvent.offlineDetected:
          _logger.i('$_tag Received offlineDetected event, updating state.');
          _setOffline(true);
          break;

        case AuthEvent.onlineRestored:
          _logger.i('$_tag Received onlineRestored event, updating state.');
          _setOffline(false);

          // Refresh profile when coming back online
          _refreshProfileAfterOnlineRestored();
          break;

        case AuthEvent.loggedIn:
          // We don't need to do anything special for loggedIn events currently
          // The state is already updated by the login method
          _logger.d(
            '$_tag Received loggedIn event, no additional action needed.',
          );
          break;
      }
    });
    _logger.i('$_tag Subscribed to AuthEventBus stream.');
  }

  /// Updates the offline status across all states
  ///
  /// This method ensures that the offline flag is updated consistently
  /// regardless of the current state (authenticated, error, loading, etc.)
  void _setOffline(bool flag) {
    switch (state.status) {
      case AuthStatus.authenticated:
        // Use copyWith to preserve other potential state attributes
        state = state.copyWith(isOffline: flag);
        break;

      case AuthStatus.error:
        state = state.copyWith(isOffline: flag);
        break;

      case AuthStatus.unauthenticated:
      case AuthStatus.loading:
        // Update offline flag for all other states too
        state = state.copyWith(isOffline: flag);
        break;
    }
  }

  /// Refreshes the user profile after coming back online
  /// Uses a simple debounce pattern to avoid API spam
  Timer? _profileRefreshTimer;
  void _refreshProfileAfterOnlineRestored() {
    // Cancel any pending refresh
    _cancelProfileRefreshTimer();

    // Schedule a new refresh after a short delay
    _logger.d('$_tag Scheduling profile refresh after online restored');
    _profileRefreshTimer = Timer(const Duration(seconds: 1), () async {
      await _executeProfileRefreshAfterOnlineRestored();
      _cancelProfileRefreshTimer();
    });
  }

  /// Cancels the profile refresh timer if active and nulls the reference
  void _cancelProfileRefreshTimer() {
    _profileRefreshTimer?.cancel();
    _profileRefreshTimer = null;
  }

  /// Executes the profile refresh process after online connection is restored
  /// Separated from the timer callback for better testability and code organization
  Future<void> _executeProfileRefreshAfterOnlineRestored() async {
    _logger.i('$_tag Refreshing profile after coming back online');
    try {
      // First validate token with the server
      if (!await _validateTokenWithServer()) {
        return; // Already handled state transition
      }

      // Token is valid, fetch fresh profile
      await _fetchAndUpdateProfileAfterOnlineRestored();
    } on AuthException catch (e, s) {
      _handleAuthExceptionDuringOnlineRestoration(e, s);
    } catch (e, s) {
      _handleGeneralExceptionDuringOnlineRestoration(e, s);
    }
  }

  /// Validates the authentication token with the server
  /// Returns true if token is valid, false otherwise
  /// Updates state to unauthenticated if token is invalid
  Future<bool> _validateTokenWithServer() async {
    _logger.d('$_tag Validating token with server via refreshSession()');
    try {
      final tokenValid = await _authService.refreshSession();

      if (!tokenValid) {
        _logger.w('$_tag Token rejected by server during online restoration');
        state = AuthState.initial();
        return false;
      }

      _logger.d('$_tag Token validated successfully by server');
      return true;
    } on AuthException catch (e) {
      if (e.type == AuthErrorType.tokenExpired ||
          e.type == AuthErrorType.unauthenticated ||
          e.type == AuthErrorType.refreshTokenInvalid) {
        _logger.w('$_tag Server rejected token during validation: ${e.type}');
        state = AuthState.initial();
        return false;
      }

      // For other auth exceptions (like network issues), rethrow to be handled upstream
      rethrow;
    }
  }

  /// Fetches a fresh profile from the server and updates state
  Future<void> _fetchAndUpdateProfileAfterOnlineRestored() async {
    _logger.d('$_tag Fetching fresh profile from server');
    final userProfile = await _authService.getUserProfile();

    // Always transition to authenticated state with the fresh profile
    state = AuthState.authenticated(userProfile, isOffline: false);
    _logger.i('$_tag Profile refresh successful after online restored');
  }

  /// Handles authentication exceptions during online restoration
  void _handleAuthExceptionDuringOnlineRestoration(
    AuthException e,
    StackTrace s,
  ) {
    _logger.w('$_tag Online restoration failed with AuthException: $e');

    if (e.type == AuthErrorType.tokenExpired ||
        e.type == AuthErrorType.unauthenticated ||
        e.type == AuthErrorType.refreshTokenInvalid) {
      // Token is invalid or expired, reset to unauthenticated state
      _logger.w(
        '$_tag Token validation failed: ${e.type}, resetting to unauthenticated',
      );
      state = AuthState.initial();
    } else {
      // Handle other auth errors (like network issues)
      state = _mapAuthExceptionToState(e, s, context: 'online profile refresh');
    }
  }

  /// Handles general exceptions during online restoration
  void _handleGeneralExceptionDuringOnlineRestoration(Object e, StackTrace s) {
    _logger.w('$_tag Online restoration failed with general exception: $e');

    if (e is DioException) {
      state = _mapDioExceptionToState(e, s, context: 'online profile refresh');
    } else {
      // For other exceptions, just log and keep current state
      _logger.e(
        '$_tag Unexpected error during online profile refresh',
        error: e,
        stackTrace: s,
      );

      // Show an error notification but don't change auth state
      _appNotifierService.show(
        message: 'Unable to refresh your profile. Please try again later.',
        type: MessageType.error,
      );
    }
  }

  /// Maps an authentication exception to the appropriate auth state
  AuthState _mapAuthExceptionToState(
    AuthException e,
    StackTrace s, {
    String context = 'auth operation',
  }) {
    final isOffline = e.type == AuthErrorType.offlineOperation;
    final errorType = AuthErrorMapper.getErrorTypeFromException(e);

    _logger.e(
      '$_tag $context failed - AuthException, offline: $isOffline, type: $errorType',
      error: e,
      stackTrace: s,
    );

    return AuthState.error(
      e.message,
      isOffline: isOffline,
      errorType: errorType,
    );
  }

  /// Maps a DioException to the appropriate auth state
  AuthState _mapDioExceptionToState(
    DioException e,
    StackTrace s, {
    String context = 'API request',
  }) {
    // First check if this is a transient profile fetch error
    final statusCode = e.response?.statusCode;
    final isProfileEndpoint = ApiPathMatcher.isUserProfile(
      e.requestOptions.path,
    );

    _logger.e(
      '$_tag $context failed - DioException: ${e.message}',
      error: e,
      stackTrace: s,
    );

    if (statusCode == 404 && isProfileEndpoint) {
      _logger.w('$_tag Handling profile fetch 404 as transient error.');
      // Show transient message using the app notifier service
      _appNotifierService.show(
        message: _profileFetchErrorMessage,
        type: MessageType.error,
        // Optional: Add a duration if desired
        // duration: const Duration(seconds: 5),
      );
      // Return authenticated state but with anonymous user (profile failed)
      // DO NOT set transientError here anymore
      return AuthState.authenticated(User.anonymous());
    }

    // For other DioExceptions, mark as error state
    // Potentially show a generic error message via notifier as well?
    _appNotifierService.show(
      message: 'Network request failed. Please try again later.',
      type: MessageType.error,
    );

    return AuthState.error(
      'Failed to complete request. Please try again later.',
      errorType: AuthErrorType.network,
    );
  }

  /// Maps a generic exception to an auth state
  AuthState _mapGenericExceptionToState(
    Object e,
    StackTrace s, {
    String context = 'operation',
  }) {
    _logger.e(
      '$_tag $context failed - Unexpected error',
      error: e,
      stackTrace: s,
    );

    return AuthState.error(
      'An unexpected error occurred. Please try again.',
      errorType: AuthErrorType.unknown,
    );
  }

  /// Attempts to log in with email and password
  Future<void> login(String email, String password) async {
    if (state.status == AuthStatus.loading) {
      _logger.w('$_tag Login attempt ignored, already loading.');
      return; // Prevent multiple login attempts
    }

    _logger.i('$_tag Attempting login for email: $email');
    // Set loading state
    state = AuthState.loading();

    try {
      // Attempt login
      await _authService.login(email, password);
      _logger.d('$_tag Login successful, fetching user profile...');
      // Fetch full profile after successful login
      final userProfile = await _authService.getUserProfile();

      // Signal autofill context completion upon successful login
      // This tells iOS/Password Managers that the entered credentials were valid
      // and can now be saved or updated.
      _autofillService.completeAutofillContext(shouldSave: true);

      state = AuthState.authenticated(userProfile);
      _logger.i(
        '$_tag Login successful, user profile fetched for ID: ${userProfile.id}',
      );
    } on AuthException catch (e, s) {
      state = _mapAuthExceptionToState(e, s, context: 'Login');
    } on DioException catch (e, s) {
      state = _mapDioExceptionToState(e, s, context: 'login flow');
    } catch (e, s) {
      state = _mapGenericExceptionToState(e, s, context: 'Login');
    }
  }

  /// Logs out the current user
  Future<void> logout() async {
    _logger.i('$_tag Logout requested.');
    // The service handles token clearing and event emission.
    // The listener (_listenToAuthEvents) will reset the state.
    try {
      await _authService.logout();
      _logger.i('$_tag Logout call successful (state reset via event).');
    } on AuthException catch (e, s) {
      // Handle potential logout errors (e.g., network issues if it calls API)
      final isOffline = e.type == AuthErrorType.offlineOperation;
      final errorType = AuthErrorMapper.getErrorTypeFromException(e);
      _logger.e(
        '$_tag Logout failed - AuthException, offline: $isOffline, type: $errorType',
        error: e,
        stackTrace: s,
      );
      // Decide on state: maybe stay authenticated but show error?
      // For now, forcefully go to initial state regardless of error, as the main goal is logout.
      if (state.status != AuthStatus.unauthenticated) {
        state = AuthState.initial();
      }
    } catch (e, s) {
      _logger.e(
        '$_tag Logout failed - Unexpected error',
        error: e,
        stackTrace: s,
      );
      // Force state reset even on logout failure
      if (state.status != AuthStatus.unauthenticated) {
        state = AuthState.initial();
      }
    }
  }

  /// Checks the current authentication status
  Future<void> _checkAuthStatus() async {
    _logger.i('$_tag Checking initial auth status...');
    try {
      // First use validateTokenLocally = false for backward compatibility with existing tests
      final isAuthenticated = await _authService.isAuthenticated(
        validateTokenLocally: false,
      );
      _logger.d('$_tag Is authenticated with basic check? $isAuthenticated');

      if (isAuthenticated) {
        _logger.d('$_tag Attempting to fetch user profile...');
        try {
          // For compatibility with existing tests, call without acceptOfflineProfile
          final userProfile = await _authService.getUserProfile();

          _logger.i(
            '$_tag Profile fetched successfully for ID: ${userProfile.id}',
          );

          state = AuthState.authenticated(userProfile);
        } on AuthException catch (e, s) {
          state = _mapAuthExceptionToState(e, s, context: 'profile fetch');
        } on DioException catch (e, s) {
          // This is needed for the existing tests that check DioException handling
          state = _mapDioExceptionToState(
            e,
            s,
            context: 'initial profile fetch',
          );
        } catch (e, s) {
          state = _mapGenericExceptionToState(e, s, context: 'Profile fetch');
        }
      } else {
        // Try again with validateTokenLocally = true for our new offline-aware behavior
        await _tryOfflineAwareAuthentication();
      }
    } on AuthException catch (e, s) {
      state = _mapAuthExceptionToState(e, s, context: 'Auth check');
    } catch (e, s) {
      state = _mapGenericExceptionToState(e, s, context: 'Auth check');
    }
  }

  /// Attempts offline-aware authentication with local token validation
  Future<void> _tryOfflineAwareAuthentication() async {
    final isAuthenticatedOffline = await _authService.isAuthenticated(
      validateTokenLocally: true,
    );
    _logger.d(
      '$_tag Is authenticated with local token validation? $isAuthenticatedOffline',
    );

    if (!isAuthenticatedOffline) {
      _logger.i('$_tag Not authenticated with any validation method.');
      state = AuthState.initial();
      return;
    }

    _logger.d(
      '$_tag Attempting to fetch user profile with offline fallback...',
    );
    try {
      // Try getting profile with offline fallback enabled
      final userProfile = await _authService.getUserProfile(
        acceptOfflineProfile: true,
      );

      // Check if we're getting an offline profile
      final isOfflineProfile = await _checkIfNetworkIsUnavailable();

      _logger.i(
        '$_tag Profile fetched successfully for ID: ${userProfile.id}, offline: $isOfflineProfile',
      );

      // Update auth state with user profile and offline flag
      state = AuthState.authenticated(userProfile, isOffline: isOfflineProfile);
    } on AuthException catch (e, s) {
      _handleAuthExceptionDuringOfflineAuth(e, s);
    } catch (e, s) {
      _handleCorruptedProfileCache(e, s);
    }
  }

  /// Detects if network is unavailable by attempting a network-only profile fetch
  Future<bool> _checkIfNetworkIsUnavailable() async {
    try {
      // Try a quick network-only fetch to see if we're offline
      await _authService.getUserProfile(acceptOfflineProfile: false);
      return false; // Network is available
    } on AuthException catch (e) {
      final isOffline = e.type == AuthErrorType.offlineOperation;
      if (isOffline) {
        _logger.i('$_tag Using offline profile due to network unavailability');
      }
      return isOffline;
    } catch (e) {
      _logger.d(
        '$_tag Network check resulted in error, but not an offline error: $e',
      );
      return false; // Assume network is available
    }
  }

  /// Handles auth exceptions during offline auth flow
  void _handleAuthExceptionDuringOfflineAuth(AuthException e, StackTrace s) {
    // Handle specific auth exceptions like token expired/invalid
    if (e.type == AuthErrorType.tokenExpired ||
        e.type == AuthErrorType.unauthenticated ||
        e.type == AuthErrorType.refreshTokenInvalid) {
      _logger.w('$_tag Token validation failed during auth check: ${e.type}');
      state = AuthState.initial();
    } else {
      state = _mapAuthExceptionToState(e, s, context: 'profile fetch');
    }
  }

  /// Handles corrupted profile cache or other unexpected errors
  void _handleCorruptedProfileCache(Object e, StackTrace s) {
    _logger.e(
      '$_tag Error fetching profile (possible cache corruption): $e',
      error: e,
      stackTrace: s,
    );

    // Show error notification but keep user authenticated with anonymous profile
    _appNotifierService.show(
      message: 'Unable to load your profile. Some features may be limited.',
      type: MessageType.error,
    );

    // Still authenticate the user but with anonymous profile
    state = AuthState.authenticated(User.anonymous());
  }
}

/// Provider for the AuthService
///
/// This should be overridden in the widget tree with the actual implementation.
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  throw UnimplementedError(
    'authServiceProvider has not been overridden. '
    'Make sure to override this in your main.dart with an implementation.',
  );
}

/// Provider for the AuthEventBus
///
/// This should be overridden in the widget tree with the actual implementation.
@Riverpod(keepAlive: true)
AuthEventBus authEventBus(Ref ref) {
  throw UnimplementedError(
    'authEventBusProvider has not been overridden. '
    'Make sure to override this in your main.dart with an implementation.',
  );
}

/// Provider for the AutofillService
///
/// This should be overridden in the widget tree with the actual implementation.
@Riverpod(keepAlive: true)
AutofillService autofillService(Ref ref) {
  // Provide a default implementation to avoid the need for overriding in
  // every test. Production code can still override this provider to inject a
  // platform-specific instance if needed.
  return AutofillServiceImpl();
}
