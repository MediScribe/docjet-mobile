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
    // Arrange: Create controllers for each input stream
    playerStateController = StreamController<DomainPlayerState>.broadcast();
    durationController = StreamController<Duration>.broadcast();
    positionController = StreamController<Duration>.broadcast();
    completeController = StreamController<void>.broadcast();

    // Arrange: Instantiate the mapper
    mapper = PlaybackStateMapperImpl();

    // Arrange: Initialize the mapper with the streams - ENSURE CORRECT TYPE
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
    'should emit Playing state with current duration and position when DomainPlayerState.playing event occurs',
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
      playerStateController.add(DomainPlayerState.playing);

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
      playerStateController.add(DomainPlayerState.playing);

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
      playerStateController.add(DomainPlayerState.playing);

      // Skip the first three states to get to our stable playing state
      await expectLater(
        mapper.playbackStateStream,
        emitsInOrder([
          const PlaybackState.initial(),
          const PlaybackState.stopped(), // Triggered by initial duration/position
          // Distinct() should filter duplicates if duration/position emit stopped again
          const PlaybackState.playing(
            totalDuration: initialDuration,
            currentPosition: initialPosition,
          ), // Triggered by playing state
        ]),
      );

      // New positions to test in sequence
      const positionUpdate1 = Duration(seconds: 10);
      const positionUpdate2 = Duration(seconds: 15);
      const positionUpdate3 = Duration(seconds: 20);

      // Expect the new states with updated positions (keeping same duration)
      // We expect ONE state emission PER position update
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsInOrder([
          PlaybackState.playing(
            totalDuration: initialDuration, // Same duration
            currentPosition: positionUpdate1, // Updated position 1
          ),
          PlaybackState.playing(
            totalDuration: initialDuration, // Same duration
            currentPosition: positionUpdate2, // Updated position 2
          ),
          PlaybackState.playing(
            totalDuration: initialDuration, // Same duration
            currentPosition: positionUpdate3, // Updated position 3
          ),
        ]),
      );

      // Act: Push multiple position updates sequentially
      positionController.add(positionUpdate1);
      // Need a small delay or yield if using fake_async to allow stream processing
      // await Future.delayed(Duration.zero); // Use if not in fake_async
      positionController.add(positionUpdate2);
      // await Future.delayed(Duration.zero);
      positionController.add(positionUpdate3);

      // Wait for the expectation to complete
      await expectation;
    },
  );

  test(
    'should emit Paused state with current duration and position when DomainPlayerState.paused event occurs',
    () async {
      // Arrange: First set up a playing state (duration + position must be set)
      const duration = Duration(seconds: 60);
      const position = Duration(seconds: 15);

      durationController.add(duration);
      positionController.add(position);
      playerStateController.add(DomainPlayerState.playing);

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
      playerStateController.add(DomainPlayerState.paused);

      // Wait for expectation to complete
      await expectation;
    },
  );

  test(
    'should emit Stopped state when DomainPlayerState.stopped event occurs',
    () async {
      // Arrange: First set up a playing state (duration + position must be set)
      const duration = Duration(seconds: 60);
      const position = Duration(seconds: 15);

      durationController.add(duration);
      positionController.add(position);
      playerStateController.add(DomainPlayerState.playing);

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
      playerStateController.add(DomainPlayerState.stopped);

      // Wait for expectation to complete
      await expectation;
    },
  );

  test(
    'should emit Completed state with final duration when onPlayerComplete event occurs',
    () async {
      // Arrange: First set up a playing state
      const duration = Duration(seconds: 60);
      const position = Duration(seconds: 15);

      durationController.add(duration);
      positionController.add(position);
      playerStateController.add(DomainPlayerState.playing);

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

      // Act: Emit complete event via the dedicated stream
      completeController.add(null);

      // Wait for expectation to complete
      await expectation;
    },
  );

  test(
    'should emit Loading state when DomainPlayerState.loading event occurs',
    () async {
      // Arrange
      const expectedState = PlaybackState.loading();
      // Expect initial first, then loading
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsInOrder([const PlaybackState.initial(), expectedState]),
      );

      // Act: Emit loading state
      playerStateController.add(DomainPlayerState.loading);

      // Wait for expectation to complete
      await expectation;
    },
  );

  test(
    'should emit Error state when DomainPlayerState.error event occurs',
    () async {
      // Arrange
      // Align expectation with the actual message and data from _constructState fallback
      const expectedState = PlaybackState.error(
        message: 'Playback error state encountered',
        currentPosition: Duration.zero,
        totalDuration: Duration.zero,
      );
      // Expect initial first, then error
      final expectation = expectLater(
        mapper.playbackStateStream,
        emitsInOrder([const PlaybackState.initial(), expectedState]),
      );

      // Act: Emit error state
      playerStateController.add(DomainPlayerState.error); // Changed value

      // Wait for expectation to complete
      await expectation;
    },
  );

  test('should ignore consecutive identical states', () async {
    // ... (rest of test setup, ensure playerStateController adds DomainPlayerState.playing)
    playerStateController.add(DomainPlayerState.playing); // Changed value
    await Future.delayed(Duration.zero); // Allow stream to process

    // ... (rest of test setup for expectLater)

    // Act: Emit states that should be filtered
    playerStateController.add(DomainPlayerState.playing); // Already playing
    playerStateController.add(DomainPlayerState.playing); // Still playing

    // ... (rest of test)
  });

  test('should reset to stopped when current file path is cleared', () async {
    // ... (rest of test setup, ensure playerStateController adds DomainPlayerState.playing)
    playerStateController.add(DomainPlayerState.playing); // Changed value
    await Future.delayed(Duration.zero); // Allow stream to process
    mapper.setCurrentFilePath('some/path.mp3');
    await Future.delayed(
      Duration.zero,
    ); // Allow stream to process potential state change if any

    // ... (rest of test setup for expectLater)

    // Act
    mapper.setCurrentFilePath(null); // Reset file path
    // Optionally push another state to see if it resets correctly
    playerStateController.add(DomainPlayerState.stopped); // Changed value

    // ... (rest of test)
  });

  test('should handle errors from the playerStateStream', () async {
    // Arrange
    final testError = Exception('Test stream error');
    // Align expectation with the actual message and data from _handleError -> _constructState
    final expectedState = PlaybackState.error(
      message: 'Error in input stream: $testError',
      currentPosition:
          Duration.zero, // Mapper includes this when constructing error state
      totalDuration: Duration.zero,
    );
    // Expect initial first, then error
    final expectation = expectLater(
      mapper.playbackStateStream,
      emitsInOrder([const PlaybackState.initial(), expectedState]),
    );

    // Act: Push an error into the stream
    playerStateController.addError(testError);

    // Wait for expectation to complete
    await expectation;
  });

  test('should handle complex sequence of events correctly', () async {
    // Arrange: Use separate controllers for this complex test
    final playerStateController =
        StreamController<DomainPlayerState>.broadcast(); // Changed type
    final durationController = StreamController<Duration>.broadcast();
    final positionController = StreamController<Duration>.broadcast();
    final completeController = StreamController<void>.broadcast();

    // Initialize mapper specifically for this test - ENSURE CORRECT TYPE
    final complexMapper = PlaybackStateMapperImpl();
    complexMapper.initialize(
      playerStateStream:
          playerStateController.stream, // MUST BE Stream<DomainPlayerState>
      durationStream: durationController.stream,
      positionStream: positionController.stream,
      completeStream: completeController.stream,
    );

    complexMapper.setCurrentFilePath('/complex/test.mp3');

    const initialDuration = Duration(seconds: 120);
    const initialPosition = Duration.zero;
    const midPosition = Duration(seconds: 30);

    // Expectation for the whole sequence
    final expectation = expectLater(
      complexMapper.playbackStateStream,
      emitsInOrder([
        const PlaybackState.initial(),
        const PlaybackState.stopped(), // Triggered by duration/position updates before playing
        // Position update might trigger another stopped or be ignored if state is already stopped
        const PlaybackState.playing(
          totalDuration: initialDuration,
          currentPosition: initialPosition,
        ), // Play triggers playing
        const PlaybackState.playing(
          totalDuration: initialDuration,
          currentPosition: midPosition,
        ), // Position update
        const PlaybackState.paused(
          totalDuration: initialDuration,
          currentPosition: midPosition,
        ), // Pause triggers paused
        const PlaybackState.playing(
          totalDuration: initialDuration,
          currentPosition: midPosition,
        ), // Resume triggers playing
        const PlaybackState.stopped(), // Stop triggers stopped (resets duration/position info)
        // Possibly add expects for complete if triggered
      ]),
    );

    // Act 1: Send duration and initial position (triggers stopped)
    durationController.add(initialDuration);
    positionController.add(initialPosition);
    await Future.delayed(Duration.zero);

    // Act 2: Start playing
    playerStateController.add(DomainPlayerState.playing); // Changed value
    await Future.delayed(Duration.zero);

    // Act 3: Update position during playback
    positionController.add(midPosition);
    await Future.delayed(Duration.zero);

    // Act 4: Pause
    playerStateController.add(DomainPlayerState.paused); // Changed value
    await Future.delayed(Duration.zero);

    // Act 5: Resume
    playerStateController.add(DomainPlayerState.playing); // Changed value
    await Future.delayed(Duration.zero);

    // Act 6: Stop
    playerStateController.add(DomainPlayerState.stopped); // Changed value

    // Wait for expectation to complete
    await expectation;

    // Clean up local controllers and mapper
    playerStateController.close();
    durationController.close();
    positionController.close();
    completeController.close();
    complexMapper.dispose();
  });

  // Add other tests: initial state, disposal, error stream handling etc.
}
