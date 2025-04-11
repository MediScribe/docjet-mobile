import 'dart:async';

// import 'package:audioplayers/audioplayers.dart' as audioplayers; // REMOVED
// import 'package:just_audio/just_audio.dart'; // REMOVED
import 'package:just_audio/just_audio.dart'; // REMOVED ALIAS
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';
// Import for Platform check if needed later, or Uri directly

// RE-ENABLE DEBUG LOGGING FOR ADAPTER
final logger = Logger(level: Level.debug);

/// Concrete implementation of [AudioPlayerAdapter] using the `just_audio` package.
class AudioPlayerAdapterImpl implements AudioPlayerAdapter {
  final AudioPlayer _audioPlayer; // REMOVED ALIAS

  // Keep track of the last known state to help with mapping
  // PlayerState _lastPlayerState = PlayerState( // REMOVED - Unused field
  //   false, // playing: bool FIRST
  //   ProcessingState.idle,
  // );

  // Constructor no longer needs to listen immediately
  AudioPlayerAdapterImpl(this._audioPlayer);

  @override
  Future<void> pause() async {
    logger.d('Adapter: pause() called');
    logger.d('Adapter pause() called by:\n${StackTrace.current}');
    await _audioPlayer.pause();
    // Add logging right after pause is called
    logger.d(
      'Adapter: pause operation completed. Current player state: ${_audioPlayer.playerState}',
    );
    logger.d(
      'Adapter: is playing: ${_audioPlayer.playing}, processingState: ${_audioPlayer.processingState}',
    );
    return;
  }

  @override
  Future<void> resume() {
    // just_audio uses play() to resume
    logger.d('Adapter: resume() called (delegating to play())');
    return _audioPlayer.play();
  }

  @override
  Future<void> seek(Duration position) {
    logger.d('Adapter: seek() called with position: $position');
    return _audioPlayer.seek(position);
  }

  @override
  Future<void> stop() {
    logger.d('Adapter: stop() called');
    logger.d('Adapter stop() called by:\n${StackTrace.current}');
    return _audioPlayer.stop();
  }

  @override
  Future<void> dispose() async {
    logger.d('Adapter: dispose() called');
    // just_audio only has dispose(), no release()
    await _audioPlayer.dispose();
  }

  @override
  Stream<DomainPlayerState> get onPlayerStateChanged {
    logger.d('Adapter: onPlayerStateChanged stream requested');
    // Map just_audio's PlayerState (ProcessingState + playing bool) to DomainPlayerState
    return _audioPlayer.playerStateStream
        .map((state) {
          logger.d(
            'ADAPTER_INPUT: just_audio PlayerState: ${state.processingState}, playing: ${state.playing}',
          );
          switch (state.processingState) {
            case ProcessingState.idle: // REMOVED ALIAS
              // Idle usually means stopped or initial
              return DomainPlayerState.stopped;
            case ProcessingState.loading: // REMOVED ALIAS
              return DomainPlayerState.loading;
            case ProcessingState.buffering: // REMOVED ALIAS
              // Treat buffering as a loading state from the domain perspective
              return DomainPlayerState.loading;
            case ProcessingState.ready: // REMOVED ALIAS
              // Ready means it can play. Check the playing flag.
              return state.playing
                  ? DomainPlayerState.playing
                  : DomainPlayerState.paused;
            case ProcessingState.completed: // REMOVED ALIAS
              return DomainPlayerState.completed;
          }
        })
        .handleError((error) {
          // Optional: Map specific player errors to a domain error state
          logger.e('Error in playerStateStream: $error');
          return DomainPlayerState.error;
        })
        .distinct(); // Avoid emitting consecutive identical states
  }

  @override
  Stream<Duration> get onDurationChanged {
    logger.d('Adapter: onDurationChanged stream requested');
    return _audioPlayer.durationStream
        .map((d) {
          // logger.d('ADAPTER_INPUT: just_audio Duration: ${d?.inMilliseconds}ms'); // <<< COMMENT OUT
          return d;
        })
        .where((d) => d != null)
        .cast<Duration>();
  }

  @override
  Stream<Duration> get onPositionChanged {
    logger.d('Adapter: onPositionChanged stream requested');
    // Expose the player's stream directly
    return _audioPlayer.positionStream.map((pos) {
      // logger.d('ADAPTER_INPUT: just_audio Position: ${pos.inMilliseconds}ms'); // <<< COMMENT OUT
      return pos;
    });
  }

  @override
  Stream<void> get onPlayerComplete {
    logger.d('Adapter: onPlayerComplete stream requested');
    // Filter the playerStateStream for the completed state and map to void.
    return _audioPlayer.playerStateStream
        .where((state) {
          final completed = state.processingState == ProcessingState.completed;
          if (completed) {
            logger.d('ADAPTER_INPUT: just_audio PlayerState completed');
          }
          return completed;
        })
        .map((_) {}); // Map to an empty expression block for void
  }

  @override
  Future<void> setSourceUrl(String pathOrUrl) async {
    logger.d('ADAPTER setSourceUrl: Received pathOrUrl: [$pathOrUrl]');
    try {
      final uri = Uri.parse(pathOrUrl);
      final bool isNetworkUrl = (uri.scheme == 'http' || uri.scheme == 'https');

      AudioSource source; // REMOVED ALIAS
      if (isNetworkUrl) {
        logger.d('ADAPTER setSourceUrl: Detected as NETWORK URL.');
        source = AudioSource.uri(uri); // REMOVED ALIAS
      } else {
        logger.d(
          'ADAPTER setSourceUrl: Detected as LOCAL PATH (assuming file scheme).',
        );
        // Ensure it's treated as a file URI, even if scheme is missing
        source = AudioSource.uri(
          // REMOVED ALIAS
          Uri.file(pathOrUrl),
        );
      }

      logger.d('ADAPTER setSourceUrl: Calling _audioPlayer.setAudioSource');
      // setAudioSource returns nullable duration, but our interface is void.
      await _audioPlayer.setAudioSource(source);
      logger.d('ADAPTER setSourceUrl: setAudioSource call complete.');
    } catch (e, stackTrace) {
      logger.e('ADAPTER Error in setSourceUrl: $e\n$stackTrace');
      // Rethrow or handle as appropriate for the application
      // Consider wrapping in a domain-specific exception
      rethrow;
    }
  }
}
