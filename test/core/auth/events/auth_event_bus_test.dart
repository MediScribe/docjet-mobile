import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart'; // Will fail initially
import 'dart:async';

void main() {
  late AuthEventBus authEventBus;

  setUp(() {
    // This will fail until AuthEventBus is implemented
    authEventBus = AuthEventBus();
  });

  tearDown(() {
    authEventBus.dispose(); // Ensure resources are released
  });

  group('AuthEventBus', () {
    test('should emit events to listeners', () async {
      final Completer<AuthEvent> completer = Completer<AuthEvent>();

      // Subscribe to the stream
      final subscription = authEventBus.stream.listen((event) {
        completer.complete(event);
      });

      // Emit an event
      authEventBus.add(AuthEvent.loggedIn);

      // Expect the listener to receive the event
      expect(await completer.future, equals(AuthEvent.loggedIn));

      // Clean up
      await subscription.cancel();
    });

    test('should emit events to multiple listeners', () async {
      final Completer<AuthEvent> completer1 = Completer<AuthEvent>();
      final Completer<AuthEvent> completer2 = Completer<AuthEvent>();

      final subscription1 = authEventBus.stream.listen((event) {
        completer1.complete(event);
      });
      final subscription2 = authEventBus.stream.listen((event) {
        completer2.complete(event);
      });

      authEventBus.add(AuthEvent.loggedOut);

      expect(await completer1.future, equals(AuthEvent.loggedOut));
      expect(await completer2.future, equals(AuthEvent.loggedOut));

      await subscription1.cancel();
      await subscription2.cancel();
    });

    test('listener should not receive events after unsubscribing', () async {
      AuthEvent? receivedEvent;
      final Completer<void> receivedCompleter = Completer<void>();

      final subscription = authEventBus.stream.listen((event) {
        receivedEvent = event;
        receivedCompleter.complete();
      });

      // Emit first event, expect it
      authEventBus.add(AuthEvent.loggedIn);
      await receivedCompleter.future; // Wait for the first event
      expect(receivedEvent, equals(AuthEvent.loggedIn));

      // Unsubscribe
      await subscription.cancel();

      // Emit second event
      authEventBus.add(AuthEvent.loggedOut);

      // Give it a moment to potentially process, although it shouldn't
      await Future.delayed(const Duration(milliseconds: 50));

      // Expect the received event is still the first one
      expect(receivedEvent, equals(AuthEvent.loggedIn));
    });
  });
}
