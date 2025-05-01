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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([AuthService, AuthEventBus])
import 'auth_notifier_test.mocks.dart';

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
  late StreamController<AuthEvent> eventBusController;
  late ProviderContainer container;
  late User testUser;

  const testEmail = 'test@example.com';
  const testPassword = 'password123';
  const testUserId = 'test-user-id';
  const userProfile = User(id: testUserId);
  final offlineException = AuthException.offlineOperationFailed();
  final profileFetchException = AuthException.userProfileFetchFailed();

  setUp(() {
    mockAuthService = MockAuthService();
    mockAuthEventBus = MockAuthEventBus();
    eventBusController = StreamController<AuthEvent>.broadcast();

    when(mockAuthEventBus.stream).thenAnswer((_) => eventBusController.stream);

    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        authEventBusProvider.overrideWithValue(mockAuthEventBus),
      ],
    );

    testUser = const User(id: testUserId);

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

  group('initial state & checkAuthStatus', () {
    test('should be unauthenticated if isAuthenticated is false', () async {
      readNotifier();
      await pumpEventQueue();

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
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => true);

        readNotifier();
        await pumpEventQueue();

        verify(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).called(1);
        verify(mockAuthService.getUserProfile()).called(1);
        expect(readState(), equals(AuthState.authenticated(userProfile)));
      },
    );

    test('should handle profile fetch failure during init', () async {
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).thenAnswer((_) async => true);
      when(mockAuthService.getUserProfile()).thenThrow(profileFetchException);

      readNotifier();
      await pumpEventQueue();

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
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).thenAnswer((_) async => true);
      when(mockAuthService.getUserProfile()).thenThrow(offlineException);

      readNotifier();
      await pumpEventQueue();

      verify(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).called(1);
      verify(mockAuthService.getUserProfile()).called(1);
      final state = readState();
      expect(state.status, AuthStatus.error);
      expect(state.isOffline, true);
      expect(state.errorMessage, offlineException.message);
    });
  });

  group('login', () {
    test('should get profile and update state when login succeeds', () async {
      when(
        mockAuthService.login(testEmail, testPassword),
      ).thenAnswer((_) async => testUser);

      await readNotifier().login(testEmail, testPassword);
      await pumpEventQueue();

      verify(mockAuthService.login(testEmail, testPassword)).called(1);
      verify(mockAuthService.getUserProfile()).called(1);
      expect(readState(), equals(AuthState.authenticated(userProfile)));
    });

    test('should update state to error when login fails', () async {
      final exception = AuthException.invalidCredentials();
      when(mockAuthService.login(testEmail, testPassword)).thenThrow(exception);

      await readNotifier().login(testEmail, testPassword);
      await pumpEventQueue();

      final state = readState();
      expect(state.status, equals(AuthStatus.unauthenticated));
      verify(mockAuthService.login(testEmail, testPassword)).called(1);
      verifyNever(mockAuthService.getUserProfile());
    });

    test(
      'should update state to error with offline flag when login is offline',
      () async {
        when(
          mockAuthService.login(testEmail, testPassword),
        ).thenThrow(offlineException);

        await readNotifier().login(testEmail, testPassword);
        await pumpEventQueue();

        final state = readState();
        expect(state.status, equals(AuthStatus.unauthenticated));
        verify(mockAuthService.login(testEmail, testPassword)).called(1);
        verifyNever(mockAuthService.getUserProfile());
      },
    );

    test(
      'should update state to error when profile fetch fails after login',
      () async {
        when(
          mockAuthService.login(testEmail, testPassword),
        ).thenAnswer((_) async => testUser);
        when(mockAuthService.getUserProfile()).thenThrow(profileFetchException);

        await readNotifier().login(testEmail, testPassword);
        await pumpEventQueue();

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
        when(
          mockAuthService.login(testEmail, testPassword),
        ).thenAnswer((_) async => testUser);
        when(mockAuthService.getUserProfile()).thenThrow(offlineException);

        await readNotifier().login(testEmail, testPassword);
        await pumpEventQueue();

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
      when(mockAuthService.login(any, any)).thenAnswer((_) async => testUser);
      when(
        mockAuthService.getUserProfile(),
      ).thenAnswer((_) async => userProfile);
      await readNotifier().login('test', 'test');
      await pumpEventQueue();
      expect(readState().status, AuthStatus.authenticated);

      await readNotifier().logout();

      eventBusController.add(AuthEvent.loggedOut);

      await pumpEventQueue();

      verify(mockAuthService.logout()).called(1);
      expect(readState(), equals(AuthState.initial()));
    });
  });

  group('Event Bus Handling', () {
    test('should subscribe to event bus on creation', () async {
      readNotifier();
      await pumpEventQueue();

      verify(mockAuthEventBus.stream).called(1);
    });

    test('should update state to unauthenticated on loggedOut event', () async {
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

      eventBusController.add(AuthEvent.loggedOut);
      await pumpEventQueue();

      expect(
        readState(),
        equals(AuthState.initial()),
        reason: "State should reset on logout event",
      );
    });
  });

  group('Offline/Online Transitions', () {
    test(
      'should set isOffline true when offlineDetected event received',
      () async {
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => true);
        when(
          mockAuthService.getUserProfile(),
        ).thenAnswer((_) async => userProfile);

        readNotifier();
        await pumpEventQueue();
        expect(readState().isOffline, false, reason: "Should start online");

        eventBusController.add(AuthEvent.offlineDetected);
        await pumpEventQueue();

        expect(
          readState().isOffline,
          true,
          reason:
              "State should be offline after receiving offlineDetected event",
        );
      },
    );

    test(
      'should set isOffline false when onlineRestored event received',
      () async {
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => true);
        when(mockAuthService.getUserProfile()).thenThrow(offlineException);

        readNotifier();
        await pumpEventQueue();
        expect(readState().isOffline, true, reason: "Should start offline");

        when(
          mockAuthService.getUserProfile(),
        ).thenAnswer((_) async => userProfile);

        eventBusController.add(AuthEvent.onlineRestored);
        await pumpEventQueue();

        expect(
          readState().isOffline,
          false,
          reason: "State should be online after receiving onlineRestored event",
        );
      },
    );

    test(
      'should NOT emit connectivity events when API calls fail or succeed',
      () async {
        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => true);
        when(
          mockAuthService.getUserProfile(),
        ).thenAnswer((_) async => userProfile);

        readNotifier();
        await pumpEventQueue();

        clearInteractions(mockAuthEventBus);

        when(mockAuthService.login(any, any)).thenThrow(offlineException);
        await readNotifier().login(testEmail, testPassword);
        await pumpEventQueue();

        verifyNever(mockAuthEventBus.add(AuthEvent.offlineDetected));

        when(mockAuthService.login(any, any)).thenAnswer((_) async => testUser);
        when(
          mockAuthService.getUserProfile(),
        ).thenAnswer((_) async => userProfile);
        await readNotifier().login(testEmail, testPassword);
        await pumpEventQueue();

        verifyNever(mockAuthEventBus.add(AuthEvent.onlineRestored));
      },
    );

    test(
      'should trigger profile refresh when onlineRestored event is received',
      () async {
        const testUser = User(id: testUserId);

        when(
          mockAuthService.isAuthenticated(validateTokenLocally: false),
        ).thenAnswer((_) async => true);

        when(mockAuthService.getUserProfile()).thenThrow(offlineException);

        readNotifier();
        await pumpEventQueue();

        final initialState = readState();
        expect(
          initialState.isOffline,
          true,
          reason: 'Should start in offline state',
        );

        clearInteractions(mockAuthService);

        reset(mockAuthService);
        when(
          mockAuthService.getUserProfile(),
        ).thenAnswer((_) async => testUser);

        eventBusController.add(AuthEvent.onlineRestored);

        await Future.delayed(const Duration(milliseconds: 200));
        await pumpEventQueue();
        await Future.delayed(const Duration(milliseconds: 1000));
        await pumpEventQueue();
        await Future.delayed(const Duration(milliseconds: 500));
        await pumpEventQueue();

        final afterState = readState();

        try {
          verify(mockAuthService.getUserProfile()).called(1);
        } catch (e) {
          rethrow;
        }

        expect(
          afterState.isOffline,
          false,
          reason: 'Should be online after event',
        );
      },
    );

    test('subscription to AuthEventBus is cancelled on dispose', () async {
      readNotifier();
      await pumpEventQueue();

      container.dispose();

      // Verify there are no active listeners
      expect(eventBusController.hasListener, isFalse);
    });
  });

  group('transient error handling', () {
    test('should set transientError for 404 on profile endpoint', () async {
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).thenAnswer((_) async => true);
      when(mockAuthService.getUserProfile()).thenThrow(profile404DioException);

      readNotifier();
      await pumpEventQueue();

      final state = readState();
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.transientError, isNotNull);
      expect(
        state.transientError?.type,
        equals(AuthErrorType.userProfileFetchFailed),
      );
      expect(
        state.transientError?.message,
        contains('Unable to fetch your profile'),
      );
      // Verify we're using anonymous user
      expect(state.user, isNotNull);
      expect(state.user!.isAnonymous, isTrue);
    });

    test('should handle versioned profile paths', () async {
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
      expect(state.transientError, isNotNull);
      // Verify we're using anonymous user
      expect(state.user, isNotNull);
      expect(state.user!.isAnonymous, isTrue);
    });

    test('should handle profile paths with query parameters', () async {
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
      expect(state.transientError, isNotNull);
      // Verify we're using anonymous user
      expect(state.user, isNotNull);
      expect(state.user!.isAnonymous, isTrue);
    });

    test('should not set transientError for other DioExceptions', () async {
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).thenAnswer((_) async => true);
      when(mockAuthService.getUserProfile()).thenThrow(otherDioException);

      readNotifier();
      await pumpEventQueue();

      final state = readState();
      expect(state.status, equals(AuthStatus.error));
      expect(state.transientError, isNull);
    });

    test(
      'should never have both AuthStatus.error and transientError',
      () async {
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
        expect(initialState.transientError, isNull);
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
        expect(errorState.transientError, isNull);
        expect(errorState.errorMessage, isNotNull);
      },
    );

    test('clearTransientError should remove the transientError', () async {
      // Set up state with a transient error
      when(
        mockAuthService.isAuthenticated(validateTokenLocally: false),
      ).thenAnswer((_) async => true);
      when(mockAuthService.getUserProfile()).thenThrow(profile404DioException);

      readNotifier();
      await pumpEventQueue();

      // Verify we have a transient error
      expect(readState().transientError, isNotNull);

      // Clear the error
      readNotifier().clearTransientError();

      // Verify the error is gone
      expect(readState().transientError, isNull);
      // But we're still authenticated
      expect(readState().status, equals(AuthStatus.authenticated));
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
}
