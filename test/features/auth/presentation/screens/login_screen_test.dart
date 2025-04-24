import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock AuthNotifier for testing specific states
// It needs to correctly implement the Notifier interface methods expected by Riverpod
// Changed from AutoDisposeNotifier to Notifier to match the keepAlive=true provider
class MockAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  MockAuthNotifier(this.initialState);

  final AuthState initialState;

  @override
  AuthState build() {
    // This build method is required by the Notifier interface.
    // It sets the initial state for the mock.
    return initialState;
  }

  // Keep other methods as no-op as they are not called in this specific test
  // (since we only care about the initial state provided)
  Future<void> checkAuthStatus() async {}

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> logout() async {}

  // Need to implement the generated methods/properties if using _$AuthNotifier
  // For simplicity here, we assume direct implementation is sufficient if
  // the AuthNotifier interface doesn't rely on ref/internals for basic state reading.
  // If tests fail due to missing generated members, extend _$AuthNotifier instead.
}

void main() {
  testWidgets(
    'LoginScreen displays offline indicator when auth state is offline error',
    (WidgetTester tester) async {
      // Arrange: Define the offline error state
      final offlineStateException = AuthException.offlineOperationFailed();
      final offlineState = AuthState.error(
        offlineStateException.message,
        isOffline: true,
      );

      // Arrange: Build the widget tree with ProviderScope and override
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Use overrideWith and provide the MockAuthNotifier instance
            authNotifierProvider.overrideWith(
              () => MockAuthNotifier(offlineState),
            ),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      // Act: Let the UI rebuild
      await tester.pump();

      // Assert: Check for the placeholder text AND the offline indicator
      expect(find.text('Login Screen Placeholder'), findsOneWidget);
      expect(find.text('Offline Mode'), findsOneWidget);
    },
  );
}
