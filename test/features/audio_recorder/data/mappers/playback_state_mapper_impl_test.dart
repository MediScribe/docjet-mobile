import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:docjet_mobile/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart'; // Implementation (will be created)
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PlaybackStateMapperImpl mapper;
  late StreamController<PlayerState> playerStateController;
  late StreamController<Duration> durationController;
  late StreamController<Duration> positionController;
  late StreamController<void> completeController;

  setUp(() {
    // Arrange: Create controllers for each input stream
    playerStateController = StreamController<PlayerState>.broadcast();
    durationController = StreamController<Duration>.broadcast();
    positionController = StreamController<Duration>.broadcast();
    completeController = StreamController<void>.broadcast();

    // Arrange: Instantiate the mapper (implementation needed)
    mapper = PlaybackStateMapperImpl();

    // Arrange: Initialize the mapper with the streams
    mapper.initialize(
      playerStateStream: playerStateController.stream,
      durationStream: durationController.stream,
      positionStream: positionController.stream,
      completeStream: completeController.stream,
    );
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
    'should emit Playing state with current duration and position when PlayerState.playing event occurs',
    () async {
      // Arrange
      const initialDuration = Duration(seconds: 60);
      const initialPosition = Duration(seconds: 5);
      const expectedState = PlaybackState.playing(
        totalDuration: initialDuration,
        currentPosition: initialPosition,
      );

      // Assert: Use emitsInOrder to check the sequence explicitly
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsInOrder([
          const PlaybackState.initial(), // Initial state
          const PlaybackState.stopped(), // First state triggered by duration/position
          // Second stopped() is filtered by distinct()
          expectedState, // The target playing state
        ]),
      );

      // Act: Push initial duration and position
      durationController.add(initialDuration);
      positionController.add(initialPosition);

      // Act: Push the playing event
      playerStateController.add(PlayerState.playing);

      // Wait for the expectation to complete
      await expectation;

      // Optional: Close controllers if needed for stream termination, although
      // expectLater with emitsInOrder often handles this.
      // await playerStateController.close();
      // await durationController.close();
      // await positionController.close();
    },
  );

  test(
    'should update state with new duration when onDurationChanged event occurs',
    () async {
      // Arrange: First get to a playing state with initial duration
      const initialDuration = Duration(seconds: 60);
      const initialPosition = Duration(seconds: 5);

      // Set initial state (necessary to transition to a state that has duration)
      durationController.add(initialDuration);
      positionController.add(initialPosition);
      playerStateController.add(PlayerState.playing);

      // Skip the first three states to get to our stable playing state
      await expectLater(
        mapper.playbackStateStream,
        emitsInOrder([
          const PlaybackState.initial(),
          const PlaybackState.stopped(),
          const PlaybackState.playing(
            totalDuration: initialDuration,
            currentPosition: initialPosition,
          ),
        ]),
      );

      // New duration to test
      const newDuration = Duration(seconds: 120);

      // Expect the new state with updated duration (keeping same position)
      final expectation = expectLater(
        mapper.playbackStateStream,
        emits(
          const PlaybackState.playing(
            totalDuration: newDuration, // Updated duration
            currentPosition: initialPosition, // Same position
          ),
        ),
      );

      // Act: Push a duration update
      durationController.add(newDuration);

      // Wait for the expectation to complete
      await expectation;
    },
  );

  test(
    'should update state with new position when onPositionChanged event occurs',
    () async {
      // Arrange: First get to a playing state with initial position
      const initialDuration = Duration(seconds: 60);
      const initialPosition = Duration(seconds: 5);

      // Set initial state
      durationController.add(initialDuration);
      positionController.add(initialPosition);
      playerStateController.add(PlayerState.playing);

      // Skip the first three states to get to our stable playing state
      await expectLater(
        mapper.playbackStateStream,
        emitsInOrder([
          const PlaybackState.initial(),
          const PlaybackState.stopped(),
          const PlaybackState.playing(
            totalDuration: initialDuration,
            currentPosition: initialPosition,
          ),
        ]),
      );

      // New position to test
      const newPosition = Duration(seconds: 30);

      // Expect the new state with updated position (keeping same duration)
      final expectation = expectLater(
        mapper.playbackStateStream,
        emits(
          const PlaybackState.playing(
            totalDuration: initialDuration, // Same duration
            currentPosition: newPosition, // Updated position
          ),
        ),
      );

      // Act: Push a position update
      positionController.add(newPosition);

      // Wait for the expectation to complete
      await expectation;
    },
  );

  test(
    'should emit Paused state with current duration and position when PlayerState.paused event occurs',
    () async {
      // Arrange: First set up a playing state (duration + position must be set)
      const duration = Duration(seconds: 60);
      const position = Duration(seconds: 15);

      durationController.add(duration);
      positionController.add(position);
      playerStateController.add(PlayerState.playing);

      // Skip initial transitions to get to playing state
      await expectLater(
        mapper.playbackStateStream,
        emitsInOrder([
          const PlaybackState.initial(),
          const PlaybackState.stopped(),
          const PlaybackState.playing(
            totalDuration: duration,
            currentPosition: position,
          ),
        ]),
      );

      // Expected paused state
      const expectedState = PlaybackState.paused(
        totalDuration: duration,
        currentPosition: position,
      );

      // Set up expectation for pause event
      final expectation = expectLater(
        mapper.playbackStateStream,
        emits(expectedState),
      );

      // Act: Emit paused state
      playerStateController.add(PlayerState.paused);

      // Wait for expectation to complete
      await expectation;
    },
  );

  test(
    'should emit Stopped state when PlayerState.stopped event occurs',
    () async {
      // Arrange: First set up a playing state (duration + position must be set)
      const duration = Duration(seconds: 60);
      const position = Duration(seconds: 15);

      durationController.add(duration);
      positionController.add(position);
      playerStateController.add(PlayerState.playing);

      // Skip initial transitions to get to playing state
      await expectLater(
        mapper.playbackStateStream,
        emitsInOrder([
          const PlaybackState.initial(),
          const PlaybackState.stopped(),
          const PlaybackState.playing(
            totalDuration: duration,
            currentPosition: position,
          ),
        ]),
      );

      // Expected stopped state
      const expectedState = PlaybackState.stopped();

      // Set up expectation for stopped event
      final expectation = expectLater(
        mapper.playbackStateStream,
        emits(expectedState),
      );

      // Act: Emit stopped state
      playerStateController.add(PlayerState.stopped);

      // Wait for expectation to complete
      await expectation;
    },
  );

  test(
    'should emit Completed state when onPlayerComplete event occurs',
    () async {
      // Arrange: First set up a playing state
      const duration = Duration(seconds: 60);
      const position = Duration(seconds: 15);

      durationController.add(duration);
      positionController.add(position);
      playerStateController.add(PlayerState.playing);

      // Skip initial transitions to get to playing state
      await expectLater(
        mapper.playbackStateStream,
        emitsInOrder([
          const PlaybackState.initial(),
          const PlaybackState.stopped(),
          const PlaybackState.playing(
            totalDuration: duration,
            currentPosition: position,
          ),
        ]),
      );

      // Expected completed state
      const expectedState = PlaybackState.completed();

      // Set up expectation for completion event
      final expectation = expectLater(
        mapper.playbackStateStream,
        emits(expectedState),
      );

      // Act: Emit completion event
      completeController.add(null); // void event, value is ignored

      // Wait for expectation to complete
      await expectation;
    },
  );

  test('should emit Error state when error occurs in any stream', () async {
    // Arrange: Create a controller that we can manually add errors to
    final errorController = StreamController<Duration>.broadcast();

    // Arrange: Set up a playing state first
    const duration = Duration(seconds: 60);
    const position = Duration(seconds: 15);
    final errorMessage = 'Test error message';

    // Create a new mapper instance for this test to isolate behavior
    final errorMapper = PlaybackStateMapperImpl();

    // Add our special controller to the initialize call
    errorMapper.initialize(
      positionStream:
          errorController.stream, // Use our error-capable controller
      durationStream: durationController.stream,
      completeStream: completeController.stream,
      playerStateStream: playerStateController.stream,
    );

    // Add regular events to set up a playing state
    durationController.add(duration);
    errorController.add(position); // Use our controller for position
    playerStateController.add(PlayerState.playing);

    // Skip to playing state
    await expectLater(
      errorMapper.playbackStateStream,
      emitsInOrder([
        const PlaybackState.initial(),
        const PlaybackState.stopped(),
        const PlaybackState.playing(
          totalDuration: duration,
          currentPosition: position,
        ),
      ]),
    );

    // Set up expectation for error state
    final expectation = expectLater(
      errorMapper.playbackStateStream,
      emits(
        predicate<PlaybackState>((state) {
          return state.maybeMap(
            error: (errorState) => errorState.message.contains(errorMessage),
            orElse: () => false,
          );
        }, 'is an error state containing "$errorMessage"'),
      ),
    );

    // Act: Add an error to our controller
    errorController.addError(Exception(errorMessage));

    // Remove the extra position update - no longer needed since our mapper
    // now emits errors immediately through a dedicated error stream

    // Wait for expectation to complete
    await expectation;

    // Clean up
    errorController.close();
    errorMapper.dispose();
  });

  test(
    'should emit correct sequence of states for play -> pause -> resume flow',
    () async {
      // Arrange: Set up test data
      const duration = Duration(seconds: 60);
      const initialPosition = Duration(seconds: 5);
      const midPosition = Duration(seconds: 15);

      // Set up expectation for the entire sequence
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsInOrder([
          // Initial state on mapper creation
          const PlaybackState.initial(),

          // First we'll get stopped state when setting duration/position
          const PlaybackState.stopped(),

          // Then playing state when player starts
          PlaybackState.playing(
            totalDuration: duration,
            currentPosition: initialPosition,
          ),

          // Position updates during playback
          PlaybackState.playing(
            totalDuration: duration,
            currentPosition: midPosition,
          ),

          // Pause state
          PlaybackState.paused(
            totalDuration: duration,
            currentPosition: midPosition,
          ),

          // Resume playback (return to playing)
          PlaybackState.playing(
            totalDuration: duration,
            currentPosition: midPosition,
          ),

          // And finally stop
          const PlaybackState.stopped(),
        ]),
      );

      // Act 1: Set initial duration and position
      durationController.add(duration);
      positionController.add(initialPosition);

      // Act 2: Start playing
      playerStateController.add(PlayerState.playing);

      // Act 3: Update position during playback
      positionController.add(midPosition);

      // Act 4: Pause
      playerStateController.add(PlayerState.paused);

      // Act 5: Resume
      playerStateController.add(PlayerState.playing);

      // Act 6: Stop
      playerStateController.add(PlayerState.stopped);

      // Wait for expectation to complete
      await expectation;
    },
  );

  // No more mapper tests needed
}
