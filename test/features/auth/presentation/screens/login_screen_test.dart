import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/cupertino.dart';
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

  @override
  void clearTransientError() {}

  // Need to implement the generated methods/properties if using _$AuthNotifier
  // For simplicity here, we assume direct implementation is sufficient if
  // the AuthNotifier interface doesn't rely on ref/internals for basic state reading.
  // If tests fail due to missing generated members, extend _$AuthNotifier instead.
}

// Helper function for creating the widget with theme
Widget createTestWidget(WidgetRef? ref, AuthState state) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => MockAuthNotifier(state)),
    ],
    child: MaterialApp(theme: createLightTheme(), home: const LoginScreen()),
  );
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

      // Act: Build the widget tree with proper theme
      await tester.pumpWidget(createTestWidget(null, offlineState));

      // Act: Let the UI rebuild
      await tester.pump();

      // Assert: Check for the login UI elements AND the offline indicator
      expect(find.text('DocJet Login'), findsOneWidget);
      expect(find.text('Offline Mode'), findsOneWidget);
    },
  );

  testWidgets('LoginScreen displays invalid credentials error message', (
    WidgetTester tester,
  ) async {
    // Arrange: Define the invalid credentials error state
    final invalidCredentialsException = AuthException.invalidCredentials();
    final errorState = AuthState.error(
      invalidCredentialsException.message,
      errorType: AuthErrorType.invalidCredentials,
    );

    // Act: Build the widget with proper theme
    await tester.pumpWidget(createTestWidget(null, errorState));

    // Act: Let the UI rebuild
    await tester.pump();

    // Assert: Check for the error message
    expect(
      find.text('Invalid email or password. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('LoginScreen displays network error message', (
    WidgetTester tester,
  ) async {
    // Arrange: Define the network error state
    final networkException = AuthException.networkError();
    final errorState = AuthState.error(
      networkException.message,
      errorType: AuthErrorType.network,
    );

    // Act: Build the widget with proper theme
    await tester.pumpWidget(createTestWidget(null, errorState));

    // Act: Let the UI rebuild
    await tester.pump();

    // Assert: Check for the error message
    expect(
      find.text('Network error. Please check your connection and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('LoginScreen displays loading indicator during authentication', (
    WidgetTester tester,
  ) async {
    // Arrange: Define the loading state
    final loadingState = AuthState.loading();

    // Act: Build the widget with proper theme
    await tester.pumpWidget(createTestWidget(null, loadingState));

    // Act: Let the UI rebuild
    await tester.pump();

    // Assert: Check for the loading indicator
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });
}
