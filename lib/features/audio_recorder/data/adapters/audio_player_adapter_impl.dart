import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';
// Import for Platform check if needed later, or Uri directly

// Using centralized logger with level OFF
// TEMPORARILY ENABLE DEBUG LOGGING FOR ADAPTER
final logger = Logger(level: Level.debug);

/// Concrete implementation of [AudioPlayerAdapter] using the `audioplayers` package.
class AudioPlayerAdapterImpl implements AudioPlayerAdapter {
  final audioplayers.AudioPlayer _audioPlayer;

  AudioPlayerAdapterImpl(this._audioPlayer);

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
  Stream<DomainPlayerState> get onPlayerStateChanged {
    // Map the audioplayers state stream to the DomainPlayerState enum stream.
    return _audioPlayer.onPlayerStateChanged.map((playerState) {
      switch (playerState) {
        case audioplayers.PlayerState.playing:
          return DomainPlayerState.playing;
        case audioplayers.PlayerState.paused:
          return DomainPlayerState.paused;
        case audioplayers.PlayerState.stopped:
          return DomainPlayerState.stopped;
        case audioplayers.PlayerState.completed:
          return DomainPlayerState.completed;
        // Map disposed state to initial. 'stopped' is handled above.
        case audioplayers.PlayerState.disposed:
          return DomainPlayerState.initial; // Or potentially stopped
        // Removed unreachable default and duplicate stopped case.
      }
      // REMOVED dead code: The switch is exhaustive.
      // logger.w('Reached end of switch in onPlayerStateChanged unexpectedly for $playerState, returning initial');
      // return DomainPlayerState.initial;
    });
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
      await _audioPlayer.setSource(audioplayers.UrlSource(pathOrUrl));
    } else {
      logger.d(
        'ADAPTER setSourceUrl: Detected as LOCAL PATH. Using DeviceFileSource.',
      );
      // Assume it's a local file path
      // Note: This assumes non-http/https URIs are file paths, which is generally safe
      // for our use case but could be refined further if file:// URIs are expected.
      await _audioPlayer.setSource(audioplayers.DeviceFileSource(pathOrUrl));
    }
    logger.d('ADAPTER setSourceUrl: setSource call complete.');
  }
}
