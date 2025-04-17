import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_notifier.g.dart';

/// Manages authentication state for the application
///
/// This notifier connects the UI layer to the domain service
/// and encapsulates authentication state management.
@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  /// The authentication service used to perform authentication operations
  late final AuthService _authService;

  @override
  AuthState build() {
    // Get the auth service from the container
    _authService = ref.read(authServiceProvider);

    // Trigger initial check for existing authentication
    _checkAuthStatus();

    // Return initial state
    return AuthState.initial();
  }

  /// Attempts to log in with email and password
  Future<void> login(String email, String password) async {
    if (state.status == AuthStatus.loading) {
      return; // Prevent multiple login attempts
    }

    // Set loading state
    state = AuthState.loading();

    try {
      // Attempt login
      final user = await _authService.login(email, password);

      // Update state with authenticated user
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      // Handle authentication errors
      state = AuthState.error(e.message);
    } catch (e) {
      // Handle unexpected errors
      state = AuthState.error('An unexpected error occurred');
    }
  }

  /// Logs out the current user
  Future<void> logout() async {
    await _authService.logout();
    state = AuthState.initial();
  }

  /// Checks the current authentication status
  Future<void> _checkAuthStatus() async {
    final isAuthenticated = await _authService.isAuthenticated();

    if (isAuthenticated) {
      // Try to refresh the session to ensure we have a valid token
      final refreshed = await _authService.refreshSession();

      if (refreshed) {
        // We successfully refreshed, need to manually get user info since
        // we don't have it from login flow
        try {
          // In a real implementation, we'd call a getUserProfile method
          // on the auth service to get the full user details.
          // For now, we'll create a placeholder user
          final userId = 'existing-user';
          state = AuthState.authenticated(User(id: userId));
        } catch (e) {
          // If we can't get the user info, force logout
          await logout();
        }
      } else {
        // Session couldn't be refreshed, log out
        await logout();
      }
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
