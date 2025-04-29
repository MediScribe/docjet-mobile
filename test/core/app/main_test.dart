import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([AuthService, AuthEventBus])
import 'main_test.mocks.dart';

void main() {
  group('Main App Providers', () {
    late MockAuthService mockAuthService;
    late MockAuthEventBus mockAuthEventBus;
    late ProviderContainer container;

    setUp(() {
      mockAuthService = MockAuthService();
      mockAuthEventBus = MockAuthEventBus();

      // Setup the provider container with our mocks
      container = ProviderContainer(
        overrides: [
          // Provide our mock auth service
          authServiceProvider.overrideWithValue(mockAuthService),
          // Also need to override the authEventBusProvider since AuthNotifier uses it
          authEventBusProvider.overrideWithValue(mockAuthEventBus),
        ],
      );
      addTearDown(container.dispose);
    });

    test('authNotifierProvider should use the authServiceProvider', () async {
      // Arrange
      when(mockAuthService.isAuthenticated()).thenAnswer((_) async => false);

      // The event bus is a stream, so we need to provide a dummy stream
      when(
        mockAuthEventBus.stream,
      ).thenAnswer((_) => const Stream<AuthEvent>.empty());

      // Act
      // The first read will trigger the build method that calls isAuthenticated
      final authState = container.read(authNotifierProvider);

      // Assert
      expect(authState, isA<AuthState>());
      // Since isAuthenticated() returns false, and we already got logs showing the complete flow,
      // the state should now be unauthenticated (not loading as initially thought)
      expect(authState.status, equals(AuthStatus.unauthenticated));

      // Verify the auth service was used (isAuthenticated should be called)
      verify(mockAuthService.isAuthenticated()).called(1);

      // Verify the event bus was used
      verify(mockAuthEventBus.stream).called(1);
    });
  });
}
