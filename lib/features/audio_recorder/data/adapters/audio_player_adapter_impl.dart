import 'package:audioplayers/audioplayers.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/core/utils/logger.dart';
import 'dart:io'; // Import for Platform check if needed later, or Uri directly

// Using centralized logger with level OFF
// TEMPORARILY ENABLE DEBUG LOGGING FOR ADAPTER
final logger = Logger(level: Level.debug);

/// Concrete implementation of [AudioPlayerAdapter] using the `audioplayers` package.
class AudioPlayerAdapterImpl implements AudioPlayerAdapter {
  final AudioPlayer _audioPlayer;

  AudioPlayerAdapterImpl(this._audioPlayer);

  @override
  Future<void> play(String filePath) async {
    // Delegate to the actual player
    await _audioPlayer.play(DeviceFileSource(filePath));
  }

  @override
  Future<void> pause() {
    // Delegate to the actual player
    return _audioPlayer.pause();
  }

  @override
  Future<void> resume() {
    // Delegate to the actual player
    return _audioPlayer.resume();
  }

  @override
  Future<void> seek(Duration position) {
    // Delegate to the actual player
    return _audioPlayer.seek(position);
  }

  @override
  Future<void> stop() {
    // Delegate to the actual player
    return _audioPlayer.stop();
  }

  @override
  Future<void> dispose() async {
    // Delegate release and dispose in order
    await _audioPlayer.release();
    await _audioPlayer.dispose();
  }

  @override
  Stream<PlayerState> get onPlayerStateChanged {
    // Expose the player's stream directly
    return _audioPlayer.onPlayerStateChanged;
  }

  @override
  Stream<Duration> get onDurationChanged {
    // Expose the player's stream directly
    return _audioPlayer.onDurationChanged;
  }

  @override
  Stream<Duration> get onPositionChanged {
    // Expose the player's stream directly
    return _audioPlayer.onPositionChanged;
  }

  @override
  Stream<void> get onPlayerComplete {
    // Expose the player's stream directly
    return _audioPlayer.onPlayerComplete;
  }

  @override
  Future<void> setSourceUrl(String pathOrUrl) async {
    logger.d('ADAPTER setSourceUrl: Received pathOrUrl: [$pathOrUrl]');
    // Use Uri.tryParse to determine if it's a URL scheme we recognize
    final uri = Uri.tryParse(pathOrUrl);
    final bool isNetworkUrl =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    if (isNetworkUrl) {
      logger.d(
        'ADAPTER setSourceUrl: Detected as NETWORK URL. Using UrlSource.',
      );
      // It's a URL
      await _audioPlayer.setSource(UrlSource(pathOrUrl));
    } else {
      logger.d(
        'ADAPTER setSourceUrl: Detected as LOCAL PATH. Using DeviceFileSource.',
      );
      // Assume it's a local file path
      // Note: This assumes non-http/https URIs are file paths, which is generally safe
      // for our use case but could be refined further if file:// URIs are expected.
      await _audioPlayer.setSource(DeviceFileSource(pathOrUrl));
    }
    logger.d('ADAPTER setSourceUrl: setSource call complete.');
  }
}
