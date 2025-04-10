import 'dart:async';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:docjet_mobile/core/utils/logger.dart';

/// Concrete implementation of [AudioPlaybackService] using the adapter and mapper pattern.
/// This service orchestrates the interactions between the [AudioPlayerAdapter] and
/// [PlaybackStateMapper] to provide a clean, testable audio playback service.
class AudioPlaybackServiceImpl implements AudioPlaybackService {
  final AudioPlayerAdapter _audioPlayerAdapter;
  final PlaybackStateMapper _playbackStateMapper;

  /// Creates an instance of [AudioPlaybackServiceImpl].
  ///
  /// Requires an [AudioPlayerAdapter] and [PlaybackStateMapper] to be injected.
  AudioPlaybackServiceImpl({
    required AudioPlayerAdapter audioPlayerAdapter,
    required PlaybackStateMapper playbackStateMapper,
  }) : _audioPlayerAdapter = audioPlayerAdapter,
       _playbackStateMapper = playbackStateMapper {
    // Initialize the mapper with adapter streams
    _playbackStateMapper.initialize(
      positionStream: _audioPlayerAdapter.onPositionChanged,
      durationStream: _audioPlayerAdapter.onDurationChanged,
      completeStream: _audioPlayerAdapter.onPlayerComplete,
      playerStateStream: _audioPlayerAdapter.onPlayerStateChanged,
    );
  }

  @override
  Future<void> play(String filePath) async {
    logger.d('SERVICE PLAY [$filePath]: START');
    try {
      // Stop any previous playback before starting new
      logger.d('SERVICE PLAY [$filePath]: Calling stop...');
      await _audioPlayerAdapter.stop();
      logger.d('SERVICE PLAY [$filePath]: Stop complete.');

      // Set the file path in the mapper using the interface method
      logger.d('SERVICE PLAY [$filePath]: Setting mapper path...');
      _playbackStateMapper.setCurrentFilePath(filePath);
      logger.d('SERVICE PLAY [$filePath]: Mapper path set.');

      // Set the audio source and resume playback
      logger.d('SERVICE PLAY [$filePath]: Calling setSourceUrl...');
      await _audioPlayerAdapter.setSourceUrl(filePath);
      logger.d('SERVICE PLAY [$filePath]: setSourceUrl complete.');

      logger.d('SERVICE PLAY [$filePath]: Calling resume...');
      await _audioPlayerAdapter.resume();
      logger.d('SERVICE PLAY [$filePath]: Resume complete.');

      logger.d('SERVICE PLAY [$filePath]: END (Success)');
    } catch (e) {
      logger.e('SERVICE PLAY [$filePath]: ERROR - $e');
      // Error handling will be done by the mapper via error streams from adapter
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    logger.d('SERVICE PAUSE: Calling adapter.pause()');
    await _audioPlayerAdapter.pause();
    logger.d('SERVICE PAUSE: Complete');
  }

  @override
  Future<void> resume() async {
    logger.d('SERVICE RESUME: Calling adapter.resume()');
    await _audioPlayerAdapter.resume();
    logger.d('SERVICE RESUME: Complete');
  }

  @override
  Future<void> seek(Duration position) async {
    logger.d(
      'SERVICE SEEK: Calling adapter.seek(${position.inMilliseconds}ms)',
    );
    await _audioPlayerAdapter.seek(position);
    logger.d('SERVICE SEEK: Complete');
  }

  @override
  Future<void> stop() async {
    logger.d('SERVICE STOP: Calling adapter.stop()');
    await _audioPlayerAdapter.stop();
    logger.d('SERVICE STOP: Complete');
  }

  @override
  Stream<PlaybackState> get playbackStateStream =>
      _playbackStateMapper.playbackStateStream;

  @override
  Future<void> dispose() async {
    logger.d('SERVICE DISPOSE: Starting');
    await _audioPlayerAdapter.dispose();
    _playbackStateMapper.dispose();
    logger.d('SERVICE DISPOSE: Complete');
  }
}
