import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Import the generated mocks file
import 'provider_override_test.mocks.dart';

// Generate mocks for dependencies
@GenerateMocks([AuthService, AuthEventBus])
void main() {
  late MockAuthService mockAuthService;
  late MockAuthEventBus mockAuthEventBus;

  setUp(() {
    mockAuthService = MockAuthService();
    mockAuthEventBus = MockAuthEventBus();
    when(mockAuthEventBus.stream).thenAnswer((_) => const Stream.empty());
  });

  group('authServiceProvider overrides', () {
    testWidgets(
      'should correctly override the generated provider from auth_notifier.dart',
      (WidgetTester tester) async {
        // Arrange
        // Create a widget with ProviderScope that mimics our main.dart setup
        await tester.pumpWidget(
          ProviderScope(
            // We're using the same override pattern as in main.dart
            overrides: [
              // Override the generated provider from auth_notifier.dart
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  // This will throw the UnimplementedError if the override
                  // doesn't work correctly
                  final authService = ref.read(authServiceProvider);
                  // This widget will only render if the provider is properly overridden
                  return Text(
                    'Provider properly overridden: ${authService.runtimeType}',
                  );
                },
              ),
            ),
          ),
        );

        // Assert
        expect(
          find.text('Provider properly overridden: MockAuthService'),
          findsOneWidget,
        );
      },
    );

    // Test to verify that authNotifierProvider now works correctly
    testWidgets(
      'should successfully use AuthNotifier with the overridden provider',
      (WidgetTester tester) async {
        // Arrange - Setup mocks for AuthNotifier to work
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => false);

        // Build our app with the proper override
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Override the generated provider that AuthNotifier uses
              authServiceProvider.overrideWithValue(mockAuthService),
              // Also override the event bus provider that AuthNotifier uses
              authEventBusProvider.overrideWithValue(mockAuthEventBus),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  // This would throw if the provider hasn't been properly overridden
                  final authState = ref.watch(authNotifierProvider);
                  return Text('AuthNotifier state: ${authState.status}');
                },
              ),
            ),
          ),
        );

        // Wait for async operations (like AuthNotifier initialization)
        await tester.pumpAndSettle();

        // This should now work because we're properly overriding the provider
        expect(find.textContaining('AuthNotifier state:'), findsOneWidget);
      },
    );
  });
}
