import 'dart:async';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'audio_playback_service_orchestration_test.mocks.dart';

// Set Logger Level to DEBUG for active development/debugging in this file
final logger = LoggerFactory.getLogger(
  'AudioPlaybackServiceOrchestrationTest',
  level: Level.debug,
);

@GenerateMocks([AudioPlayerAdapter, PlaybackStateMapper])
void main() {
  // Set SUT logger to debug level for testing
  LoggerFactory.setLogLevel(AudioPlaybackServiceImpl, Level.debug);

  group('AudioPlaybackServiceImpl Orchestration', () {
    late MockAudioPlayerAdapter mockAdapter;
    late MockPlaybackStateMapper mockMapper;
    late AudioPlaybackServiceImpl service;
    late StreamController<PlaybackState> mapperStateController;

    setUp(() {
      mockAdapter = MockAudioPlayerAdapter();
      mockMapper = MockPlaybackStateMapper();
      mapperStateController = StreamController<PlaybackState>.broadcast();

      when(
        mockMapper.playbackStateStream,
      ).thenAnswer((_) => mapperStateController.stream);

      when(mockAdapter.stop()).thenAnswer((_) async {});
      when(mockAdapter.setSourceUrl(any)).thenAnswer((_) async {});
      when(mockAdapter.resume()).thenAnswer((_) async {});
      when(mockAdapter.pause()).thenAnswer((_) async {});
      when(mockAdapter.seek(any, any)).thenAnswer((_) async {});
      when(mockAdapter.dispose()).thenAnswer((_) async {});

      when(mockMapper.dispose()).thenReturn(null);

      service = AudioPlaybackServiceImpl(
        audioPlayerAdapter: mockAdapter,
        playbackStateMapper: mockMapper,
      );
    });

    tearDown(() async {
      await service.dispose();
      await mapperStateController.close();
    });

    test(
      'initial play() should call stop, setSource, resume, setCurrentFilePath',
      () async {
        const testFilePath = 'test/file/path.mp3';
        mapperStateController.add(const PlaybackState.initial());
        await Future.delayed(Duration.zero);

        await service.play(testFilePath);

        verify(mockAdapter.stop()).called(1);
        verify(mockAdapter.setSourceUrl(testFilePath)).called(1);
        verify(mockAdapter.resume()).called(1);
      },
    );

    test('play() on paused file should ONLY call resume()', () async {
      const testFilePath = 'test/file/path.mp3';
      const pausedState = PlaybackState.paused(
        currentPosition: Duration(seconds: 10),
        totalDuration: Duration(seconds: 30),
      );

      // First play to set initial state and _currentFilePath
      await service.play(testFilePath);
      mapperStateController.add(pausedState); // Simulate paused state
      await Future.delayed(Duration.zero);

      // Clear interactions from the initial setup
      clearInteractions(mockAdapter);
      clearInteractions(mockMapper);

      // Set up expectations ONLY for resume
      when(mockAdapter.resume()).thenAnswer((_) async {});

      // Play the same file again while paused
      await service.play(testFilePath);

      // Verify ONLY resume was called
      verify(mockAdapter.resume()).called(1);
      verifyNever(mockAdapter.stop());
      verifyNever(mockAdapter.setSourceUrl(any));
    });

    test('pause() should call adapter.pause()', () async {
      await service.pause();

      verify(mockAdapter.pause()).called(1);
    });

    test('seek() should call adapter.seek() with internally stored path', () async {
      const testFilePath = 'test/seek/path.mp3'; // Path to be stored internally
      const testPosition = Duration(seconds: 10);

      // Arrange: Play a file first to set the internal state (_currentFilePath)
      await service.play(testFilePath);

      // Arrange: Reset interactions from the 'play' call
      clearInteractions(mockAdapter);

      // Arrange: Ensure the adapter mock expects two arguments for seek
      when(mockAdapter.seek(any, any)).thenAnswer((_) async {});

      // Act: Call service seek with BOTH the path and position
      await service.seek(testFilePath, testPosition);

      // Assert: Verify the adapter was called with the path from 'play' and the position
      verify(mockAdapter.seek(testFilePath, testPosition)).called(1);
    });

    test('stop() should call adapter.stop()', () async {
      await service.stop();

      verify(mockAdapter.stop()).called(1);
    });

    test(
      'dispose() should call adapter.dispose() and mapper.dispose()',
      () async {
        await service.dispose();

        verify(mockAdapter.dispose()).called(1);
        verify(mockMapper.dispose()).called(1);
      },
    );

    test('playbackStateStream should return the service\'s stream', () {
      expect(service.playbackStateStream, isNotNull);
      expect(service.playbackStateStream, isA<Stream<PlaybackState>>());

      const testState = PlaybackState.loading();
      expectLater(service.playbackStateStream, emits(testState));
      mapperStateController.add(testState);
    });
  });
}
