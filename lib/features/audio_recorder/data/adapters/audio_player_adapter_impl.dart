import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';

/// Concrete implementation of [AudioPlayerAdapter] using the `just_audio` package.
class AudioPlayerAdapterImpl implements AudioPlayerAdapter {
  final logger = LoggerFactory.getLogger(
    AudioPlayerAdapterImpl,
    level: Level.off,
  );

  final AudioPlayer _audioPlayer; // REMOVED ALIAS

  // Create a timestamp counter to track event sequences
  int _eventSequence = 0;

  // Constructor no longer needs to listen immediately
  AudioPlayerAdapterImpl(this._audioPlayer) {
    logger.d('[ADAPTER_INIT] Creating AudioPlayerAdapterImpl instance.');
    // Internal listeners primarily for logging/debugging if needed
    _audioPlayer.playerStateStream.listen(
      (state) {
        // Add more detailed logging of raw player state changes
        final seqId = _eventSequence++; // Increment sequence for each event
        logger.t(
          '[ADAPTER_RAW_STATE #$seqId] Raw player state changed: playing=${state.playing}, processingState=${state.processingState}',
        );
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
        // Add logging for duration changes
        logger.t(
          '[ADAPTER_RAW_DURATION] Duration changed: ${dur?.inMilliseconds ?? 0}ms',
        );
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
    final seqId = _eventSequence++;
    logger.d(
      '[ADAPTER PAUSE #$seqId] START - Before: playing=${_audioPlayer.playing}, processingState=${_audioPlayer.processingState}',
    );
    try {
      await _audioPlayer.pause();
      logger.d(
        '[ADAPTER PAUSE #$seqId] Call complete - After: playing=${_audioPlayer.playing}, processingState=${_audioPlayer.processingState}',
      );
    } catch (e, s) {
      logger.e('[ADAPTER PAUSE #$seqId] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[ADAPTER PAUSE #$seqId] END');
  }

  @override
  Future<void> resume() async {
    // just_audio uses play() to resume
    final seqId = _eventSequence++;
    logger.d(
      '[ADAPTER RESUME #$seqId] START - Before: playing=${_audioPlayer.playing}, processingState=${_audioPlayer.processingState}',
    );
    try {
      await _audioPlayer.play();
      logger.d(
        '[ADAPTER RESUME #$seqId] play() call complete - After: playing=${_audioPlayer.playing}, processingState=${_audioPlayer.processingState}',
      );
    } catch (e, s) {
      logger.e('[ADAPTER RESUME #$seqId] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[ADAPTER RESUME #$seqId] END');
  }

  @override
  Future<void> seek(String filePath, Duration position) async {
    // Note: filePath is required by the interface, but just_audio's seek only uses position.
    logger.d('[ADAPTER SEEK $filePath @ ${position.inMilliseconds}ms] START');
    try {
      await _audioPlayer.seek(position);
      logger.d('[ADAPTER SEEK] Call complete.');
    } catch (e, s) {
      logger.e('[ADAPTER SEEK] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[ADAPTER SEEK $filePath @ ${position.inMilliseconds}ms] END');
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
          final seqId = _eventSequence++;
          // Change to TRACE level to reduce noise
          logger.t(
            '[ADAPTER STREAM MAP #$seqId] Input PlayerState: processingState=${state.processingState}, playing=${state.playing}',
          );

          // Special debugging for state transitions - now just a regular debug log
          logger.t(
            '[STATE_TRANSITION #$seqId] RAW: ${state.processingState}, playing=${state.playing}',
          );

          DomainPlayerState domainState;

          // Normal state mapping logic
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

          logger.t(
            '[ADAPTER STREAM MAP #$seqId] Translating: ${state.processingState} + playing=${state.playing} => $domainState',
          );

          // Special debugging for state transitions - now just a regular debug log
          logger.t('[STATE_TRANSITION #$seqId] MAPPED: $domainState');

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
    final seqId = _eventSequence++;
    final startLoadTime = DateTime.now().millisecondsSinceEpoch;
    logger.d(
      '[ADAPTER SET_SOURCE_URL #$seqId] START: $url - Before: playing=${_audioPlayer.playing}, processingState=${_audioPlayer.processingState}',
    );
    try {
      // Determine if it's a local file or a remote URL
      Uri uri = Uri.parse(url);
      AudioSource source;
      if (uri.isScheme('file')) {
        logger.d('[ADAPTER SET_SOURCE_URL #$seqId] Detected local file path.');
        source = AudioSource.uri(uri);
      } else if (uri.isScheme('http') || uri.isScheme('https')) {
        logger.d('[ADAPTER SET_SOURCE_URL #$seqId] Detected remote URL.');
        source = AudioSource.uri(uri);
      } else {
        logger.d(
          '[ADAPTER SET_SOURCE_URL #$seqId] Unrecognized scheme: ${uri.scheme}. Assuming local file path.',
        );
        // Assume it's a local path if no scheme or unrecognized scheme
        source = AudioSource.uri(Uri.file(url));
      }
      logger.d(
        '[ADAPTER SET_SOURCE_URL #$seqId] Calling _audioPlayer.setAudioSource...',
      );
      // Use setAudioSource which returns Future<Duration?> (duration)
      final duration = await _audioPlayer.setAudioSource(
        source,
        // Consider initialPosition and preload if needed
        // initialPosition: Duration.zero,
        // preload: true,
      );
      final loadDuration =
          DateTime.now().millisecondsSinceEpoch - startLoadTime;
      logger.d(
        '[ADAPTER SET_SOURCE_URL #$seqId] Call complete - Returned duration: ${duration?.inMilliseconds}ms, After: playing=${_audioPlayer.playing}, processingState=${_audioPlayer.processingState}',
      );
      logger.d('[ADAPTER TIMING] Audio source loading took ${loadDuration}ms');
    } catch (e, s) {
      logger.e(
        '[ADAPTER SET_SOURCE_URL #$seqId] FAILED',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
    logger.d('[ADAPTER SET_SOURCE_URL #$seqId] END');
  }
}
