import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Simplified notifier implementation for testing
class TestAuthNotifier extends AutoDisposeNotifier<AuthState> {
  final AuthState _initialState;

  TestAuthNotifier(this._initialState);

  @override
  AuthState build() => _initialState;
}

void main() {
  group('OfflineBanner Theme Tests', () {
    testWidgets('Banner is visible when offline', (WidgetTester tester) async {
      // We don't test dark mode adaptation anymore since we've simplified our approach
      // Instead, we just verify basic visibility
      await tester.pumpWidget(
        createTestApp(
          authState: createOfflineState(),
          child: const Scaffold(body: Text('Content')),
        ),
      );

      // Act: Let the widget render
      await tester.pumpAndSettle();

      // Verify banner visibility
      expect(findOfflineBannerText(), findsOneWidget);

      // Verify content is still visible underneath
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('Banner is hidden when online', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          authState: createOnlineState(),
          child: const Scaffold(body: Text('Content')),
        ),
      );

      // Act: Let the widget render
      await tester.pumpAndSettle();

      // Verify banner is not visible
      expect(findOfflineBannerText(), findsNothing);

      // Verify content is still visible
      expect(find.text('Content'), findsOneWidget);
    });
  });
}
