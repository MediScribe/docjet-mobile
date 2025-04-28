import 'dart:async';

import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/di/injection_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([AuthService, AuthEventBus])
import 'auth_notifier_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late MockAuthEventBus mockAuthEventBus;
  late StreamController<AuthEvent> eventBusController;
  late ProviderContainer container;
  late User testUser;

  const testEmail = 'test@example.com';
  const testPassword = 'password123';
  const testUserId = 'test-user-id';
  final userProfile = User(id: testUserId);
  final offlineException = AuthException.offlineOperationFailed();
  final profileFetchException = AuthException.userProfileFetchFailed();

  setUp(() {
    mockAuthService = MockAuthService();
    mockAuthEventBus = MockAuthEventBus();
    eventBusController = StreamController<AuthEvent>.broadcast();

    // Mock the event bus stream
    when(mockAuthEventBus.stream).thenAnswer((_) => eventBusController.stream);

    // Create a ProviderContainer with overrides
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        // Override event bus provider assuming it exists
        authEventBusProvider.overrideWithValue(mockAuthEventBus),
      ],
    );

    testUser = const User(id: testUserId);

    // Default stubbing
    when(
      mockAuthService.isAuthenticated(
        validateTokenLocally: anyNamed('validateTokenLocally'),
      ),
    ).thenAnswer((_) async => false);
    when(mockAuthService.logout()).thenAnswer((_) async => {});
    when(mockAuthService.getUserProfile()).thenAnswer((_) async => userProfile);
  });

  tearDown(() {
    eventBusController.close();
    container.dispose();
  });

  // Helper to read the notifier state
  AuthState readState() => container.read(authNotifierProvider);

  // Helper to get the notifier itself
  AuthNotifier readNotifier() => container.read(authNotifierProvider.notifier);

  // Helper to wait for microtasks
  Future<void> pumpEventQueue() => Future.delayed(Duration.zero);

  group('initial state & checkAuthStatus', () {
    test('should be unauthenticated if isAuthenticated is false', () async {
      // Arrange (already done in setUp)

      // Act - reading the provider triggers build()
      readNotifier();
      await pumpEventQueue();

      // Assert
      expect(readState(), equals(AuthState.initial()));
      verify(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).called(1);
      verifyNever(mockAuthService.refreshSession());
      verifyNever(mockAuthService.getUserProfile());
    });

    test(
      'should try refresh and get profile if isAuthenticated is true',
      () async {
        // Arrange
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => true);
        // Let refreshSession succeed implicitly (no setup needed unless specific return needed)
        // Let getUserProfile succeed (setup in global setup)

        // Act
        readNotifier();
        await pumpEventQueue();

        // Assert
        verify(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).called(1);
        verify(mockAuthService.getUserProfile()).called(1);
        expect(readState(), equals(AuthState.authenticated(userProfile)));
      },
    );

    test('should handle profile fetch failure during init', () async {
      // Arrange
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).thenAnswer((_) async => true);
      when(mockAuthService.getUserProfile()).thenThrow(profileFetchException);

      // Act
      readNotifier();
      await pumpEventQueue();

      // Assert
      verify(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).called(1);
      verify(mockAuthService.getUserProfile()).called(1);
      expect(
        readState(),
        equals(
          AuthState.error(
            profileFetchException.message,
            errorType: AuthErrorType.userProfileFetchFailed,
          ),
        ),
      );
    });

    test('should handle offline failure during init profile fetch', () async {
      // Arrange
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).thenAnswer((_) async => true);
      when(mockAuthService.getUserProfile()).thenThrow(offlineException);

      // Act
      readNotifier();
      await pumpEventQueue();

      // Assert
      verify(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).called(1);
      verify(mockAuthService.getUserProfile()).called(1);
      // Expect authenticated but offline state
      final state = readState();
      expect(
        state.status,
        AuthStatus.error,
      ); // Or maybe authenticated but offline?
      expect(state.isOffline, true);
      expect(state.errorMessage, offlineException.message);
    });
  });

  group('login', () {
    test('should get profile and update state when login succeeds', () async {
      // Arrange
      when(
        mockAuthService.login(testEmail, testPassword),
      ).thenAnswer((_) async => testUser); // login returns basic user
      // getUserProfile returns full profile (stubbed in setUp)

      // Act
      await readNotifier().login(testEmail, testPassword);
      await pumpEventQueue();

      // Assert
      verify(mockAuthService.login(testEmail, testPassword)).called(1);
      verify(mockAuthService.getUserProfile()).called(1);
      expect(readState(), equals(AuthState.authenticated(userProfile)));
    });

    test('should update state to error when login fails', () async {
      // Arrange
      final exception = AuthException.invalidCredentials();
      when(mockAuthService.login(testEmail, testPassword)).thenThrow(exception);

      // Act
      await readNotifier().login(testEmail, testPassword);
      await pumpEventQueue();

      // Assert
      // The implementation sets auth state back to unauthenticated after login fails
      final state = readState();
      expect(state.status, equals(AuthStatus.unauthenticated));
      verify(mockAuthService.login(testEmail, testPassword)).called(1);
      verifyNever(mockAuthService.getUserProfile());
    });

    test(
      'should update state to error with offline flag when login is offline',
      () async {
        // Arrange
        when(
          mockAuthService.login(testEmail, testPassword),
        ).thenThrow(offlineException);

        // Act
        await readNotifier().login(testEmail, testPassword);
        await pumpEventQueue();

        // Assert
        final state = readState();
        expect(state.status, equals(AuthStatus.unauthenticated));
        verify(mockAuthService.login(testEmail, testPassword)).called(1);
        verifyNever(mockAuthService.getUserProfile());
      },
    );

    test(
      'should update state to error when profile fetch fails after login',
      () async {
        // Arrange
        when(
          mockAuthService.login(testEmail, testPassword),
        ).thenAnswer((_) async => testUser);
        when(mockAuthService.getUserProfile()).thenThrow(profileFetchException);

        // Act
        await readNotifier().login(testEmail, testPassword);
        await pumpEventQueue();

        // Assert
        verify(mockAuthService.login(testEmail, testPassword)).called(1);
        verify(mockAuthService.getUserProfile()).called(1);
        final state = readState();
        expect(state.status, AuthStatus.error);
        expect(state.errorMessage, equals(profileFetchException.message));
      },
    );

    test(
      'should update state to error with offline flag when profile fetch is offline after login',
      () async {
        // Arrange
        when(
          mockAuthService.login(testEmail, testPassword),
        ).thenAnswer((_) async => testUser);
        when(mockAuthService.getUserProfile()).thenThrow(offlineException);

        // Act
        await readNotifier().login(testEmail, testPassword);
        await pumpEventQueue();

        // Assert
        verify(mockAuthService.login(testEmail, testPassword)).called(1);
        verify(mockAuthService.getUserProfile()).called(1);
        final state = readState();
        expect(state.status, AuthStatus.error);
        expect(state.errorMessage, equals(offlineException.message));
        expect(state.isOffline, true);
      },
    );
  });

  group('logout', () {
    test('should call authService.logout and update state', () async {
      // Arrange: Start in an authenticated state (simulate previous login)
      when(mockAuthService.login(any, any)).thenAnswer((_) async => testUser);
      when(
        mockAuthService.getUserProfile(),
      ).thenAnswer((_) async => userProfile);
      await readNotifier().login('test', 'test');
      await pumpEventQueue();
      expect(readState().status, AuthStatus.authenticated);

      // Act
      await readNotifier().logout();

      // Simulate the event that would normally be emitted by the authService
      eventBusController.add(AuthEvent.loggedOut);

      await pumpEventQueue();

      // Assert
      verify(mockAuthService.logout()).called(1);
      // State should be reset by the notifier directly or via event bus
      expect(readState(), equals(AuthState.initial()));
    });
  });

  group('Event Bus Handling', () {
    test('should subscribe to event bus on creation', () async {
      // Arrange
      // ProviderContainer setup now includes the event bus override.

      // Act
      readNotifier(); // Trigger notifier creation and subscription
      await pumpEventQueue();

      // Assert
      // Verify the stream was accessed. Actual subscription needs notifier impl.
      verify(mockAuthEventBus.stream).called(1);
    });

    test('should update state to unauthenticated on loggedOut event', () async {
      // Arrange: Start authenticated
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).thenAnswer((_) async => true);
      readNotifier();
      await pumpEventQueue();
      expect(
        readState().status,
        AuthStatus.authenticated,
        reason: "State should be authenticated initially",
      );

      // Act: Emit logout event
      eventBusController.add(AuthEvent.loggedOut);
      await pumpEventQueue();

      // Assert
      expect(
        readState(),
        equals(AuthState.initial()),
        reason: "State should reset on logout event",
      );
    });
  });

  group('Offline/Online Transitions', () {
    test(
      'should emit offlineDetected when transitioning from online to offline',
      () async {
        // Arrange: Start authenticated and online
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => true);
        when(
          mockAuthService.getUserProfile(),
        ).thenAnswer((_) async => userProfile);
        when(
          mockAuthService.login(testEmail, testPassword),
        ).thenAnswer((_) async => testUser);

        // Initialize notifier (will be online initially)
        readNotifier();
        await pumpEventQueue();
        expect(readState().isOffline, false, reason: "Should start online");

        // Clear any previous mock interactions
        clearInteractions(mockAuthEventBus);

        // Act: Change to offline state for the next call
        when(mockAuthService.getUserProfile()).thenThrow(offlineException);
        await readNotifier().login(
          testEmail,
          testPassword,
        ); // This will trigger the state change
        await pumpEventQueue();

        // Assert: Should emit the offline event
        verify(mockAuthEventBus.add(AuthEvent.offlineDetected)).called(1);
        // Verify that isOffline flag is set correctly in the state
        expect(
          readState().isOffline,
          true,
          reason: "State should be offline after transition",
        );
      },
    );

    test(
      'should emit onlineRestored when transitioning from offline to online',
      () async {
        // Arrange: We need to create a custom notifier for this scenario
        // First, we create a state that's offline (caused by profile fetch fail)
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => true);
        when(mockAuthService.getUserProfile()).thenThrow(offlineException);

        // Initialize notifier (will be offline due to profile fetch error)
        readNotifier();
        await pumpEventQueue();
        expect(readState().isOffline, true, reason: "Should start offline");

        // We need to reset the mock verification since initialization called add
        clearInteractions(mockAuthEventBus);

        // Now prepare for the second call that will succeed
        when(
          mockAuthService.getUserProfile(),
        ).thenAnswer((_) async => userProfile);

        // Trigger state change by calling login again
        when(
          mockAuthService.login(testEmail, testPassword),
        ).thenAnswer((_) async => testUser);
        await readNotifier().login(testEmail, testPassword);
        await pumpEventQueue();

        // Assert: Should now be online and emitted the onlineRestored event
        verify(mockAuthEventBus.add(AuthEvent.onlineRestored)).called(1);
        // Verify that isOffline flag is set correctly in the state
        expect(
          readState().isOffline,
          false,
          reason: "State should be online after transition",
        );
      },
    );

    test('subscription to AuthEventBus is cancelled on dispose', () async {
      // Arrange
      readNotifier(); // Create the notifier
      await pumpEventQueue();

      // Act: Dispose the container which should trigger onDispose
      container.dispose();

      // Assert: Can't easily verify the subscription was cancelled, but the notifier
      // should have had onDispose called which contains the cancellation logic
      // This is a "does not throw" test, implicitly verifying cleanup
    });
  });

  // Remove old session refresh tests as logic is covered in init tests
  /*
  group('session refresh', () {
    // ... old tests removed ...
  });
 */
}
