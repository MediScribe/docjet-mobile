import 'dart:async';

import 'package:docjet_mobile/core/auth/auth_error_mapper.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
// import 'package:docjet_mobile/core/auth/entities/user.dart'; // Removed unused import
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/di/injection_container.dart'; // Assuming provider is here
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logger
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
  StreamSubscription? _eventSubscription;

  @override
  AuthState build() {
    _logger.d('$_tag Building AuthNotifier...');
    // Get the auth service from the container
    _authService = ref.read(authServiceProvider);
    _authEventBus = ref.read(authEventBusProvider); // Read event bus

    // Listen to auth events
    _listenToAuthEvents();

    // Initial auth check
    _checkAuthStatus();

    // Register dispose callback
    ref.onDispose(() {
      _logger.d('$_tag Disposing AuthNotifier, cancelling subscription.');
      _eventSubscription?.cancel();
    });

    // Return initial state
    return AuthState.initial();
  }

  void _listenToAuthEvents() {
    _eventSubscription?.cancel(); // Cancel previous subscription if any
    _eventSubscription = _authEventBus.stream.listen((event) {
      _logger.d('$_tag Received auth event: $event');
      if (event == AuthEvent.loggedOut) {
        if (state.status != AuthStatus.unauthenticated) {
          _logger.i('$_tag Received loggedOut event, resetting state.');
          state = AuthState.initial();
        }
      }
      // Handle other events like loggedIn if needed
    });
    _logger.i('$_tag Subscribed to AuthEventBus stream.');
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
      state = AuthState.authenticated(userProfile);
      _logger.i(
        '$_tag Login successful, user profile fetched for ID: ${userProfile.id}',
      );
    } on AuthException catch (e, s) {
      final isOffline = e == AuthException.offlineOperationFailed();
      final errorType = AuthErrorMapper.getErrorTypeFromException(e);
      _logger.e(
        '$_tag Login failed - AuthException, offline: $isOffline, type: $errorType',
        error: e,
        stackTrace: s,
      );
      state = AuthState.error(
        e.message,
        isOffline: isOffline,
        errorType: errorType,
      );
    } catch (e, s) {
      _logger.e(
        '$_tag Login failed - Unexpected error',
        error: e,
        stackTrace: s,
      );
      state = AuthState.error('An unexpected error occurred during login');
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
      final isOffline = e == AuthException.offlineOperationFailed();
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
        final userProfile = await _authService.getUserProfile();
        _logger.i(
          '$_tag Profile fetched successfully for ID: ${userProfile.id}',
        );
        state = AuthState.authenticated(userProfile);
      } else {
        _logger.i('$_tag Not authenticated locally.');
        state = AuthState.initial();
      }
    } on AuthException catch (e, s) {
      final isOffline = e == AuthException.offlineOperationFailed();
      final errorType = AuthErrorMapper.getErrorTypeFromException(e);
      _logger.w(
        '$_tag Auth check failed - AuthException, offline: $isOffline, type: $errorType',
        error: e,
        stackTrace: s,
      );
      // If check fails (e.g., token invalid, profile fetch fail), treat as unauthenticated
      // but potentially flag offline status.
      // If offline, we might want a different state, but for now, error seems appropriate.
      state = AuthState.error(
        e.message,
        isOffline: isOffline,
        errorType: errorType,
      );
      // Consider calling logout to ensure tokens are cleared if refresh/profile fetch fails
      // await _authService.logout(); // Potentially trigger this? But event bus might handle it.
    } catch (e, s) {
      _logger.e(
        '$_tag Auth check failed - Unexpected error',
        error: e,
        stackTrace: s,
      );
      state = AuthState.error(
        'An unexpected error occurred checking auth status',
      );
      // await _authService.logout(); // Force clear state on unexpected error?
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
