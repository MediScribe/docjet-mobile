// Imports
import 'dart:async';

import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'audio_playback_service_event_handling_test.mocks.dart';

// Set Logger Level to DEBUG for active development/debugging in this file
final logger = LoggerFactory.getLogger(
  'AudioPlaybackServiceEventHandlingTest',
  level: Level.debug,
);

// Generate mock classes
@GenerateMocks([AudioPlayerAdapter, PlaybackStateMapper])
void main() {
  // Set SUT logger to debug level for testing
  LoggerFactory.setLogLevel(AudioPlaybackServiceImpl, Level.debug);

  late MockAudioPlayerAdapter mockAudioPlayerAdapter;
  late MockPlaybackStateMapper mockPlaybackStateMapper;
  late AudioPlaybackServiceImpl service;
  late StreamController<PlaybackState> playbackStateController;

  setUp(() {
    logger.d('EVENT_HANDLING_TEST_SETUP: Starting');
    mockAudioPlayerAdapter = MockAudioPlayerAdapter();
    mockPlaybackStateMapper = MockPlaybackStateMapper();
    playbackStateController = StreamController<PlaybackState>.broadcast();

    // Setup the streams needed by the mapper
    when(
      mockAudioPlayerAdapter.onPositionChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(
      mockAudioPlayerAdapter.onDurationChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(
      mockAudioPlayerAdapter.onPlayerComplete,
    ).thenAnswer((_) => const Stream.empty());
    when(
      mockAudioPlayerAdapter.onPlayerStateChanged,
    ).thenAnswer((_) => const Stream.empty());

    // Setup the playback state stream
    when(
      mockPlaybackStateMapper.playbackStateStream,
    ).thenAnswer((_) => playbackStateController.stream);

    service = AudioPlaybackServiceImpl(
      audioPlayerAdapter: mockAudioPlayerAdapter,
      playbackStateMapper: mockPlaybackStateMapper,
    );
    logger.d('EVENT_HANDLING_TEST_SETUP: Complete');
  });

  tearDown(() async {
    logger.d('EVENT_HANDLING_TEST_TEARDOWN: Starting');
    await service.dispose();
    await playbackStateController.close();
    logger.d('EVENT_HANDLING_TEST_TEARDOWN: Complete');
  });

  group('audioPlaybackService event handling -', () {
    test('should delegate mapper events through playbackStateStream', () async {
      logger.d('TEST [delegate events]: Starting');
      // Arrange
      const expectedState = PlaybackState.playing(
        currentPosition: Duration(seconds: 10),
        totalDuration: Duration(minutes: 2),
      );

      // Act & Assert
      final expectation = expectLater(
        service.playbackStateStream,
        emits(expectedState),
      );

      // Simulate the mapper emitting a state
      playbackStateController.add(expectedState);

      // Wait for the expectation to complete
      await expectation;
      logger.d('TEST [delegate events]: Complete');
    });
  });
}
