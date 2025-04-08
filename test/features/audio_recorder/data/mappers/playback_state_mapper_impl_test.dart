import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:docjet_mobile/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart'; // Implementation (will be created)
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
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
    () {
      // Arrange
      const initialDuration = Duration(seconds: 60);
      const initialPosition = Duration(seconds: 5);
      const expectedState = PlaybackState.playing(
        totalDuration: initialDuration,
        currentPosition: initialPosition,
      );

      // Act: Push initial duration and position (needed for Playing state)
      durationController.add(initialDuration);
      positionController.add(initialPosition);

      // Assert: Expect the Playing state *after* the playing event, skipping the initial state
      // We add the playing event *after* setting up the expectLater
      expectLater(mapper.playbackStateStream.skip(1), emits(expectedState));

      // Act: Push the playing event
      playerStateController.add(PlayerState.playing);
    },
  );

  // More mapper tests will go here
}
