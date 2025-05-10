import 'dart:async';

import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthNotifier – initial connectivity probe', () {
    late ProviderContainer container;

    setUp(() {
      // Reset GetIt to a clean slate before each test.
      GetIt.I.reset();

      // Register a fake NetworkInfo that reports OFFLINE.
      GetIt.I.registerSingleton<NetworkInfo>(
        FakeNetworkInfo(isConnected: false),
      );

      // Build a ProviderContainer with minimal overrides.
      container = ProviderContainer(
        overrides: [
          // Provide a fake AuthService – only the methods touched by
          // `checkAuthStatus()` are implemented.
          authServiceProvider.overrideWith((ref) => _FakeAuthService()),
          // Provide a concrete AuthEventBus so AuthNotifier can subscribe
          authEventBusProvider.overrideWith((ref) => AuthEventBus()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      GetIt.I.reset();
    });

    test('sets state.isOffline = true when offline at startup', () async {
      // Trigger notifier build.
      final notifier = container.read(authNotifierProvider.notifier);

      // Allow async tasks (initial connectivity check + auth check) to finish.
      await pumpEventQueue(times: 5);

      final state = notifier.state;

      expect(
        state.isOffline,
        isTrue,
        reason:
            'AuthNotifier should flag offline mode when the first '
            'connectivity probe reports no connection.',
      );
    });
  });
}

/// Minimal fake implementation of [NetworkInfo].
class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({required bool isConnected}) : _isConnected = isConnected;

  final bool _isConnected;

  @override
  Future<bool> get isConnected async => _isConnected;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

/// Very lightweight fake for [AuthService] that returns unauthenticated.
class _FakeAuthService implements AuthService {
  @override
  Future<bool> isAuthenticated({bool validateTokenLocally = false}) async =>
      false;

  @override
  Future<User> login(String email, String password) =>
      Future.error(UnsupportedError('login() not used in this test'));

  @override
  Future<void> logout() async {}

  @override
  Future<bool> refreshSession() async => false;

  @override
  Future<String> getCurrentUserId() =>
      Future.error(UnsupportedError('getCurrentUserId() not used'));

  @override
  Future<User> getUserProfile({bool acceptOfflineProfile = true}) =>
      Future.error(UnsupportedError('getUserProfile() not used'));
}
