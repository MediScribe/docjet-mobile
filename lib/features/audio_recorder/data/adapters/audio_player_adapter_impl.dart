import 'dart:async';

// import 'package:audioplayers/audioplayers.dart' as audioplayers; // REMOVED
// import 'package:just_audio/just_audio.dart'; // REMOVED
import 'package:just_audio/just_audio.dart'; // REMOVED ALIAS
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';
// Import for Platform check if needed later, or Uri directly

// Set Logger Level HIGH to silence most logs by default
final logger = Logger(level: Level.warning);

/// Concrete implementation of [AudioPlayerAdapter] using the `just_audio` package.
class AudioPlayerAdapterImpl implements AudioPlayerAdapter {
  final AudioPlayer _audioPlayer; // REMOVED ALIAS

  // Keep track of the last known state to help with mapping
  // PlayerState _lastPlayerState = PlayerState( // REMOVED - Unused field
  //   false, // playing: bool FIRST
  //   ProcessingState.idle,
  // );

  // Constructor no longer needs to listen immediately
  AudioPlayerAdapterImpl(this._audioPlayer) {
    logger.d('[ADAPTER_INIT] Creating AudioPlayerAdapterImpl instance.');
    // Log player state changes immediately upon creation for debugging
    _audioPlayer.playerStateStream.listen(
      (state) {
        // TEMPORARY FLICKER DEBUG - COMMENTED OUT
        // logger.d(
        //   '[ADAPTER_RAW_STATE] Time: ${DateTime.now().millisecondsSinceEpoch}ms - State: ${state.processingState}, playing: ${state.playing}',
        // );
      },
      onError: (e, s) {
        logger.e(
          '[ADAPTER_INTERNAL] Error in playerStateStream',
          error: e,
          stackTrace: s,
        );
      },
    );
    _audioPlayer.positionStream.listen(
      (pos) {
        // TEMPORARY FLICKER DEBUG - COMMENTED OUT DUE TO SPAM
        // logger.d(
        //   '[ADAPTER_RAW_POS] Time: ${DateTime.now().millisecondsSinceEpoch}ms - Position: ${pos.inMilliseconds}ms',
        // );
        // COMMENT OUT HIGH-FREQUENCY POSITION LOG
        // logger.d('[ADAPTER_INTERNAL] Position changed: ${pos.inMilliseconds}ms');
      },
      onError: (e, s) {
        logger.e(
          '[ADAPTER_INTERNAL] Error in positionStream',
          error: e,
          stackTrace: s,
        );
      },
    );
    _audioPlayer.durationStream.listen(
      (dur) {
        // TEMPORARY FLICKER DEBUG - COMMENTED OUT
        // logger.d(
        //   '[ADAPTER_RAW_DUR] Time: ${DateTime.now().millisecondsSinceEpoch}ms - Duration: ${dur?.inMilliseconds}ms',
        // );
      },
      onError: (e, s) {
        logger.e(
          '[ADAPTER_INTERNAL] Error in durationStream',
          error: e,
          stackTrace: s,
        );
      },
    );
  }

  @override
  Future<void> pause() async {
    final trace = StackTrace.current;
    logger.d('[ADAPTER PAUSE] START', stackTrace: trace);
    try {
      await _audioPlayer.pause();
      logger.d(
        '[ADAPTER PAUSE] Call complete. Current state: playing=${_audioPlayer.playing}, processing=${_audioPlayer.processingState}',
      );
    } catch (e, s) {
      logger.e('[ADAPTER PAUSE] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[ADAPTER PAUSE] END');
  }

  @override
  Future<void> resume() async {
    // Changed return type to Future<void> for consistency with async
    final trace = StackTrace.current;
    // just_audio uses play() to resume
    logger.d(
      '[ADAPTER RESUME] START (delegating to play())',
      stackTrace: trace,
    );
    try {
      await _audioPlayer.play();
      logger.d('[ADAPTER RESUME] play() call complete.');
    } catch (e, s) {
      logger.e('[ADAPTER RESUME] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[ADAPTER RESUME] END');
    // Since play() returns Future<void>, we don't need to return explicitly
  }

  @override
  Future<void> seek(Duration position) async {
    final trace = StackTrace.current;
    logger.d(
      '[ADAPTER SEEK ${position.inMilliseconds}ms] START',
      stackTrace: trace,
    );
    try {
      await _audioPlayer.seek(position);
      logger.d('[ADAPTER SEEK] Call complete.');
    } catch (e, s) {
      logger.e('[ADAPTER SEEK] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[ADAPTER SEEK ${position.inMilliseconds}ms] END');
  }

  @override
  Future<void> stop() async {
    final trace = StackTrace.current;
    logger.d('[ADAPTER STOP] START', stackTrace: trace);
    try {
      await _audioPlayer.stop();
      logger.d('[ADAPTER STOP] Call complete.');
    } catch (e, s) {
      logger.e('[ADAPTER STOP] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[ADAPTER STOP] END');
  }

  @override
  Future<void> dispose() async {
    logger.d('[ADAPTER DISPOSE] START');
    // just_audio only has dispose(), no release()
    try {
      await _audioPlayer.dispose();
      logger.d('[ADAPTER DISPOSE] Call complete.');
    } catch (e, s) {
      logger.e('[ADAPTER DISPOSE] FAILED', error: e, stackTrace: s);
      // Decide if rethrow is appropriate
    }
    logger.d('[ADAPTER DISPOSE] END');
  }

  @override
  Stream<DomainPlayerState> get onPlayerStateChanged {
    logger.d('[ADAPTER STREAM] onPlayerStateChanged accessed');
    // Map just_audio's PlayerState (ProcessingState + playing bool) to DomainPlayerState
    return _audioPlayer.playerStateStream
        .map((state) {
          logger.d(
            '[ADAPTER STREAM MAP] Input PlayerState: processing=${state.processingState}, playing=${state.playing}',
          );
          DomainPlayerState domainState;
          switch (state.processingState) {
            case ProcessingState.idle: // REMOVED ALIAS
              // Idle usually means stopped or initial
              domainState = DomainPlayerState.stopped;
              break;
            case ProcessingState.loading: // REMOVED ALIAS
              domainState = DomainPlayerState.loading;
              break;
            case ProcessingState.buffering: // REMOVED ALIAS
              // Treat buffering as a loading state from the domain perspective
              domainState = DomainPlayerState.loading;
              break;
            case ProcessingState.ready: // REMOVED ALIAS
              // Ready means it can play. Check the playing flag.
              domainState =
                  state.playing
                      ? DomainPlayerState.playing
                      : DomainPlayerState.paused;
              break;
            case ProcessingState.completed: // REMOVED ALIAS
              domainState = DomainPlayerState.completed;
              break;
          }
          // COMMENT OUT VERBOSE LOG
          // logger.d(
          //   '[ADAPTER STREAM MAP] Output DomainPlayerState: $domainState',
          // );
          return domainState;
        })
        .handleError((error, stackTrace) {
          logger.e(
            '[ADAPTER STREAM] Error in playerStateStream',
            error: error,
            stackTrace: stackTrace,
          );
          // Map specific player errors to a domain error state or rethrow
          // For now, just logging and letting the stream emit the error.
          // Consider emitting DomainPlayerState.error here if needed.
          throw error; // Rethrow to propagate the error
        })
        .distinct(); // Avoid emitting consecutive identical states
  }

  @override
  Stream<Duration> get onDurationChanged {
    logger.d('[ADAPTER STREAM] onDurationChanged accessed');
    return _audioPlayer.durationStream
        .map((d) {
          // logger.d('[ADAPTER STREAM MAP] Input Duration: ${d?.inMilliseconds}ms'); // Keep commented
          return d;
        })
        .where((d) => d != null)
        .cast<Duration>()
        .handleError((error, stackTrace) {
          logger.e(
            '[ADAPTER STREAM] Error in durationStream',
            error: error,
            stackTrace: stackTrace,
          );
          throw error;
        });
  }

  @override
  Stream<Duration> get onPositionChanged {
    logger.d('[ADAPTER STREAM] onPositionChanged accessed');
    return _audioPlayer.positionStream
        .map((pos) {
          // logger.d('[ADAPTER STREAM MAP] Input Position: ${pos.inMilliseconds}ms'); // Keep commented
          return pos;
        })
        .handleError((error, stackTrace) {
          logger.e(
            '[ADAPTER STREAM] Error in positionStream',
            error: error,
            stackTrace: stackTrace,
          );
          throw error;
        });
  }

  @override
  Stream<void> get onPlayerComplete {
    logger.d('[ADAPTER STREAM] onPlayerComplete accessed');
    return _audioPlayer.playerStateStream
        .where((state) {
          final completed = state.processingState == ProcessingState.completed;
          if (completed) {
            logger.d('[ADAPTER STREAM FILTER] PlayerState completed detected.');
          }
          return completed;
        })
        .map((_) {
          logger.d(
            '[ADAPTER STREAM MAP] Mapping completed state to void event.',
          );
          return;
        })
        .handleError((error, stackTrace) {
          logger.e(
            '[ADAPTER STREAM] Error in onPlayerComplete stream logic',
            error: error,
            stackTrace: stackTrace,
          );
          throw error;
        });
  }

  @override
  Future<void> setSourceUrl(String pathOrUrl) async {
    final trace = StackTrace.current;
    logger.d('[ADAPTER SET_SOURCE $pathOrUrl] START', stackTrace: trace);
    try {
      final uri = Uri.parse(pathOrUrl);
      final bool isNetworkUrl = (uri.scheme == 'http' || uri.scheme == 'https');

      AudioSource source; // REMOVED ALIAS
      if (isNetworkUrl) {
        logger.d('[ADAPTER SET_SOURCE $pathOrUrl] Detected NETWORK URL.');
        source = AudioSource.uri(uri); // REMOVED ALIAS
      } else {
        logger.d(
          '[ADAPTER SET_SOURCE $pathOrUrl] Detected LOCAL PATH (assuming file scheme).',
        );
        // Ensure it's treated as a file URI, even if scheme is missing
        source = AudioSource.uri(
          // REMOVED ALIAS
          Uri.file(pathOrUrl),
        );
      }

      logger.d(
        '[ADAPTER SET_SOURCE $pathOrUrl] Action: Calling _audioPlayer.setAudioSource...',
      );
      // setAudioSource returns nullable duration, but our interface is void.
      await _audioPlayer.setAudioSource(source);
      logger.d('[ADAPTER SET_SOURCE $pathOrUrl] setAudioSource call complete.');
    } catch (e, stackTrace) {
      logger.e(
        '[ADAPTER SET_SOURCE $pathOrUrl] FAILED',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
    logger.d('[ADAPTER SET_SOURCE $pathOrUrl] END');
  }
}
