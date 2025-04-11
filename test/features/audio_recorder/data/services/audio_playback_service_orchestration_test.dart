import 'dart:async';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/utils/logger.dart';

import 'audio_playback_service_orchestration_test.mocks.dart';

@GenerateMocks([AudioPlayerAdapter, PlaybackStateMapper])
void main() {
  setLogLevel(Level.off);

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
      when(mockAdapter.seek(any)).thenAnswer((_) async {});
      when(mockAdapter.dispose()).thenAnswer((_) async {});

      when(mockMapper.setCurrentFilePath(any)).thenReturn(null);
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
        verify(mockMapper.setCurrentFilePath(testFilePath)).called(1);
      },
    );

    test(
      'play() on paused file should restart with stop, setSourceUrl, resume',
      () async {
        const testFilePath = 'test/file/path.mp3';
        const pausedState = PlaybackState.paused(
          currentPosition: Duration(seconds: 10),
          totalDuration: Duration(seconds: 30),
        );

        // First play to set initial state
        await service.play(testFilePath);
        mapperStateController.add(pausedState);
        await Future.delayed(Duration.zero);

        // Clear interactions from the initial setup
        clearInteractions(mockAdapter);
        clearInteractions(mockMapper);

        // Set up expectations for next play call
        when(mockAdapter.stop()).thenAnswer((_) async {});
        when(mockAdapter.setSourceUrl(testFilePath)).thenAnswer((_) async {});
        when(mockAdapter.resume()).thenAnswer((_) async {});

        // Play the same file again
        await service.play(testFilePath);

        // Verify we properly restart playback
        verify(mockAdapter.stop()).called(1);
        verify(mockAdapter.setSourceUrl(testFilePath)).called(1);
        verify(mockAdapter.resume()).called(1);

        // We should NOT call setCurrentFilePath for the same file
        verifyNever(mockMapper.setCurrentFilePath(any));
      },
    );

    test('pause() should call adapter.pause()', () async {
      await service.pause();

      verify(mockAdapter.pause()).called(1);
    });

    test('seek() should call adapter.seek()', () async {
      const testPosition = Duration(seconds: 10);

      await service.seek(testPosition);

      verify(mockAdapter.seek(testPosition)).called(1);
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
