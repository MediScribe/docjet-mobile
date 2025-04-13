import 'dart:async';

import 'package:docjet_mobile/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart'; // Import Domain state
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PlaybackStateMapperImpl mapper;
  late StreamController<DomainPlayerState> playerStateController;
  late StreamController<Duration> durationController;
  late StreamController<Duration> positionController;
  late StreamController<void> completeController;

  setUp(() {
    // Creates a fresh PlaybackStateMapperImpl for each test
    mapper = PlaybackStateMapperImpl();

    // Enable test mode to disable debouncing for predictable test behavior
    mapper.setTestMode(true);

    // Create controllers for test inputs
    playerStateController = StreamController<DomainPlayerState>.broadcast();
    durationController = StreamController<Duration>.broadcast();
    positionController = StreamController<Duration>.broadcast();
    completeController = StreamController<void>.broadcast();

    // Initialize the mapper with the test controllers
    mapper.initialize(
      playerStateStream: playerStateController.stream,
      durationStream: durationController.stream,
      positionStream: positionController.stream,
      completeStream: completeController.stream,
    );

    // No need to immediately listen here if we handle initial state correctly in tests
  });

  tearDown(() {
    // Clean up controllers
    playerStateController.close();
    durationController.close();
    positionController.close();
    completeController.close();
    mapper.dispose(); // Ensure mapper resources are cleaned up
  });

  test(
    'should emit Playing state with current duration and position when DomainPlayerState.playing event occurs',
    () async {
      // Arrange
      const initialDuration = Duration(seconds: 60);
      const initialPosition = Duration(seconds: 5);
      final expectedState = PlaybackState.playing(
        totalDuration: initialDuration,
        currentPosition: initialPosition,
      );

      // Define the expectation FIRST using emitsThrough
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsThrough(expectedState), // Waits until expectedState is emitted
      );

      // Act: Push initial duration and position
      // No need for delay here, let combineLatest handle it
      durationController.add(initialDuration);
      positionController.add(initialPosition);

      // Act: Push the playing event
      // No need for delay here either
      playerStateController.add(DomainPlayerState.playing);

      // Assert: Await the expectation. This ensures the test waits
      // long enough for the expected state to be emitted.
      await expectation;
    },
  );

  test(
    'should update state with new duration when onDurationChanged event occurs',
    () async {
      // Arrange
      const tInitialPosition = Duration(seconds: 5);
      const tInitialDuration = Duration(seconds: 60);
      const tNewDuration = Duration(seconds: 120);

      // Only define the FINAL expected state
      final expectedFinalState = PlaybackState.playing(
        currentPosition: tInitialPosition,
        totalDuration: tNewDuration, // Final duration
      );

      // Define expectation FIRST using emitsThrough
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsThrough(expectedFinalState),
      );

      // Act
      // 1. Set initial conditions
      positionController.add(tInitialPosition);
      durationController.add(tInitialDuration);
      // 2. Trigger playing state
      playerStateController.add(DomainPlayerState.playing);
      // 3. Trigger the new duration
      durationController.add(tNewDuration);

      // Assert
      await expectation;
    },
  );

  test(
    'should update state with new position when onPositionChanged event occurs',
    () async {
      // Arrange
      const tDuration = Duration(seconds: 60);
      const tInitialPosition = Duration(seconds: 5);
      const tNewPosition = Duration(seconds: 15);

      // Only define the FINAL expected state
      final expectedFinalState = PlaybackState.playing(
        currentPosition: tNewPosition, // Final position
        totalDuration: tDuration,
      );

      // Define expectation FIRST using emitsThrough
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsThrough(expectedFinalState),
      );

      // Act
      // 1. Set initial conditions
      positionController.add(tInitialPosition);
      durationController.add(tDuration);
      // 2. Trigger playing state
      playerStateController.add(DomainPlayerState.playing);
      // 3. Trigger the new position
      positionController.add(tNewPosition);

      // Assert
      await expectation;
    },
  );

  test(
    'should emit Paused state with current duration and position when DomainPlayerState.paused event occurs',
    () async {
      // Arrange
      const tDuration = Duration(seconds: 60);
      const tPosition = Duration(seconds: 15);
      // Only define the FINAL expected state
      const expectedFinalState = PlaybackState.paused(
        currentPosition: tPosition,
        totalDuration: tDuration,
      );

      // Define expectation FIRST using emitsThrough
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsThrough(expectedFinalState),
      );

      // Act
      // 1. Set initial conditions
      positionController.add(tPosition);
      durationController.add(tDuration);
      // 2. Trigger initial playing state (to have something to pause from)
      playerStateController.add(DomainPlayerState.playing);
      // 3. Trigger the target paused state
      playerStateController.add(DomainPlayerState.paused);

      // Assert
      await expectation;
    },
  );

  test(
    'should emit Stopped state when DomainPlayerState.stopped event occurs',
    () async {
      // Arrange
      const tDuration = Duration(seconds: 60);
      const tPosition = Duration(seconds: 15);
      // Only define the FINAL expected state
      const expectedFinalState = PlaybackState.stopped();

      // Define expectation FIRST using emitsThrough
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsThrough(expectedFinalState),
      );

      // Act
      // 1. Set initial conditions
      positionController.add(tPosition);
      durationController.add(tDuration);
      // 2. Trigger initial playing state (to have something to stop from)
      playerStateController.add(DomainPlayerState.playing);
      // 3. Trigger the target stopped state
      playerStateController.add(DomainPlayerState.stopped);

      // Assert
      await expectation;
    },
  );

  test(
    'should emit Completed state with final duration when onPlayerComplete event occurs',
    () async {
      // Arrange
      const tDuration = Duration(seconds: 60);
      const tPosition = Duration(seconds: 58); // Near the end
      // The final state should be Completed
      const expectedFinalState = PlaybackState.completed();

      // Define expectation FIRST using emitsThrough
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsThrough(expectedFinalState),
      );

      // Act
      // 1. Set initial conditions
      positionController.add(tPosition);
      durationController.add(tDuration);
      // 2. Trigger playing state
      playerStateController.add(DomainPlayerState.playing);
      // 3. Trigger the complete event
      completeController.add(null);
      playerStateController.add(DomainPlayerState.completed);

      // Assert
      await expectation;
    },
  );

  test(
    'should emit Loading state when DomainPlayerState.loading event occurs',
    () async {
      // Arrange
      const expectedFinalState = PlaybackState.loading();

      // Define expectation FIRST using emitsThrough
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsThrough(expectedFinalState),
      );

      // Act
      playerStateController.add(DomainPlayerState.loading);

      // Assert
      await expectation;
    },
  );

  test(
    'should emit Error state when DomainPlayerState.error event occurs',
    () async {
      // Arrange
      // The state includes the position/duration known at the time of the error
      final expectedFinalState = PlaybackState.error(
        message: 'Unknown player error',
        currentPosition: Duration.zero,
        totalDuration: Duration.zero,
      );

      // Define expectation FIRST using emitsThrough
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsThrough(expectedFinalState),
      );

      // Act
      playerStateController.add(DomainPlayerState.error);

      // Assert
      await expectation;
    },
  );

  test(
    'should handle errors from the playerStateStream',
    () async {
      // Arrange
      final testError = Exception('Player State Stream Error');
      // Match the EXACT message format from the mapper's onError handler
      final String expectedMessage =
          'Adapter player state stream error: $testError';
      final expectedErrorState = PlaybackState.error(
        message: expectedMessage, // <-- FIX
        currentPosition: Duration.zero, // <-- FIX
        totalDuration: Duration.zero, // <-- FIX
      );

      // Define expectation FIRST using emitsThrough
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsThrough(expectedErrorState),
      );

      // Act: Add an error to the source stream
      playerStateController.addError(testError);

      // Assert
      await expectation;
    },
    // Skip this test if error handling isn't forwarding through combineLatest as expected
    // skip: true, // Keep skip for now if needed
  );

  test('should handle complex sequence of events correctly', () async {
    // Arrange
    const duration1 = Duration(seconds: 100);
    const position1 = Duration(seconds: 10);
    const position2 = Duration(seconds: 20);
    const duration2 = Duration(seconds: 120);
    const position3 = Duration(seconds: 30);

    // Only define the VERY FINAL expected state
    final expectedFinalState = PlaybackState.completed();

    // Define expectation FIRST using emitsThrough
    final expectation = expectLater(
      mapper.playbackStateStream,
      emitsThrough(expectedFinalState),
    );

    // Act: Simulate a complex user interaction (NO DELAYS NEEDED)
    // 1. Load and start playing
    durationController.add(duration1);
    positionController.add(position1);
    playerStateController.add(DomainPlayerState.playing);

    // 2. Update position, then pause
    positionController.add(position2);
    playerStateController.add(DomainPlayerState.paused);

    // 3. Update duration while paused, then resume
    durationController.add(duration2);
    playerStateController.add(DomainPlayerState.playing);

    // 4. Stop the player
    playerStateController.add(DomainPlayerState.stopped);

    // 5. Start playing again (implies loading/ready)
    positionController.add(position3);
    playerStateController.add(DomainPlayerState.playing);

    // 6. Encounter an error
    playerStateController.add(DomainPlayerState.error);

    // 7. Finally, complete
    completeController.add(null);
    playerStateController.add(DomainPlayerState.completed);

    // Assert: Await the final expectation
    await expectation;
  });
}
