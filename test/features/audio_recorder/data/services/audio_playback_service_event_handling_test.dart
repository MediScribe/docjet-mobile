// Imports
import 'dart:async';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Create mock classes for dependencies
class MockAudioPlayerAdapter extends Mock implements AudioPlayerAdapter {}

class MockPlaybackStateMapper extends Mock implements PlaybackStateMapper {}

void main() {
  late MockAudioPlayerAdapter mockAdapter;
  late MockPlaybackStateMapper mockMapper;
  late AudioPlaybackServiceImpl service;
  late StreamController<PlaybackState> playbackStateController;

  setUp(() {
    mockAdapter = MockAudioPlayerAdapter();
    mockMapper = MockPlaybackStateMapper();
    playbackStateController = StreamController<PlaybackState>.broadcast();

    // Stub the playbackStateStream
    when(
      mockMapper.playbackStateStream,
    ).thenAnswer((_) => playbackStateController.stream);

    // Stub basic adapter methods
    when(
      mockAdapter.setSourceUrl('test/audio/file.mp3'),
    ).thenAnswer((_) async {});
    when(mockAdapter.resume()).thenAnswer((_) async {});
    when(mockAdapter.pause()).thenAnswer((_) async {});
    when(mockAdapter.seek(Duration.zero)).thenAnswer((_) async {});
    when(mockAdapter.stop()).thenAnswer((_) async {});
    when(mockAdapter.dispose()).thenAnswer((_) async {});

    // Instantiate service with mocked dependencies
    service = AudioPlaybackServiceImpl(
      audioPlayerAdapter: mockAdapter,
      playbackStateMapper: mockMapper,
    );
  });

  tearDown(() async {
    // Dispose the service first
    await service.dispose();
    // Close controllers
    await playbackStateController.close();
  });

  group('Event Handling', () {
    test('play() sets source and calls resume on adapter', () async {
      // Arrange
      const testPath = 'test/audio/file.mp3';

      // Act
      await service.play(testPath);

      // Assert
      verify(mockMapper.setCurrentFilePath(testPath)).called(1);
      verify(mockAdapter.setSourceUrl(testPath)).called(1);
      verify(mockAdapter.resume()).called(1);
    });

    test('playbackStateStream returns stream from mapper', () {
      // Act
      final resultStream = service.playbackStateStream;

      // Assert
      expect(resultStream, equals(playbackStateController.stream));
      verify(mockMapper.playbackStateStream).called(1);
    });
  });
}
