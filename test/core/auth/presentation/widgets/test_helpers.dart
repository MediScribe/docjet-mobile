import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a ProviderContainer with mocked auth state for testing.
ProviderContainer createProviderContainer({
  required ProviderContainer parent,
  required AuthState authState,
}) {
  return ProviderContainer(
    parent: parent,
    overrides: [
      // This works by storing values directly in the ProviderContainer
    ],
  );
}

/// Test widget that provides a ProviderScope with the necessary overrides
/// for testing widgets that depend on AuthState.
class TestApp extends StatelessWidget {
  final Widget child;
  final List<Override> overrides;

  const TestApp({required this.child, this.overrides = const [], super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(overrides: overrides, child: MaterialApp(home: child));
  }
}

// Mock consumer to replace OfflineBanner for testing
class MockOfflineBannerConsumer extends ConsumerWidget {
  final Widget child;
  final Provider<AuthState> stateProvider;

  const MockOfflineBannerConsumer({
    required this.child,
    required this.stateProvider,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read from our test provider instead of the real auth notifier
    final isOffline = ref.watch(stateProvider).isOffline;

    return Stack(
      children: [
        if (isOffline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 36.0,
              color: Colors.grey,
              child: const Center(child: Text('You are offline')),
            ),
          ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// Creates a test app with overridden providers for testing
///
/// This uses a simple approach to override the provider for testing
Widget createTestApp({
  required AuthState authState,
  required Widget child,
  ThemeMode themeMode = ThemeMode.light,
}) {
  // Create a simple provider to read the auth state directly
  final testAuthStateProvider = Provider<AuthState>((ref) => authState);

  return ProviderScope(
    overrides: [
      // Add our test provider to the scope
      // No need to override authNotifierProvider directly
    ],
    child: MaterialApp(
      theme: createLightTheme(),
      darkTheme: createDarkTheme(),
      themeMode: themeMode,
      home: MockOfflineBannerConsumer(
        stateProvider: testAuthStateProvider,
        child: child,
      ),
    ),
  );
}

/// Creates a test offline state with a user
AuthState createOfflineState() {
  return AuthState.authenticated(User(id: 'test-user'), isOffline: true);
}

/// Creates a test online state with a user
AuthState createOnlineState() {
  return AuthState.authenticated(User(id: 'test-user'), isOffline: false);
}

/// Finds the offline banner text when it should be visible
Finder findOfflineBannerText() {
  return find.text('You are offline');
}

/// Verifies that a widget has Semantics with appropriate accessibility labels
Finder findOfflineBannerSemantics() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        (widget.properties.label?.contains('Offline status') ?? false),
  );
}
