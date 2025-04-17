import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([AuthService])
import 'auth_notifier_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late ProviderContainer container;
  late User testUser;

  const testEmail = 'test@example.com';
  const testPassword = 'password123';
  const testUserId = 'test-user-id';

  setUp(() {
    mockAuthService = MockAuthService();

    // Create a ProviderContainer with overrides
    container = ProviderContainer(
      overrides: [
        // Override the auth service provider with our mock
        authServiceProvider.overrideWithValue(mockAuthService),
      ],
    );

    testUser = const User(id: testUserId);
  });

  // Clean up the ProviderContainer after each test
  tearDown(() {
    container.dispose();
  });

  group('initial state', () {
    test('should check authentication status on initialization', () async {
      // Arrange
      when(mockAuthService.isAuthenticated()).thenAnswer((_) async => false);

      // Act - reading the provider triggers build()
      container.read(authNotifierProvider);

      // Wait for any pending asynchronous operations
      await Future.delayed(Duration.zero);

      // Assert
      verify(mockAuthService.isAuthenticated()).called(1);
    });
  });

  group('login', () {
    test('should update state to authenticated when login succeeds', () async {
      // Arrange
      when(mockAuthService.isAuthenticated()).thenAnswer((_) async => false);
      when(
        mockAuthService.login(testEmail, testPassword),
      ).thenAnswer((_) async => testUser);

      // Initialize the notifier
      final notifier = container.read(authNotifierProvider.notifier);

      // Act
      await notifier.login(testEmail, testPassword);

      // Assert
      final state = container.read(authNotifierProvider);
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.user, equals(testUser));
      verify(mockAuthService.login(testEmail, testPassword)).called(1);
    });

    test('should update state to error when login fails', () async {
      // Arrange
      when(mockAuthService.isAuthenticated()).thenAnswer((_) async => false);
      when(
        mockAuthService.login(testEmail, testPassword),
      ).thenThrow(AuthException.invalidCredentials());

      // Initialize the notifier
      final notifier = container.read(authNotifierProvider.notifier);

      // Act
      await notifier.login(testEmail, testPassword);

      // Assert
      final state = container.read(authNotifierProvider);
      expect(state.status, equals(AuthStatus.error));
      expect(state.errorMessage, isNotNull);
      verify(mockAuthService.login(testEmail, testPassword)).called(1);
    });
  });

  group('logout', () {
    test('should update state to unauthenticated after logout', () async {
      // Arrange
      when(mockAuthService.isAuthenticated()).thenAnswer((_) async => false);
      when(mockAuthService.logout()).thenAnswer((_) async => {});

      // Initialize the notifier
      final notifier = container.read(authNotifierProvider.notifier);

      // Manually set state to authenticated for this test
      // (Note: this is a simplification; in a real test we might need
      // to mock the provider state more thoroughly)
      when(mockAuthService.login(any, any)).thenAnswer((_) async => testUser);
      await notifier.login('user@test.com', 'password');

      // Act
      await notifier.logout();

      // Assert
      final state = container.read(authNotifierProvider);
      expect(state.status, equals(AuthStatus.unauthenticated));
      expect(state.user, isNull);
      verify(mockAuthService.logout()).called(1);
    });
  });

  group('session refresh', () {
    test('should authenticate user when valid session exists', () async {
      // Arrange
      when(mockAuthService.isAuthenticated()).thenAnswer((_) async => true);
      when(mockAuthService.refreshSession()).thenAnswer((_) async => true);

      // Act - reading the provider triggers build() which calls _checkAuthStatus()
      container.read(authNotifierProvider);

      // Wait for async operations to complete
      await Future.delayed(Duration.zero);

      // Assert
      final state = container.read(authNotifierProvider);
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.user, isNotNull);
      verify(mockAuthService.isAuthenticated()).called(1);
      verify(mockAuthService.refreshSession()).called(1);
    });

    test('should log out when session refresh fails', () async {
      // Arrange
      when(mockAuthService.isAuthenticated()).thenAnswer((_) async => true);
      when(mockAuthService.refreshSession()).thenAnswer((_) async => false);
      when(mockAuthService.logout()).thenAnswer((_) async => {});

      // Act - reading the provider triggers build() which calls _checkAuthStatus()
      container.read(authNotifierProvider);

      // Wait for async operations to complete
      await Future.delayed(Duration.zero);

      // Assert
      verify(mockAuthService.refreshSession()).called(1);
      verify(mockAuthService.logout()).called(1);

      final state = container.read(authNotifierProvider);
      expect(state.status, equals(AuthStatus.unauthenticated));
    });
  });
}
