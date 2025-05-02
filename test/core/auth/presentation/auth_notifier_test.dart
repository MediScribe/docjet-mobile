import 'dart:async';

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/common/models/app_message.dart';
import 'package:docjet_mobile/core/common/notifiers/app_notifier_service.dart';
import 'package:docjet_mobile/core/services/autofill_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([AuthService, AuthEventBus, AutofillService])
import 'auth_notifier_test.mocks.dart';

// Creating a fake app notifier service for tracking calls
class FakeAppNotifierService extends AppNotifierService {
  final List<AppMessage> showCalls = [];
  int dismissCount = 0;

  @override
  void show({
    required String message,
    required MessageType type,
    Duration? duration,
    String? id,
  }) {
    showCalls.add(
      AppMessage(message: message, type: type, duration: duration, id: id),
    );
    super.show(message: message, type: type, duration: duration, id: id);
  }

  @override
  void dismiss() {
    dismissCount++;
    super.dismiss();
  }
}

// Additional DioExceptions for testing
final profile404DioException = DioException(
  requestOptions: RequestOptions(path: '/users/profile'),
  response: Response(
    requestOptions: RequestOptions(path: '/users/profile'),
    statusCode: 404,
  ),
  type: DioExceptionType.badResponse,
);

final otherDioException = DioException(
  requestOptions: RequestOptions(path: '/some/other/path'),
  response: Response(
    requestOptions: RequestOptions(path: '/some/other/path'),
    statusCode: 500,
  ),
  type: DioExceptionType.badResponse,
);

// Additional specialized DioExceptions for testing path matcher
final profile404DioExceptionWithVersion = DioException(
  requestOptions: RequestOptions(path: '/v1/users/profile'),
  response: Response(
    requestOptions: RequestOptions(path: '/v1/users/profile'),
    statusCode: 404,
  ),
  type: DioExceptionType.badResponse,
);

final profile404DioExceptionWithQuery = DioException(
  requestOptions: RequestOptions(path: '/users/profile?param=value'),
  response: Response(
    requestOptions: RequestOptions(path: '/users/profile?param=value'),
    statusCode: 404,
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  late MockAuthService mockAuthService;
  late MockAuthEventBus mockAuthEventBus;
  late MockAutofillService mockAutofillService;
  late StreamController<AuthEvent> eventBusController;
  late ProviderContainer container;

  const testUserId = 'test-user-id';
  const userProfile = User(id: testUserId);

  setUp(() {
    mockAuthService = MockAuthService();
    mockAuthEventBus = MockAuthEventBus();
    mockAutofillService = MockAutofillService();
    eventBusController = StreamController<AuthEvent>.broadcast();

    when(mockAuthEventBus.stream).thenAnswer((_) => eventBusController.stream);

    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        authEventBusProvider.overrideWithValue(mockAuthEventBus),
        autofillServiceProvider.overrideWithValue(mockAutofillService),
      ],
    );

    when(
      mockAuthService.isAuthenticated(
        validateTokenLocally: anyNamed('validateTokenLocally'),
      ),
    ).thenAnswer((_) async => false);
    when(mockAuthService.logout()).thenAnswer((_) async => {});
    when(mockAuthService.getUserProfile()).thenAnswer((_) async => userProfile);
  });

  tearDown(() async {
    await eventBusController.close();
    container.dispose();
  });

  AuthState readState() => container.read(authNotifierProvider);

  AuthNotifier readNotifier() => container.read(authNotifierProvider.notifier);

  Future<void> pumpEventQueue() => Future.delayed(Duration.zero);

  group('notification handling', () {
    test(
      'should handle 404 on profile endpoint by setting anonymous user',
      () async {
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => true);
        when(
          mockAuthService.getUserProfile(),
        ).thenThrow(profile404DioException);

        readNotifier();
        await pumpEventQueue();

        final state = readState();
        expect(state.status, equals(AuthStatus.authenticated));
        expect(state.user, isNotNull);
        expect(state.user!.isAnonymous, isTrue);
      },
    );

    test(
      'should handle versioned profile paths by setting anonymous user',
      () async {
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => true);
        when(
          mockAuthService.getUserProfile(),
        ).thenThrow(profile404DioExceptionWithVersion);

        readNotifier();
        await pumpEventQueue();

        final state = readState();
        expect(state.status, equals(AuthStatus.authenticated));
        expect(state.user, isNotNull);
        expect(state.user!.isAnonymous, isTrue);
      },
    );

    test(
      'should handle profile paths with query parameters by setting anonymous user',
      () async {
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => true);
        when(
          mockAuthService.getUserProfile(),
        ).thenThrow(profile404DioExceptionWithQuery);

        readNotifier();
        await pumpEventQueue();

        final state = readState();
        expect(state.status, equals(AuthStatus.authenticated));
        expect(state.user, isNotNull);
        expect(state.user!.isAnonymous, isTrue);
      },
    );

    test('should set error state for other DioExceptions', () async {
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).thenAnswer((_) async => true);
      when(mockAuthService.getUserProfile()).thenThrow(otherDioException);

      readNotifier();
      await pumpEventQueue();

      final state = readState();
      expect(state.status, equals(AuthStatus.error));
    });

    test('should have proper error state for auth errors', () async {
      // Create a normal authenticated state first
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).thenAnswer((_) async => true);
      when(
        mockAuthService.getUserProfile(),
      ).thenAnswer((_) async => userProfile);

      readNotifier();
      await pumpEventQueue();

      // Verify we have authenticated status with no errors
      final initialState = readState();
      expect(initialState.status, equals(AuthStatus.authenticated));
      expect(initialState.errorMessage, isNull);

      // Try logging in with an error to trigger AuthStatus.error
      reset(mockAuthService);
      when(
        mockAuthService.login(any, any),
      ).thenThrow(AuthException.invalidCredentials());

      // Attempt login which should fail with critical error
      await readNotifier().login('test@example.com', 'wrong-password');
      await pumpEventQueue();

      // Verify we now have error status but still no transient error
      final errorState = readState();
      expect(errorState.status, equals(AuthStatus.error));
      expect(errorState.errorMessage, isNotNull);
    });
  });

  // Test for User.anonymous()
  group('User.anonymous()', () {
    test('isAnonymous should be true for anonymous users', () {
      final anonymousUser = User.anonymous();
      expect(anonymousUser.isAnonymous, isTrue);
    });

    test('isAnonymous should be false for real users', () {
      final realUser = User(id: 'real-user-id');
      expect(realUser.isAnonymous, isFalse);
    });
  });

  // Tests for offline auth caching behavior
  group('offline authentication', () {
    test(
      'should authenticate with valid local credentials when offline',
      () async {
        // Set up auth service to use local validation and simulate offline condition
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: true),
        ).thenAnswer((_) async => true);

        // Simulate network error when trying to get profile online
        when(
          mockAuthService.getUserProfile(acceptOfflineProfile: false),
        ).thenThrow(AuthException.offlineOperationFailed());

        // But succeed with cached profile when accepting offline profile
        when(
          mockAuthService.getUserProfile(acceptOfflineProfile: true),
        ).thenAnswer((_) async => userProfile);

        // Create a new notifier with our enhanced offline-first behavior
        readNotifier();
        await pumpEventQueue();

        // Verify we end up authenticated with the offline profile
        final state = readState();
        expect(state.status, equals(AuthStatus.authenticated));
        expect(state.user, equals(userProfile));
        expect(state.isOffline, isTrue);

        // Verify we called the right methods with right parameters
        verify(mockAuthService.isAuthenticated(validateTokenLocally: true));
        verify(mockAuthService.getUserProfile(acceptOfflineProfile: true));
      },
    );

    test(
      'should reject if server invalidates locally valid token when online',
      () async {
        // First the standard auth fails (no token)
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => false);

        // But the local validation succeeds (validateTokenLocally: true)
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: true),
        ).thenAnswer((_) async => true);

        // But when we try to call getUserProfile, server rejects
        when(
          mockAuthService.getUserProfile(acceptOfflineProfile: true),
        ).thenThrow(AuthException.unauthenticated('Server rejected token'));

        readNotifier();
        await pumpEventQueue();

        // Should be unauthenticated if token is rejected
        final state = readState();
        expect(state.status, equals(AuthStatus.unauthenticated));
        expect(state.user, isNull);
      },
    );

    test('should handle corrupted profile cache gracefully', () async {
      // Auth is valid locally
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: true),
      ).thenAnswer((_) async => true);

      // But profile fetch fails with cache corruption error
      when(
        mockAuthService.getUserProfile(acceptOfflineProfile: true),
      ).thenThrow(Exception('Corrupted profile cache'));

      // Override app notifier service to verify error messages
      final fakeAppNotifier = FakeAppNotifierService();
      container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          authEventBusProvider.overrideWithValue(mockAuthEventBus),
          autofillServiceProvider.overrideWithValue(mockAutofillService),
          appNotifierServiceProvider.overrideWith(() => fakeAppNotifier),
        ],
      );

      readNotifier();
      await pumpEventQueue();

      // Should still be authenticated but with anonymous user
      final state = readState();
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.user, isNotNull);
      expect(state.user!.isAnonymous, isTrue);

      // Should have shown an error notification
      expect(fakeAppNotifier.showCalls.length, 1);
      expect(fakeAppNotifier.showCalls.first.type, equals(MessageType.error));
      expect(fakeAppNotifier.showCalls.first.message, contains('profile'));
    });

    test('should handle token expiry detection during offline mode', () async {
      // First the standard auth fails (no token)
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).thenAnswer((_) async => false);

      // And the local validation says token is expired
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: true),
      ).thenThrow(AuthException.tokenExpired());

      readNotifier();
      await pumpEventQueue();

      // Should be in error state when token is expired
      final state = readState();
      expect(state.status, equals(AuthStatus.error));
      expect(state.errorType, equals(AuthErrorType.tokenExpired));
      expect(state.user, isNull);

      // Verify we called isAuthenticated with correct parameter
      verify(
        mockAuthService.isAuthenticated(validateTokenLocally: true),
      ).called(1);
    });

    test(
      'should show appropriate error notification during offline auth errors',
      () async {
        // Create FakeAppNotifierService first for proper capturing
        final fakeAppNotifier = FakeAppNotifierService();

        // We need to recreate the container with our fake notifier service
        container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            authEventBusProvider.overrideWithValue(mockAuthEventBus),
            autofillServiceProvider.overrideWithValue(mockAutofillService),
            appNotifierServiceProvider.overrideWith(() => fakeAppNotifier),
          ],
        );

        // First the standard auth fails (no token)
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => false);

        // But the local validation succeeds (validateTokenLocally: true)
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: true),
        ).thenAnswer((_) async => true);

        // But we throw a corrupted profile cache error which should show a notification
        when(
          mockAuthService.getUserProfile(acceptOfflineProfile: true),
        ).thenThrow(Exception('Corrupted profile cache'));

        // Get the notifier using our container with the fake service
        container.read(authNotifierProvider);
        await pumpEventQueue();

        // Should be authenticated but with anonymous user
        final state = container.read(authNotifierProvider);
        expect(state.status, equals(AuthStatus.authenticated));
        expect(state.user, isNotNull);
        expect(state.user!.isAnonymous, isTrue);

        // Should have shown an error notification
        expect(fakeAppNotifier.showCalls.length, 1);
        expect(fakeAppNotifier.showCalls.first.type, equals(MessageType.error));
        expect(fakeAppNotifier.showCalls.first.message, contains('profile'));
      },
    );
  });

  group('network restoration token validation', () {
    test(
      'should validate token with server when transitioning from offline to online',
      () async {
        // Set up initial offline authentication state
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: true),
        ).thenAnswer((_) async => true);

        // Simulate network error when trying to get profile online
        when(
          mockAuthService.getUserProfile(acceptOfflineProfile: false),
        ).thenThrow(AuthException.offlineOperationFailed());

        // But succeed with cached profile when accepting offline profile
        when(
          mockAuthService.getUserProfile(acceptOfflineProfile: true),
        ).thenAnswer((_) async => userProfile);

        // Create the notifier and verify we get offline authenticated state
        readNotifier();
        await pumpEventQueue();

        // Verify initial state is offline but authenticated
        final initialState = readState();
        expect(initialState.status, equals(AuthStatus.authenticated));
        expect(initialState.isOffline, isTrue);

        // Clear interactions to prepare for online transition
        clearInteractions(mockAuthService);

        // Now simulate coming back online
        when(mockAuthService.refreshSession()).thenAnswer((_) async => true);
        when(
          mockAuthService.getUserProfile(),
        ).thenAnswer((_) async => userProfile);

        // Trigger online restored event
        eventBusController.add(AuthEvent.onlineRestored);
        await pumpEventQueue();

        // Need additional delay for the debounce timer
        await Future.delayed(const Duration(seconds: 2));

        // Verify token was validated with server through refreshSession
        verify(mockAuthService.refreshSession()).called(1);
        verify(mockAuthService.getUserProfile()).called(1);

        // Verify we're now authenticated and online
        final finalState = readState();
        expect(finalState.status, equals(AuthStatus.authenticated));
        expect(finalState.user, equals(userProfile));
        expect(finalState.isOffline, isFalse);
      },
    );

    test(
      'should reset to unauthenticated when server rejects token during network restoration',
      () async {
        // Set up initial offline authentication state
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: true),
        ).thenAnswer((_) async => true);

        // Simulate offline profile fetch
        when(
          mockAuthService.getUserProfile(acceptOfflineProfile: false),
        ).thenThrow(AuthException.offlineOperationFailed());
        when(
          mockAuthService.getUserProfile(acceptOfflineProfile: true),
        ).thenAnswer((_) async => userProfile);

        // Create the notifier and verify we get offline authenticated state
        readNotifier();
        await pumpEventQueue();

        // Verify initial state is offline but authenticated
        final initialState = readState();
        expect(initialState.status, equals(AuthStatus.authenticated));
        expect(initialState.isOffline, isTrue);

        // Clear interactions to prepare for online transition
        clearInteractions(mockAuthService);

        // Now simulate coming back online but with invalid token
        when(mockAuthService.refreshSession()).thenAnswer((_) async => false);

        // Trigger online restored event
        eventBusController.add(AuthEvent.onlineRestored);
        await pumpEventQueue();

        // Need additional delay for the debounce timer
        await Future.delayed(const Duration(seconds: 2));

        // Verify token was validated with server
        verify(mockAuthService.refreshSession()).called(1);

        // Verify we should not attempt to get profile as token was invalid
        verifyNever(mockAuthService.getUserProfile());

        // Verify we're now unauthenticated
        final finalState = readState();
        expect(finalState.status, equals(AuthStatus.unauthenticated));
        expect(finalState.isOffline, isFalse);
      },
    );

    test('should update cached profile when coming back online', () async {
      // Set up initial offline authentication state
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: true),
      ).thenAnswer((_) async => true);

      // Simulate offline profile fetch
      when(
        mockAuthService.getUserProfile(acceptOfflineProfile: false),
      ).thenThrow(AuthException.offlineOperationFailed());

      // Return an "offline" profile first
      final offlineProfile = User(id: 'offline-user-id');
      when(
        mockAuthService.getUserProfile(acceptOfflineProfile: true),
      ).thenAnswer((_) async => offlineProfile);

      // Create the notifier and verify we get offline authenticated state
      readNotifier();
      await pumpEventQueue();

      // Verify initial state has the offline profile
      final initialState = readState();
      expect(initialState.user, equals(offlineProfile));
      expect(initialState.isOffline, isTrue);

      // Clear interactions to prepare for online transition
      clearInteractions(mockAuthService);

      // Now simulate coming back online with fresh profile data
      when(mockAuthService.refreshSession()).thenAnswer((_) async => true);

      // Return updated profile when online
      final onlineProfile = User(id: 'online-fresh-id');
      when(
        mockAuthService.getUserProfile(),
      ).thenAnswer((_) async => onlineProfile);

      // Trigger online restored event
      eventBusController.add(AuthEvent.onlineRestored);
      await pumpEventQueue();

      // Need additional delay for the debounce timer
      await Future.delayed(const Duration(seconds: 2));

      // Verify we fetched fresh profile data
      verify(mockAuthService.refreshSession()).called(1);
      verify(mockAuthService.getUserProfile()).called(1);

      // Verify state has been updated with fresh profile
      final finalState = readState();
      expect(finalState.status, equals(AuthStatus.authenticated));
      expect(finalState.user, equals(onlineProfile));
      expect(finalState.isOffline, isFalse);
    });
  });
}
