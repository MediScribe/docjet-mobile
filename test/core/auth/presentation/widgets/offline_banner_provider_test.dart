import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('OfflineBanner with Provider Tests', () {
    testWidgets('Banner height changes with online/offline state', (
      WidgetTester tester,
    ) async {
      // Test with initial offline state
      await tester.pumpWidget(
        createTestApp(
          authState: createOfflineState(),
          child: const Scaffold(body: Text('Content')),
        ),
      );

      // Verify banner is visible in offline state
      expect(findOfflineBannerText(), findsOneWidget);

      // Find the container that represents our banner
      final offlineContainer = find.ancestor(
        of: findOfflineBannerText(),
        matching: find.byType(Container),
      );
      expect(offlineContainer, findsOneWidget);

      // Measure its height
      final offlineContainerWidget = tester.widget<Container>(offlineContainer);
      expect(offlineContainerWidget.constraints?.maxHeight ?? 0, equals(36.0));

      // Rebuild with online state
      await tester.pumpWidget(
        createTestApp(
          authState: createOnlineState(),
          child: const Scaffold(body: Text('Content')),
        ),
      );

      await tester.pumpAndSettle();

      // Verify no banner is visible
      expect(findOfflineBannerText(), findsNothing);
    });
  });
}
