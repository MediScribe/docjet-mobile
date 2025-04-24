import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart'; // Corrected import
import 'package:docjet_mobile/core/auth/presentation/auth_status.dart';
// Import ValueGetter for copyWith test

void main() {
  group('AuthState', () {
    final testUser = User(id: '1'); // Removed const

    test('initial state should have correct defaults', () {
      final state = AuthState.initial(); // Removed const
      expect(state.status, AuthStatus.unauthenticated); // Corrected expectation
      expect(state.user, isNull);
      expect(state.errorMessage, isNull);
      expect(state.isOffline, isFalse); // Check default
    });

    test('authenticated state should have correct properties', () {
      final state = AuthState.authenticated(testUser); // Removed const
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, testUser);
      expect(state.errorMessage, isNull);
      expect(state.isOffline, isFalse); // Check default
    });

    test(
      'authenticated state in offline mode should have correct properties',
      () {
        // This test setup will need to change once AuthState is updated
        final state = AuthState.authenticated(testUser, isOffline: true);
        expect(state.status, AuthStatus.authenticated);
        expect(state.user, testUser);
        expect(state.errorMessage, isNull);
        expect(state.isOffline, isTrue); // Check offline flag
      },
    );

    test('unauthenticated state should have correct properties', () {
      // AuthState.initial() covers this, but let's keep it explicit
      final state = AuthState(
        status: AuthStatus.unauthenticated,
      ); // Removed const
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);
      expect(state.errorMessage, isNull);
      expect(state.isOffline, isFalse); // Check default
    });

    test('loading state should have correct properties', () {
      final state = AuthState.loading(); // Removed const
      expect(state.status, AuthStatus.loading);
      expect(state.user, isNull);
      expect(state.errorMessage, isNull);
      expect(state.isOffline, isFalse); // Check default
    });

    test('error state should have correct properties', () {
      final state = AuthState.error('Something went wrong'); // Removed const
      expect(state.status, AuthStatus.error);
      expect(state.user, isNull);
      expect(state.errorMessage, 'Something went wrong');
      expect(state.isOffline, isFalse); // Check default
    });

    test('error state in offline mode should have correct properties', () {
      final state = AuthState.error('Offline Error', isOffline: true);
      expect(state.status, AuthStatus.error);
      expect(state.user, isNull);
      expect(state.errorMessage, 'Offline Error');
      expect(state.isOffline, isTrue); // Check offline flag
    });

    test('copyWith should update specified properties including offline', () {
      final state = AuthState.initial(); // Removed const
      final updatedState = state.copyWith(
        status: AuthStatus.authenticated,
        user: () => testUser,
        isOffline: true,
      );

      expect(updatedState.status, AuthStatus.authenticated);
      expect(updatedState.user, testUser);
      expect(updatedState.errorMessage, state.errorMessage);
      expect(updatedState.isOffline, true); // Check updated flag
    });

    test('copyWith should retain unspecified properties including offline', () {
      final state = AuthState.authenticated(testUser, isOffline: true);
      final updatedState = state.copyWith(status: AuthStatus.loading);

      expect(updatedState.status, AuthStatus.loading);
      expect(updatedState.user, state.user);
      expect(updatedState.errorMessage, state.errorMessage);
      expect(
        updatedState.isOffline,
        state.isOffline,
      ); // Check retained flag (true)
    });

    test('copyWith handles null values for message', () {
      final state = AuthState.error('Initial Error'); // Removed const
      final updatedState = state.copyWith(errorMessage: () => null);
      expect(updatedState.errorMessage, isNull);

      // Check retaining null
      final stateNull = AuthState(status: AuthStatus.authenticated);
      final updatedStateNull = stateNull.copyWith(status: AuthStatus.loading);
      expect(updatedStateNull.errorMessage, isNull);
    });

    test('copyWith handles null values for user', () {
      final state = AuthState.authenticated(testUser); // Removed const
      final updatedState = state.copyWith(user: () => null);
      expect(updatedState.user, isNull);

      // Check retaining null
      final stateNull = AuthState(status: AuthStatus.unauthenticated);
      final updatedStateNull = stateNull.copyWith(status: AuthStatus.loading);
      expect(updatedStateNull.user, isNull);
    });
  });
}
