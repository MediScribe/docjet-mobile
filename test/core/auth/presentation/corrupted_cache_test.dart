import 'dart:async';

import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/common/models/app_message.dart';
import 'package:docjet_mobile/core/common/notifiers/app_notifier_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import just the auth_notifier_test.mocks.dart which has all the mocks we need
import 'auth_notifier_test.mocks.dart';

// A fake app notifier service to track notifications
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

// We don't need to generate mocks since we're importing them
void main() {
  late ProviderContainer container;
  late SharedPreferences prefs;
  late FakeAppNotifierService fakeAppNotifier;
  late MockAuthService mockAuthService;
  late MockAuthEventBus mockAuthEventBus;
  late MockAutofillService mockAutofillService;
  late StreamController<AuthEvent> eventController;

  setUp(() async {
    // Setup SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    // Create a fake app notifier
    fakeAppNotifier = FakeAppNotifierService();

    // Create mocks
    mockAuthService = MockAuthService();
    mockAuthEventBus = MockAuthEventBus();
    mockAutofillService = MockAutofillService();

    // Setup event bus stream
    eventController = StreamController<AuthEvent>();
    when(mockAuthEventBus.stream).thenAnswer((_) => eventController.stream);
  });

  tearDown(() {
    eventController.close();
    container.dispose();
  });

  test('AuthNotifier handles corrupted profile cache gracefully', () async {
    // Set corrupted data in SharedPreferences for a test user
    const testUserId = 'test-user-123';
    const corruptedJson = '{invalid:json-data]';

    // Use the same key pattern as the real cache
    await prefs.setString('cached_profile_$testUserId', corruptedJson);

    // First the normal token auth fails (no token or expired)
    when(
      mockAuthService.isAuthenticated(validateTokenLocally: false),
    ).thenAnswer((_) async => false);

    // But the local validation succeeds (validateTokenLocally: true)
    when(
      mockAuthService.isAuthenticated(validateTokenLocally: true),
    ).thenAnswer((_) async => true);

    // Then when getUserProfile is called with acceptOfflineProfile: true, it throws
    // representing the corrupted profile cache
    when(
      mockAuthService.getUserProfile(acceptOfflineProfile: true),
    ).thenThrow(Exception('Corrupted profile cache'));

    // Setup the container with our mocks
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        authEventBusProvider.overrideWithValue(mockAuthEventBus),
        autofillServiceProvider.overrideWithValue(mockAutofillService),
        appNotifierServiceProvider.overrideWith(() => fakeAppNotifier),
      ],
    );

    // Initialize the notifier
    container.read(authNotifierProvider);
    await pumpEventQueue();

    // Verify behavior
    final authState = container.read(authNotifierProvider);

    // Should still be authenticated but with anonymous user
    expect(authState.status, equals(AuthStatus.authenticated));
    expect(authState.user, isNotNull);
    expect(authState.user!.isAnonymous, isTrue);

    // Should have shown an error notification
    expect(fakeAppNotifier.showCalls.length, 1);
    expect(fakeAppNotifier.showCalls.first.type, equals(MessageType.error));
    expect(
      fakeAppNotifier.showCalls.first.message,
      contains('Unable to load your profile'),
    );
  });
}
