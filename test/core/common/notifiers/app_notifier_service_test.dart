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

  test('throws ArgumentError when duration is non-positive', () {
    // Arrange
    const message = 'Invalid Duration Test';
    const type = MessageType.error;
    final invalidDuration = Duration(seconds: -5);

    // Act & Assert
    expect(
      () => notifier.show(
        message: message,
        type: type,
        duration: invalidDuration,
      ),
      throwsArgumentError,
    );
  });

  test('show() accepts custom message ID', () {
    // Arrange
    const message = 'Custom ID Test';
    const type = MessageType.info;
    const customId = 'my-custom-id-123';

    // Act
    notifier.show(message: message, type: type, id: customId);

    // Assert
    final state = container.read(appNotifierServiceProvider);
    expect(state, isNotNull);
    expect(state?.id, customId);
  });

  test('identical messages with different IDs are considered unique', () {
    // Arrange
    const message = 'Same Message';
    const type = MessageType.warning;
    final firstId = 'first-id';
    final secondId = 'second-id';

    // Act - show two identical messages with different IDs
    notifier.show(message: message, type: type, id: firstId);
    final firstState = container.read(appNotifierServiceProvider);

    notifier.show(message: message, type: type, id: secondId);
    final secondState = container.read(appNotifierServiceProvider);

    // Assert
    expect(firstState, isNotNull);
    expect(secondState, isNotNull);
    expect(
      firstState != secondState,
      isTrue,
      reason: 'Messages with different IDs should be treated as different',
    );
    expect(firstState?.id, firstId);
    expect(secondState?.id, secondId);
  });

  test('sequential messages with different types are handled correctly', () {
    // Arrange
    const baseMessage = 'Type Test';

    // Act - show messages with all different types
    notifier.show(message: '$baseMessage - Info', type: MessageType.info);
    final infoState = container.read(appNotifierServiceProvider);

    notifier.show(message: '$baseMessage - Success', type: MessageType.success);
    final successState = container.read(appNotifierServiceProvider);

    notifier.show(message: '$baseMessage - Warning', type: MessageType.warning);
    final warningState = container.read(appNotifierServiceProvider);

    notifier.show(message: '$baseMessage - Error', type: MessageType.error);
    final errorState = container.read(appNotifierServiceProvider);

    // Assert
    expect(infoState?.type, MessageType.info);
    expect(successState?.type, MessageType.success);
    expect(warningState?.type, MessageType.warning);
    expect(errorState?.type, MessageType.error);

    // Last message shown should be current state
    expect(
      container.read(appNotifierServiceProvider)?.message,
      '$baseMessage - Error',
    );
  });

  test('dismiss() on empty state has no effect', () {
    // Arrange - ensure state is null
    notifier.dismiss(); // Just to be certain
    expect(container.read(appNotifierServiceProvider), isNull);

    // Act - call dismiss on empty state
    // This should not throw exceptions
    notifier.dismiss();

    // Assert
    expect(container.read(appNotifierServiceProvider), isNull);
  });

  test(
    'reusing the same ID with different message content works correctly',
    () => fakeAsync((async) {
      // Arrange
      const id = 'reused-id';
      const firstMessage = 'First message with ID';
      const secondMessage = 'Second message with same ID';
      const duration = Duration(seconds: 5);

      // Act 1 - Show first message with ID and duration
      notifier.show(
        message: firstMessage,
        type: MessageType.info,
        id: id,
        duration: duration,
      );
      final firstState = container.read(appNotifierServiceProvider);

      // Advance time but not enough to dismiss
      async.elapse(const Duration(seconds: 2));

      // Act 2 - Show second message with same ID but different content
      notifier.show(message: secondMessage, type: MessageType.warning, id: id);
      final secondState = container.read(appNotifierServiceProvider);

      // Assert
      expect(firstState?.id, id);
      expect(secondState?.id, id);
      expect(secondState?.message, secondMessage);
      expect(secondState?.type, MessageType.warning);

      // The timer from the first message should be cancelled
      // The second message has no duration, so it should remain
      async.elapse(duration * 2);
      expect(container.read(appNotifierServiceProvider), isNotNull);
      expect(
        container.read(appNotifierServiceProvider)?.message,
        secondMessage,
      );
    }),
  );
}
