import 'dart:async';

// import 'package:audioplayers/audioplayers.dart' as audioplayers; // REMOVED
// import 'package:just_audio/just_audio.dart'; // REMOVED
import 'package:just_audio/just_audio.dart'; // REMOVED ALIAS
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';
// Import for Platform check if needed later, or Uri directly

// Set Logger Level to DEBUG for active development/debugging in this file
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
  AudioPlayerAdapterImpl(this._audioPlayer) {
    logger.d('[ADAPTER_INIT] Creating AudioPlayerAdapterImpl instance.');
    // Internal listeners primarily for logging/debugging if needed
    _audioPlayer.playerStateStream.listen(
      (state) {
        // Listener is kept for potential future debugging, but no active logging.
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
        // Demoted from DEBUG to TRACE due to high frequency
        logger.t('[ADAPTER_RAW_POS] Position: ${pos.inMilliseconds}ms');
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
        // Listener is kept for potential future debugging, but no active logging.
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
    logger.d('[ADAPTER PAUSE] START');
    try {
      await _audioPlayer.pause();
      logger.d(
        '[ADAPTER PAUSE] Call complete. State: playing=${_audioPlayer.playing}, processing=${_audioPlayer.processingState}',
      );
    } catch (e, s) {
      logger.e('[ADAPTER PAUSE] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[ADAPTER PAUSE] END');
  }

  @override
  Future<void> resume() async {
    // just_audio uses play() to resume
    logger.d('[ADAPTER RESUME] START (delegating to play())');
    try {
      await _audioPlayer.play();
      logger.d('[ADAPTER RESUME] play() call complete.');
    } catch (e, s) {
      logger.e('[ADAPTER RESUME] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[ADAPTER RESUME] END');
  }

  @override
  Future<void> seek(Duration position) async {
    logger.d('[ADAPTER SEEK ${position.inMilliseconds}ms] START');
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
    logger.d('[ADAPTER STOP] START');
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
    return _audioPlayer.playerStateStream
        .map((state) {
          // Demoted from DEBUG to TRACE
          logger.t(
            '[ADAPTER STREAM MAP] Input PlayerState: processing=${state.processingState}, playing=${state.playing}',
          );
          DomainPlayerState domainState;
          switch (state.processingState) {
            case ProcessingState.idle:
              domainState = DomainPlayerState.stopped;
              break;
            case ProcessingState.loading:
            case ProcessingState.buffering:
              domainState = DomainPlayerState.loading;
              break;
            case ProcessingState.ready:
              domainState =
                  state.playing
                      ? DomainPlayerState.playing
                      : DomainPlayerState.paused;
              break;
            case ProcessingState.completed:
              domainState = DomainPlayerState.completed;
              break;
          }
          // Demoted from DEBUG to TRACE
          logger.t(
            '[ADAPTER STREAM MAP] Output DomainPlayerState: $domainState',
          );
          return domainState;
        })
        .handleError((error, stackTrace) {
          logger.e(
            '[ADAPTER STREAM] Error in playerStateStream',
            error: error,
            stackTrace: stackTrace,
          );
          throw error;
        })
        .distinct();
  }

  @override
  Stream<Duration> get onDurationChanged {
    // logger.d('[ADAPTER STREAM] onDurationChanged accessed'); // Removed: Access logging is noisy
    return _audioPlayer.durationStream
        .where((d) => d != null) // Ensure non-null duration
        .map((d) {
          // Demoted from DEBUG to TRACE
          logger.t(
            '[ADAPTER STREAM MAP] Input Duration: ${d!.inMilliseconds}ms',
          );
          return d;
        })
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
    // logger.d('[ADAPTER STREAM] onPositionChanged accessed'); // Removed: Access logging is noisy
    return _audioPlayer.positionStream
        .map((pos) {
          // Demoted from DEBUG to TRACE due to high frequency
          logger.t(
            '[ADAPTER STREAM MAP] Input Position: ${pos.inMilliseconds}ms',
          );
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
        .map((_) => null) // Map to void
        .handleError((error, stackTrace) {
          logger.e(
            '[ADAPTER STREAM] Error filtering/mapping for playerComplete',
            error: error,
            stackTrace: stackTrace,
          );
          throw error;
        });
  }

  @override
  Future<void> setSourceUrl(String url) async {
    logger.d('[ADAPTER SET_SOURCE_URL] START: $url');
    try {
      // Determine if it's a local file or a remote URL
      Uri uri = Uri.parse(url);
      AudioSource source;
      if (uri.isScheme('file')) {
        // logger.d('[ADAPTER SET_SOURCE_URL] Detected local file path.'); // Keep for debug
        source = AudioSource.uri(uri);
      } else if (uri.isScheme('http') || uri.isScheme('https')) {
        // logger.d('[ADAPTER SET_SOURCE_URL] Detected remote URL.'); // Keep for debug
        source = AudioSource.uri(uri);
      } else {
        // logger.w('[ADAPTER SET_SOURCE_URL] Unrecognized scheme: ${uri.scheme}. Assuming local file path.'); // Keep for debug
        // Assume it's a local path if no scheme or unrecognized scheme
        source = AudioSource.uri(Uri.file(url));
      }
      logger.d(
        '[ADAPTER SET_SOURCE_URL] Calling _audioPlayer.setAudioSource...',
      );
      // Use setAudioSource which returns Future<Duration?> (duration)
      final duration = await _audioPlayer.setAudioSource(
        source,
        // Consider initialPosition and preload if needed
        // initialPosition: Duration.zero,
        // preload: true,
      );
      logger.d(
        '[ADAPTER SET_SOURCE_URL] Call complete. Returned duration: ${duration?.inMilliseconds}ms',
      );
    } catch (e, s) {
      logger.e('[ADAPTER SET_SOURCE_URL] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[ADAPTER SET_SOURCE_URL] END');
  }
}
