import 'dart:async';

import 'package:docjet_mobile/core/auth/auth_error_mapper.dart';
import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/auth/transient_error.dart';
import 'package:docjet_mobile/core/auth/utils/api_path_matcher.dart';
import 'package:docjet_mobile/core/services/autofill_service.dart'; // Import AutofillService
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logger
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

  /// The authentication service used to perform authentication operations
  late final AuthService _authService;
  late final AuthEventBus _authEventBus;
  late final AutofillService _autofillService; // Add AutofillService
  StreamSubscription? _eventSubscription;

  @override
  AuthState build() {
    _logger.d('$_tag Building AuthNotifier...');
    // Get the auth service from the container
    _authService = ref.read(authServiceProvider);
    _authEventBus = ref.read(authEventBusProvider); // Read event bus
    _autofillService = ref.read(autofillServiceProvider); // Get AutofillService

    // Listen to auth events
    _listenToAuthEvents();

    // Initial auth check
    _checkAuthStatus();

    // Register dispose callback
    ref.onDispose(() {
      _logger.d('$_tag Disposing AuthNotifier, cancelling subscription.');
      _eventSubscription?.cancel();
      // Cancel any pending profile refresh timers to avoid leaks.
      _profileRefreshTimer?.cancel();
      _profileRefreshTimer = null;
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
    _profileRefreshTimer?.cancel();

    // Schedule a new refresh after a short delay
    _logger.d('$_tag Scheduling profile refresh after online restored');
    _profileRefreshTimer = Timer(const Duration(seconds: 1), () async {
      // Try to refresh profile regardless of current state
      // This covers cases where we're in ERROR state due to offline but
      // still have valid auth credentials
      _logger.i('$_tag Refreshing profile after coming back online');
      try {
        final userProfile = await _authService.getUserProfile();
        // Always transition to authenticated state with the fresh profile
        state = AuthState.authenticated(userProfile, isOffline: false);
        _logger.i('$_tag Profile refresh successful after online restored');
      } catch (e) {
        _logger.w('$_tag Profile refresh after online restore failed: $e');
        // Don't change state on failure, we've already transitioned to online
      }
    });
  }

  /// Clears the transient error from the state
  void clearTransientError() {
    _logger.d('$_tag Clearing transient error');
    state = state.copyWith(transientError: () => null);
  }

  /// Handles DioException by extracting relevant information and setting
  /// transient error when appropriate
  TransientError? _handleDioExceptionForTransientError(
    DioException e, {
    String context = 'API request',
  }) {
    final statusCode = e.response?.statusCode;
    _logger.d('$_tag DioException in $context, status: $statusCode');

    // Handle 404 on /users/profile specially as a transient error
    final isProfileEndpoint = ApiPathMatcher.isUserProfile(
      e.requestOptions.path,
    );
    if (statusCode == 404 && isProfileEndpoint) {
      return TransientError(
        message: 'Unable to fetch your profile. Please try again later.',
        type: AuthErrorType.userProfileFetchFailed,
      );
    }

    // Add other transient error cases here as needed
    return null;
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
    // First check if this can be handled as a transient error
    final transientError = _handleDioExceptionForTransientError(
      e,
      context: context,
    );

    _logger.e(
      '$_tag $context failed - DioException: ${e.message}, transient: ${transientError != null}',
      error: e,
      stackTrace: s,
    );

    if (transientError != null) {
      // For transient errors on profile fetch, we can still mark as authenticated
      // but with a placeholder user and the error
      return AuthState.authenticated(
        // Use anonymous user instead of magic string
        User.anonymous(),
        transientError: transientError,
      );
    } else {
      // For other DioExceptions, mark as error state
      return AuthState.error(
        'Failed to complete request. Please try again later.',
        errorType: AuthErrorType.network,
      );
    }
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
      // Use validateTokenLocally = false for initial check
      final isAuthenticated = await _authService.isAuthenticated();
      _logger.d('$_tag Is authenticated locally? $isAuthenticated');

      if (isAuthenticated) {
        _logger.d('$_tag Attempting to fetch user profile...');
        // If basic check passes, try getting profile (which implies token validity)
        try {
          final userProfile = await _authService.getUserProfile();
          _logger.i(
            '$_tag Profile fetched successfully for ID: ${userProfile.id}',
          );
          state = AuthState.authenticated(userProfile);
        } on DioException catch (e, s) {
          state = _mapDioExceptionToState(
            e,
            s,
            context: 'initial profile fetch',
          );
        }
      } else {
        _logger.i('$_tag Not authenticated locally.');
        state = AuthState.initial();
      }
    } on AuthException catch (e, s) {
      state = _mapAuthExceptionToState(e, s, context: 'Auth check');
    } catch (e, s) {
      state = _mapGenericExceptionToState(e, s, context: 'Auth check');
    }
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
