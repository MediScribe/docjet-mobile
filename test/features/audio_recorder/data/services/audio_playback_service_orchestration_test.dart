import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'audio_playback_service_orchestration_test.mocks.dart';

export 'package:flutter/foundation.dart';

@GenerateMocks([AudioPlayerAdapter, PlaybackStateMapper])
void main() {
  group('AudioPlaybackServiceImpl Orchestration', () {
    late MockAudioPlayerAdapter mockAdapter;
    late MockPlaybackStateMapper mockMapper;
    late AudioPlaybackServiceImpl service;

    setUp(() {
      mockAdapter = MockAudioPlayerAdapter();
      mockMapper = MockPlaybackStateMapper();

      // Mock adapter streams
      final positionStream = Stream<Duration>.value(Duration.zero);
      final durationStream = Stream<Duration>.value(Duration.zero);
      final completeStream = Stream<void>.value(null);
      final playerStateStream = Stream<DomainPlayerState>.value(
        DomainPlayerState.stopped,
      );

      when(mockAdapter.onPositionChanged).thenAnswer((_) => positionStream);
      when(mockAdapter.onDurationChanged).thenAnswer((_) => durationStream);
      when(mockAdapter.onPlayerComplete).thenAnswer((_) => completeStream);
      when(
        mockAdapter.onPlayerStateChanged,
      ).thenAnswer((_) => playerStateStream);

      // Mock mapper stream
      final testMapperOutputStream = Stream<PlaybackState>.value(
        const PlaybackState.initial(),
      );
      when(
        mockMapper.playbackStateStream,
      ).thenAnswer((_) => testMapperOutputStream);

      // Mock the initialize call on the mapper
      when(
        mockMapper.initialize(
          positionStream: anyNamed('positionStream'),
          durationStream: anyNamed('durationStream'),
          completeStream: anyNamed('completeStream'),
          playerStateStream: anyNamed('playerStateStream'),
        ),
      ).thenReturn(null);

      service = AudioPlaybackServiceImpl(
        audioPlayerAdapter: mockAdapter,
        playbackStateMapper: mockMapper,
      );

      verify(
        mockMapper.initialize(
          positionStream: positionStream,
          durationStream: durationStream,
          completeStream: completeStream,
          playerStateStream: playerStateStream,
        ),
      ).called(1);
    });

    tearDown(() async {
      await service.dispose();
    });

    test('play() should call setSource and resume on adapter', () async {
      // Arrange
      const testFilePath = 'test/file/path.mp3';
      when(mockAdapter.setSourceUrl(any)).thenAnswer((_) => Future.value());
      when(mockAdapter.resume()).thenAnswer((_) => Future.value());

      // Act
      await service.play(testFilePath);

      // Assert
      verify(mockAdapter.setSourceUrl(testFilePath)).called(1);
      verify(mockAdapter.resume()).called(1);
      verify(mockMapper.setCurrentFilePath(testFilePath)).called(1);
    });

    test('pause() should call adapter.pause()', () async {
      // Arrange
      when(mockAdapter.pause()).thenAnswer((_) => Future.value());

      // Act
      await service.pause();

      // Assert
      verify(mockAdapter.pause()).called(1);
    });

    test('seek() should call adapter.seek()', () async {
      // Arrange
      final testPosition = Duration(seconds: 10);
      when(mockAdapter.seek(any)).thenAnswer((_) => Future.value());

      // Act
      await service.seek(testPosition);

      // Assert
      verify(mockAdapter.seek(testPosition)).called(1);
    });

    test('stop() should call adapter.stop()', () async {
      // Arrange
      when(mockAdapter.stop()).thenAnswer((_) => Future.value());

      // Act
      await service.stop();

      // Assert
      verify(mockAdapter.stop()).called(1);
    });

    test('dispose() should call adapter.dispose()', () async {
      // Arrange
      when(mockAdapter.dispose()).thenAnswer((_) => Future.value());

      // Act
      await service.dispose();

      // Assert
      verify(mockAdapter.dispose()).called(1);
      verify(mockMapper.dispose()).called(1);
    });

    test('playbackStateStream should return mapper.playbackStateStream', () {
      // Arrange
      final testMapperOutputStream = Stream<PlaybackState>.value(
        const PlaybackState.initial(),
      );
      when(
        mockMapper.playbackStateStream,
      ).thenAnswer((_) => testMapperOutputStream);

      // Act & Assert
      expect(service.playbackStateStream, equals(testMapperOutputStream));
    });
  });
}
