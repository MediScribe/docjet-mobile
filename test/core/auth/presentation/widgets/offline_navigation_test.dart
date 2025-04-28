import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock screens for testing
class MockLoginScreen extends StatelessWidget {
  const MockLoginScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Login Screen'));
}

class MockHomeScreen extends StatelessWidget {
  final bool isOffline;

  const MockHomeScreen({super.key, this.isOffline = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Column(
        children: [
          if (isOffline)
            Container(
              color: Colors.grey.shade300,
              padding: const EdgeInsets.all(8.0),
              width: double.infinity,
              child: const Text('You are offline'),
            ),
          const Expanded(child: Center(child: Text('Home Screen'))),
        ],
      ),
    );
  }
}

// Mock app that mimics routing logic based on auth state
class MockApp extends StatelessWidget {
  final AuthState authState;

  const MockApp({super.key, required this.authState});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: _buildHomeBasedOnAuthState());
  }

  Widget _buildHomeBasedOnAuthState() {
    switch (authState.status) {
      case AuthStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        return MockHomeScreen(isOffline: authState.isOffline);
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const MockLoginScreen();
    }
  }
}

void main() {
  group('Offline Mode Routing Tests', () {
    testWidgets('Authenticated offline user stays on HomeScreen', (
      WidgetTester tester,
    ) async {
      // Create an offline authenticated state with a mock user
      final user = User(id: 'test-user-id');
      final offlineAuthenticatedState = AuthState.authenticated(
        user,
        isOffline: true,
      );

      // Build the app with the offline authenticated state
      await tester.pumpWidget(MockApp(authState: offlineAuthenticatedState));

      // Allow all animations and async operations to complete
      await tester.pumpAndSettle();

      // Verify we stay on HomeScreen
      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('Login Screen'), findsNothing);

      // Verify offline banner is shown
      expect(find.text('You are offline'), findsOneWidget);
    });
  });
}
