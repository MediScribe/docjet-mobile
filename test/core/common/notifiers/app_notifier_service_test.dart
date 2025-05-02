import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/common/models/app_message.dart';
import 'package:docjet_mobile/core/common/notifiers/app_notifier_service.dart';

void main() {
  late ProviderContainer container;
  late AppNotifierService notifier;

  setUp(() {
    container = ProviderContainer();
    // Listen to the provider to keep it alive, similar to how UI would
    container.listen(appNotifierServiceProvider, (_, __) {});
    // Access the notifier instance directly for testing method calls
    notifier = container.read(appNotifierServiceProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  test('initial state is null', () {
    expect(container.read(appNotifierServiceProvider), isNull);
  });

  test('show() updates state with correct message', () {
    // Arrange
    const message = 'Test Info';
    const type = MessageType.info;

    // Act
    notifier.show(message: message, type: type);

    // Assert
    final state = container.read(appNotifierServiceProvider);
    expect(state, isNotNull);
    expect(state?.message, message);
    expect(state?.type, type);
    expect(state?.duration, isNull);
    expect(state?.id, isNotEmpty);
  });

  test('show() with duration updates state and stores duration', () {
    // Arrange
    const message = 'Test Success';
    const type = MessageType.success;
    const duration = Duration(seconds: 5);

    // Act
    notifier.show(message: message, type: type, duration: duration);

    // Assert
    final state = container.read(appNotifierServiceProvider);
    expect(state, isNotNull);
    expect(state?.message, message);
    expect(state?.type, type);
    expect(state?.duration, duration);
  });

  test('dismiss() sets state to null', () {
    // Arrange
    notifier.show(message: 'To Dismiss', type: MessageType.warning);
    expect(
      container.read(appNotifierServiceProvider),
      isNotNull,
      reason: 'State should not be null before dismiss',
    );

    // Act
    notifier.dismiss();

    // Assert
    expect(container.read(appNotifierServiceProvider), isNull);
  });

  test(
    'show() replaces existing message and cancels timer',
    () => fakeAsync((async) {
      // Arrange: Show first message with a long duration
      const firstMessage = 'First Message';
      const firstDuration = Duration(minutes: 1);
      notifier.show(
        message: firstMessage,
        type: MessageType.info,
        duration: firstDuration,
      );
      final firstState = container.read(appNotifierServiceProvider);
      expect(firstState?.message, firstMessage);

      // Act: Show second message immediately
      const secondMessage = 'Second Message';
      const secondType = MessageType.error;
      notifier.show(message: secondMessage, type: secondType);

      // Assert: Second message is shown
      final secondState = container.read(appNotifierServiceProvider);
      expect(secondState?.message, secondMessage);
      expect(secondState?.type, secondType);
      expect(secondState?.duration, isNull);

      // Assert: First message timer was cancelled (state remains second message after first duration)
      async.elapse(firstDuration + const Duration(seconds: 1));
      expect(
        container.read(appNotifierServiceProvider)?.message,
        secondMessage,
        reason: 'First timer should have been cancelled',
      );
    }),
  );

  test(
    'show() with duration auto-dismisses after duration',
    () => fakeAsync((async) {
      // Arrange
      const message = 'Auto Dismiss';
      const type = MessageType.warning;
      const duration = Duration(seconds: 3);

      // Act
      notifier.show(message: message, type: type, duration: duration);

      // Assert: Message is present initially
      expect(container.read(appNotifierServiceProvider)?.message, message);

      // Assert: Message is still present just before duration ends
      async.elapse(duration - const Duration(milliseconds: 1));
      expect(container.read(appNotifierServiceProvider)?.message, message);

      // Assert: Message is dismissed exactly after duration
      async.elapse(const Duration(milliseconds: 1));
      expect(container.read(appNotifierServiceProvider), isNull);
    }),
  );

  test(
    'show() with null duration does not auto-dismiss',
    () => fakeAsync((async) {
      // Arrange
      const message = 'Manual Dismiss';
      const type = MessageType.info;

      // Act
      notifier.show(message: message, type: type, duration: null);

      // Assert: Message is present initially
      expect(container.read(appNotifierServiceProvider)?.message, message);

      // Assert: Message is still present after a long time
      async.elapse(const Duration(hours: 1));
      expect(container.read(appNotifierServiceProvider)?.message, message);
    }),
  );

  test(
    'dismiss() cancels the auto-dismiss timer',
    () => fakeAsync((async) {
      // Arrange
      const message = 'Dismiss Test';
      const type = MessageType.error;
      const duration = Duration(seconds: 5);
      notifier.show(message: message, type: type, duration: duration);
      expect(container.read(appNotifierServiceProvider), isNotNull);

      // Act: Dismiss before the timer fires
      async.elapse(const Duration(seconds: 1));
      notifier.dismiss();

      // Assert: State is null immediately
      expect(container.read(appNotifierServiceProvider), isNull);

      // Assert: State remains null even after the original duration passes
      async.elapse(duration);
      expect(
        container.read(appNotifierServiceProvider),
        isNull,
        reason: 'Timer should have been cancelled by dismiss()',
      );
    }),
  );

  test(
    'timer is cancelled when notifier is disposed',
    () => fakeAsync((async) {
      // Arrange: Show a message with a duration
      const message = 'Dispose Test';
      const duration = Duration(seconds: 10);
      notifier.show(
        message: message,
        type: MessageType.info,
        duration: duration,
      );
      expect(container.read(appNotifierServiceProvider), isNotNull);

      // Act: Dispose the container (which disposes the notifier)
      container.dispose();

      // Assert: Attempting to elapse time should not cause issues (or crashes)
      // We can't directly check the timer, but ensure no exceptions occur.
      // and that the state wouldn't have changed IF the timer had fired.
      // A better check might involve mocking the Timer, but this is okay for now.
      try {
        async.elapse(duration * 2);
        // No assertion needed here, just checking absence of exceptions
      } catch (e) {
        fail('Elapsing time after dispose caused an error: $e');
      }

      // Re-create container to check state (which should be initial null)
      container = ProviderContainer();
      expect(
        container.read(appNotifierServiceProvider),
        isNull,
        reason: 'State should be null in a new container',
      );
    }),
  );
}
