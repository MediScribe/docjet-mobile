import 'package:freezed_annotation/freezed_annotation.dart';

part 'playback_state.freezed.dart';

/// Represents the various states of audio playback, including relevant data.
@freezed
abstract class PlaybackState with _$PlaybackState {
  /// Initial state before any playback attempt.
  const factory PlaybackState.initial() = _Initial;

  /// State when the audio source is being loaded.
  const factory PlaybackState.loading() = _Loading;

  /// State when audio is actively playing.
  const factory PlaybackState.playing({
    required Duration currentPosition,
    required Duration totalDuration,
  }) = _Playing;

  /// State when audio playback is paused.
  const factory PlaybackState.paused({
    required Duration currentPosition,
    required Duration totalDuration,
  }) = _Paused;

  /// State when audio playback is stopped (explicitly or finished).
  const factory PlaybackState.stopped() = _Stopped;

  /// State when audio playback has completed normally.
  const factory PlaybackState.completed() = _Completed;

  /// State when an error occurs during playback or loading.
  const factory PlaybackState.error({
    required String message,
    Duration? currentPosition,
    Duration? totalDuration,
  }) = _Error;
}
