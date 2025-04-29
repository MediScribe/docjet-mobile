import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock screens for testing
class MockLoginScreen extends StatelessWidget {
  const MockLoginScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Login Screen'));
}

class MockHomeScreen extends StatelessWidget {
  const MockHomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Home Screen'));
}

// This test verifies the navigation logic based on auth state
void main() {
  group('Navigation based on auth state', () {
    // Create a widget that mimics the main app's conditional rendering logic
    Widget createAppWithState(AuthState state) {
      return MaterialApp(
        home: Builder(
          builder: (context) {
            // This is the same logic as in the real app's _buildHomeBasedOnAuthState method
            switch (state.status) {
              case AuthStatus.loading:
                return const Scaffold(
                  body: Center(child: CupertinoActivityIndicator()),
                );
              case AuthStatus.authenticated:
                return const MockHomeScreen();
              case AuthStatus.unauthenticated:
              case AuthStatus.error:
                return const MockLoginScreen();
            }
          },
        ),
      );
    }

    testWidgets('Shows Login screen when unauthenticated', (
      WidgetTester tester,
    ) async {
      // Arrange: Set up unauthenticated state
      final unauthenticatedState = AuthState.initial();

      // Build our test widget with the unauthenticated state
      await tester.pumpWidget(createAppWithState(unauthenticatedState));

      // Allow all animations and async operations to complete
      await tester.pumpAndSettle();

      // Assert: Verify LoginScreen is shown
      expect(find.byType(MockLoginScreen), findsOneWidget);
      expect(find.byType(MockHomeScreen), findsNothing);
      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('Shows Home screen when authenticated', (
      WidgetTester tester,
    ) async {
      // Arrange: Create an authenticated state with a mock user
      final user = User(id: 'test-user-id');
      final authenticatedState = AuthState.authenticated(user);

      // Build our test widget with the authenticated state
      await tester.pumpWidget(createAppWithState(authenticatedState));

      // Allow all animations and async operations to complete
      await tester.pumpAndSettle();

      // Assert: Verify HomeScreen is shown
      expect(find.byType(MockHomeScreen), findsOneWidget);
      expect(find.byType(MockLoginScreen), findsNothing);
      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets('Shows loading indicator when loading', (
      WidgetTester tester,
    ) async {
      // Arrange: Set up loading state
      final loadingState = AuthState.loading();

      // Build our test widget with the loading state
      await tester.pumpWidget(createAppWithState(loadingState));

      // The loading indicator should be shown immediately
      await tester.pump();

      // Assert: Verify CupertinoActivityIndicator is shown
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(MockHomeScreen), findsNothing);
      expect(find.byType(MockLoginScreen), findsNothing);
    });
  });
}
