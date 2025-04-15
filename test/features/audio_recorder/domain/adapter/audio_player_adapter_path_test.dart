import 'dart:async';

import 'package:docjet_mobile/core/platform/src/path_resolver.dart';
import 'package:docjet_mobile/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mockito/mockito.dart';

// Manual mocks with explicit implementations to avoid dynamic method issues
class MockAudioPlayer extends Mock implements AudioPlayer {
  final _playerStateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playbackEventController = StreamController<PlaybackEvent>.broadcast();

  String? lastSetFilePath;
  bool wasDisposeCalled = false;
  Duration? durationToReturn;

  void stubSetFilePath(Duration duration) {
    durationToReturn = duration;
  }

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream =>
      _playbackEventController.stream;

  @override
  PlayerState get playerState => PlayerState(false, ProcessingState.idle);

  @override
  bool get playing => false;

  @override
  ProcessingState get processingState => ProcessingState.idle;

  @override
  Future<Duration?> setFilePath(
    String path, {
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    // Track which path was passed in
    lastSetFilePath = path;
    return durationToReturn;
  }

  @override
  Future<void> dispose() async {
    wasDisposeCalled = true;
    await _playerStateController.close();
    await _positionController.close();
    await _durationController.close();
    await _playbackEventController.close();
    return Future.value();
  }
}

class MockPathResolver extends Mock implements PathResolver {
  String? resolvedPath;
  Exception? throwException;
  bool wasResolveCalledWithCorrectPath = false;

  void stubResolve(String path, String result) {
    resolvedPath = result;
  }

  void stubThrow(Exception exception) {
    throwException = exception;
  }

  @override
  Future<String> resolve(String inputPath, {bool mustExist = false}) async {
    // Track that resolve was called with the expected path
    if (resolvedPath != null && inputPath == 'audio/test.m4a') {
      wasResolveCalledWithCorrectPath = true;
    }

    if (throwException != null) {
      throw throwException!;
    }
    return resolvedPath ?? '/default/path/$inputPath';
  }
}

void main() {
  test(
    'AudioPlayerAdapter.getDuration uses PathResolver to resolve relative paths',
    () async {
      // ARRANGE
      final mockMainPlayer = MockAudioPlayer();
      final mockTempPlayer = MockAudioPlayer();
      final mockPathResolver = MockPathResolver();

      const relativePath = 'audio/test.m4a';
      const absolutePath = '/resolved/absolute/path/audio/test.m4a';
      const duration = Duration(seconds: 42);

      // Set up the path resolver
      mockPathResolver.stubResolve(relativePath, absolutePath);

      // Set up the temp player
      mockTempPlayer.stubSetFilePath(duration);

      // Factory to control which player is created
      AudioPlayer tempPlayerFactory() => mockTempPlayer;

      // Create adapter with our mocks
      final adapter = AudioPlayerAdapterImpl(
        mockMainPlayer,
        pathResolver: mockPathResolver,
        audioPlayerFactory: tempPlayerFactory,
      );

      // ACT
      final result = await adapter.getDuration(relativePath);

      // ASSERT
      expect(result, duration);

      // Check that the expected methods were called with the correct parameters
      expect(
        mockPathResolver.wasResolveCalledWithCorrectPath,
        isTrue,
        reason:
            'PathResolver.resolve should have been called with the relative path',
      );
      expect(
        mockTempPlayer.lastSetFilePath,
        equals(absolutePath),
        reason:
            'AudioPlayer.setFilePath should have been called with the absolute path',
      );
      expect(
        mockTempPlayer.wasDisposeCalled,
        isTrue,
        reason:
            'AudioPlayer.dispose should have been called to clean up resources',
      );
    },
  );
}
