import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:docjet_mobile/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:logger/logger.dart'; // Keep this logger import

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
    try {
      // Set the file path in the mapper using the interface method
      _playbackStateMapper.setCurrentFilePath(filePath);

      // Set the audio source and resume playback
      await _audioPlayerAdapter.setSourceUrl(filePath);
      await _audioPlayerAdapter.resume();
    } catch (e) {
      // Error handling will be done by the mapper via error streams from adapter
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    await _audioPlayerAdapter.pause();
  }

  @override
  Future<void> resume() async {
    await _audioPlayerAdapter.resume();
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioPlayerAdapter.seek(position);
  }

  @override
  Future<void> stop() async {
    await _audioPlayerAdapter.stop();
  }

  @override
  Stream<PlaybackState> get playbackStateStream =>
      _playbackStateMapper.playbackStateStream;

  @override
  Future<void> dispose() async {
    await _audioPlayerAdapter.dispose();
    _playbackStateMapper.dispose();
  }
}
