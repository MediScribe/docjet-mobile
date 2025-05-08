import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/platform/network_info_provider.dart';
import 'package:docjet_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart';

class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo(this.connected);
  final bool connected;

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

// ---------------------------------------------------------------------------
// Test stubs
// ---------------------------------------------------------------------------

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(this._offline);
  final bool _offline;

  @override
  AuthState build() => AuthState.initial().copyWith(isOffline: _offline);

  // Avoid hitting real services.
  @override
  Future<void> checkAuthStatus() async {}
}

void main() {
  testWidgets(
    'LoginScreen shows offline banner, disabled button with offline message when offline',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkInfoProvider.overrideWithValue(FakeNetworkInfo(false)),
            authNotifierProvider.overrideWith(() => _StubAuthNotifier(true)),
          ],
          child: MaterialApp(
            theme: createLightTheme(),
            home: const LoginScreen(),
          ),
        ),
      );

      // Let the FutureProvider settle
      await tester.pumpAndSettle();

      // Expect the title to be present
      expect(find.text('DocJet Login'), findsOneWidget);

      // Email and password fields should still be rendered
      expect(find.byType(CupertinoTextField), findsNWidgets(2));

      // Login button should be disabled and show offline message
      final button = tester.widget<CupertinoButton>(
        find.byType(CupertinoButton),
      );
      expect(button.onPressed, isNull);

      // Check for the offline message in the button
      expect(
        find.text('Login Disabled - Your Device is Offline'),
        findsOneWidget,
      );
    },
  );

  testWidgets('LoginScreen shows active login button when online', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkInfoProvider.overrideWithValue(FakeNetworkInfo(true)),
          authNotifierProvider.overrideWith(() => _StubAuthNotifier(false)),
        ],
        child: MaterialApp(
          theme: createLightTheme(),
          home: const LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Button should show "Login" (not the offline message)
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Login Disabled - Your Device is Offline'), findsNothing);

    // Note: Button may still be disabled if form validation fails
  });
}
