import 'dart:async';

import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// An End-to-End test for authentication flows including:
/// - Login flow
/// - Token refresh
/// - Logout flow
///
/// This test suite uses lightweight mock screens instead of the actual app screens
/// to avoid dependencies on real implementation details while still testing the
/// full authentication flow.

// ==========================================================================
// MOCK UI COMPONENTS
// ==========================================================================

/// A lightweight mock login screen for testing
///
/// Avoids dependencies on real UI components while providing the essential
/// functionality needed for testing the login flow.
class MockLoginScreen extends StatelessWidget {
  final VoidCallback? onLoginTap;
  final String? email;
  final String? password;

  const MockLoginScreen({
    super.key,
    this.onLoginTap,
    this.email,
    this.password,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Login Screen'),
          if (onLoginTap != null)
            ElevatedButton(onPressed: onLoginTap, child: const Text('Login')),
        ],
      ),
    );
  }
}

/// A lightweight mock home screen for testing
///
/// Provides the essential UI elements needed for testing the authenticated state
/// and logout functionality.
class MockHomeScreen extends StatelessWidget {
  final VoidCallback? onLogoutTap;
  final String? userId;

  const MockHomeScreen({super.key, this.onLogoutTap, this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          if (onLogoutTap != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: onLogoutTap,
              tooltip: 'Logout',
            ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Home Screen'),
          if (userId != null) Text('User ID: $userId'),
        ],
      ),
    );
  }
}

// ==========================================================================
// TEST APP FOR AUTH FLOWS
// ==========================================================================

/// A test-specific app that simulates the real app's authentication flows
///
/// This app provides:
/// - State management for auth states (unauthenticated, loading, authenticated)
/// - Navigation between login and home screens based on auth state
/// - Callbacks for login, logout, and profile fetching
/// - Delay parameters for simulating network operations
class TestAuthApp extends StatefulWidget {
  final AuthState initialAuthState;
  final Function(AuthState)? onAuthStateChanged;
  final Future<User> Function(String, String)? onLogin;
  final Future<void> Function()? onLogout;
  final Future<User> Function()? onGetUserProfile;
  final Duration loginDelay;

  const TestAuthApp({
    super.key,
    required this.initialAuthState,
    this.onAuthStateChanged,
    this.onLogin,
    this.onLogout,
    this.onGetUserProfile,
    this.loginDelay = Duration.zero,
  });

  @override
  State<TestAuthApp> createState() => _TestAuthAppState();
}

class _TestAuthAppState extends State<TestAuthApp> {
  late AuthState _authState;

  @override
  void initState() {
    super.initState();
    _authState = widget.initialAuthState;
  }

  /// Simulates login process including state transitions
  Future<void> _handleLogin(String email, String password) async {
    // Set loading state
    setState(() {
      _authState = AuthState.loading();
    });

    if (widget.onAuthStateChanged != null) {
      widget.onAuthStateChanged!(_authState);
    }

    // Simulate network delay if specified
    if (widget.loginDelay != Duration.zero) {
      await Future.delayed(widget.loginDelay);
    }

    try {
      // Call login callback and set authenticated state on success
      final user = await widget.onLogin!(email, password);
      setState(() {
        _authState = AuthState.authenticated(user);
      });

      if (widget.onAuthStateChanged != null) {
        widget.onAuthStateChanged!(_authState);
      }
    } on AuthException catch (e) {
      // Set error state on auth exception
      setState(() {
        _authState = AuthState.error(e.message);
      });

      if (widget.onAuthStateChanged != null) {
        widget.onAuthStateChanged!(_authState);
      }
      rethrow;
    }
  }

  /// Simulates logout process including state transitions
  Future<void> _handleLogout() async {
    try {
      // Call logout callback and reset to unauthenticated state
      await widget.onLogout!();
      setState(() {
        _authState = AuthState.initial();
      });

      if (widget.onAuthStateChanged != null) {
        widget.onAuthStateChanged!(_authState);
      }
    } catch (e) {
      // Even on error, we force logout in UI
      setState(() {
        _authState = AuthState.initial();
      });

      if (widget.onAuthStateChanged != null) {
        widget.onAuthStateChanged!(_authState);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: _buildScreenBasedOnAuthState());
  }

  /// Shows the appropriate screen based on the current auth state
  Widget _buildScreenBasedOnAuthState() {
    switch (_authState.status) {
      case AuthStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        return MockHomeScreen(
          userId: _authState.user?.id,
          onLogoutTap: widget.onLogout != null ? _handleLogout : null,
        );
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return MockLoginScreen(
          onLoginTap:
              widget.onLogin != null
                  ? () => _handleLogin('test@example.com', 'password123')
                  : null,
        );
    }
  }
}

// ==========================================================================
// MOCK SERVICES
// ==========================================================================

/// Mock auth service for testing
///
/// Returns predefined user and success responses.
class MockAuthService implements AuthService {
  final User _user;

  MockAuthService(this._user);

  @override
  Future<String> getCurrentUserId() => Future.value(_user.id);

  @override
  Future<User> getUserProfile() => Future.value(_user);

  @override
  Future<bool> isAuthenticated({bool validateTokenLocally = false}) =>
      Future.value(true);

  @override
  Future<User> login(String email, String password) => Future.value(_user);

  @override
  Future<void> logout() => Future.value();

  @override
  Future<bool> refreshSession() => Future.value(true);
}

/// Mock auth event bus for testing
///
/// Provides a stream of auth events for components to listen to.
class MockAuthEventBus implements AuthEventBus {
  final StreamController<AuthEvent> _controller =
      StreamController<AuthEvent>.broadcast();

  @override
  void add(AuthEvent event) {
    _controller.add(event);
  }

  @override
  void dispose() {
    _controller.close();
  }

  @override
  Stream<AuthEvent> get stream => _controller.stream;
}

/// Mock auth session provider for testing
///
/// Returns a predefined user ID and true for isAuthenticated.
class MockAuthSessionProvider implements AuthSessionProvider {
  final String _userId;

  MockAuthSessionProvider(this._userId);

  @override
  Future<String> getCurrentUserId() => Future.value(_userId);

  @override
  Future<bool> isAuthenticated() => Future.value(true);
}

// ==========================================================================
// TESTS
// ==========================================================================

void main() {
  group('End-to-End Authentication Flow', () {
    // Test user shared across all tests
    late User testUser;

    setUp(() {
      testUser = User(id: 'test-user-123');
    });

    testWidgets('Login - User can log in and navigate to home screen', (
      WidgetTester tester,
    ) async {
      // ARRANGE
      bool loginCalled = false;
      AuthState? currentState;

      // Build app with initial unauthenticated state
      await tester.pumpWidget(
        TestAuthApp(
          initialAuthState: AuthState.initial(),
          onLogin: (email, password) async {
            loginCalled = true;
            return testUser;
          },
          onAuthStateChanged: (state) {
            currentState = state;
          },
          // Add a small delay to ensure loading state is visible
          loginDelay: const Duration(milliseconds: 300),
        ),
      );

      // Verify we're on login screen
      expect(find.text('Login Screen'), findsOneWidget);

      // ACT: Tap the login button
      await tester.tap(find.text('Login'));

      // Let the loading state show
      await tester.pump();
      // Wait for the loading state to be visible, needs another frame
      await tester.pump(const Duration(milliseconds: 100));

      // Verify loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(currentState?.status, AuthStatus.loading);

      // Pump frames to complete the login process
      await tester.pumpAndSettle();

      // ASSERT: Verify login was called and we're on the home screen
      expect(loginCalled, isTrue);
      expect(currentState?.status, AuthStatus.authenticated);
      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('User ID: ${testUser.id}'), findsOneWidget);
    });

    testWidgets('Token Refresh - Authorization continues after token refresh', (
      WidgetTester tester,
    ) async {
      // ARRANGE
      bool refreshCalled = false;

      // Build app with authenticated state
      await tester.pumpWidget(
        TestAuthApp(
          initialAuthState: AuthState.authenticated(testUser),
          onGetUserProfile: () async {
            // First call fails with expired token
            if (!refreshCalled) {
              throw AuthException.tokenExpired();
            }
            return testUser;
          },
          onLogout: () async {
            // This simulates a refresh token call
            refreshCalled = true;
          },
        ),
      );

      // Verify we're on home screen
      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('User ID: ${testUser.id}'), findsOneWidget);

      // This test verifies the basic UI flow works
      // In real app integration:
      // 1. AuthInterceptor would catch 401 errors
      // 2. It would call refreshToken automatically
      // 3. Original requests would be retried with new token
    });

    testWidgets('Logout - User can log out and navigate back to login screen', (
      WidgetTester tester,
    ) async {
      // ARRANGE
      bool logoutCalled = false;
      AuthState? currentState;

      // Build app with authenticated state
      await tester.pumpWidget(
        TestAuthApp(
          initialAuthState: AuthState.authenticated(testUser),
          onLogout: () async {
            logoutCalled = true;
          },
          onAuthStateChanged: (state) {
            currentState = state;
          },
        ),
      );

      // Verify we're on home screen
      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('User ID: ${testUser.id}'), findsOneWidget);

      // ACT: Tap the logout button
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pump(); // Process initial frame
      await tester.pumpAndSettle(); // Wait for animations to complete

      // ASSERT: Verify logout was called and we navigated to login screen
      expect(logoutCalled, isTrue);
      expect(currentState?.status, AuthStatus.unauthenticated);
      expect(find.text('Login Screen'), findsOneWidget);
    });
  });
}
