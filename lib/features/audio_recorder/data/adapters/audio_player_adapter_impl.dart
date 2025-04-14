import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:just_audio/just_audio.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';

/// Concrete implementation of [AudioPlayerAdapter] using the `just_audio` package.
class AudioPlayerAdapterImpl implements AudioPlayerAdapter {
  final logger = LoggerFactory.getLogger(
    AudioPlayerAdapterImpl,
    level: Level.debug,
  );
  final String _tag = logTag(AudioPlayerAdapterImpl);

  // Core just_audio player instance
  final AudioPlayer _audioPlayer;

  // Optional path provider for normalization support
  final PathProvider? _pathProvider;

  // File system dependency for consistent path handling
  final FileSystem? _fileSystem;

  // Counter to help track and correlate log messages for specific operations
  int _eventSequence = 0;

  // Constructor no longer needs to listen immediately
  AudioPlayerAdapterImpl(
    this._audioPlayer, {
    PathProvider? pathProvider,
    FileSystem? fileSystem,
  }) : _pathProvider = pathProvider,
       _fileSystem = fileSystem {
    logger.d('$_tag Creating AudioPlayerAdapterImpl instance.');
    // Internal listeners primarily for logging/debugging if needed
    _setupInternalListeners();
  }

  void _setupInternalListeners() {
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

  /// Normalizes a file path if we have access to the PathProvider.
  /// If we don't have that dependency, it returns the original path.
  Future<String> _normalizePath(String path) async {
    if (path.isEmpty) {
      return path;
    }

    // If this doesn't look like an absolute path, it's likely relative already
    if (!p.isAbsolute(path)) {
      logger.d('[ADAPTER NORMALIZE PATH] Path appears to be relative: $path');
      // Get the absolute path
      if (_pathProvider != null) {
        final docsDir = await _pathProvider.getApplicationDocumentsDirectory();
        final absolutePath = p.join(docsDir.path, path);
        logger.d(
          '[ADAPTER NORMALIZE PATH] Converted to absolute: $absolutePath',
        );
        return absolutePath;
      }
      return path;
    }

    // Handle absolute paths (for backward compatibility)
    if (path.contains('/var/mobile/Containers/Data/Application/')) {
      logger.d('[ADAPTER NORMALIZE PATH] Detected iOS container path: $path');
      try {
        // Check if the path exists as is first
        if (await File(path).exists()) {
          logger.d('[ADAPTER NORMALIZE PATH] Path exists as is');
          return path;
        }

        // Extract the filename (everything after the last slash)
        final filename = path.split('/').last;

        // Get current documents directory
        if (_pathProvider != null) {
          final docsDir =
              await _pathProvider.getApplicationDocumentsDirectory();
          final normalizedPath = p.join(docsDir.path, filename);

          logger.d(
            '[ADAPTER NORMALIZE PATH] Normalized path: $path → $normalizedPath',
          );
          return normalizedPath;
        }
      } catch (e) {
        logger.e('[ADAPTER NORMALIZE PATH] Error normalizing path: $e');
      }
    }
    return path; // Return original path if no normalization needed or available
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
          // Since we filtered nulls above, we know d is non-null here
          final duration =
              d!; // Use non-null assertion here to satisfy static analysis
          // Demoted from DEBUG to TRACE
          logger.t(
            '[ADAPTER STREAM MAP] Input Duration: ${duration.inMilliseconds}ms',
          );
          return duration;
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
    logger.d('[ADAPTER SET_SOURCE_URL #$seqId] START: $url');
    try {
      // Extract just the filename if it's a path
      final filename = url.contains('/') ? url.split('/').last : url;
      String absoluteUrl;
      bool fileExists = false;

      // STRATEGY 1: Try using the FileSystem's getAbsolutePath first (most efficient)
      if (_fileSystem != null) {
        try {
          // Check if file exists as a relative path
          fileExists = await _fileSystem!.fileExists(filename);
          if (fileExists) {
            // Get the absolute path from FileSystem
            absoluteUrl = await _fileSystem!.getAbsolutePath(filename);
            logger.d(
              '[ADAPTER SET_SOURCE_URL #$seqId] Found via FileSystem (relative path): $absoluteUrl',
            );
          } else {
            // Try with original path
            fileExists = await _fileSystem!.fileExists(url);
            if (fileExists) {
              absoluteUrl = await _fileSystem!.getAbsolutePath(url);
              logger.d(
                '[ADAPTER SET_SOURCE_URL #$seqId] Found via FileSystem (original path): $absoluteUrl',
              );
            } else {
              // Fall back to direct check
              absoluteUrl = url;
            }
          }
        } catch (e) {
          logger.e('[ADAPTER SET_SOURCE_URL #$seqId] FileSystem error: $e');
          absoluteUrl = url; // Fall back to input
        }
      } else {
        // No FileSystem, use direct path
        absoluteUrl = url;
      }

      // STRATEGY 2: If not found yet, try checking if the file exists directly
      if (!fileExists) {
        try {
          fileExists = await File(absoluteUrl).exists();
          logger.d(
            '[ADAPTER SET_SOURCE_URL #$seqId] Found via direct File check: $absoluteUrl',
          );
        } catch (e) {
          logger.e(
            '[ADAPTER SET_SOURCE_URL #$seqId] Direct file check error: $e',
          );
        }
      }

      // STRATEGY 3: Last resort - try in app documents directory with just filename
      if (!fileExists && _pathProvider != null) {
        try {
          final docsDir =
              await _pathProvider!.getApplicationDocumentsDirectory();
          final docDirPath = '${docsDir.path}/$filename';

          fileExists = await File(docDirPath).exists();
          if (fileExists) {
            absoluteUrl = docDirPath;
            logger.d(
              '[ADAPTER SET_SOURCE_URL #$seqId] Found in docs dir: $absoluteUrl',
            );
          }
        } catch (e) {
          logger.e('[ADAPTER SET_SOURCE_URL #$seqId] Docs dir check error: $e');
        }
      }

      // Log whether file was found
      if (!fileExists) {
        logger.w(
          '[ADAPTER SET_SOURCE_URL #$seqId] File not found but continuing anyway',
        );
      }

      // Create URI and audio source
      Uri uri = Uri.file(absoluteUrl);
      logger.d('[ADAPTER SET_SOURCE_URL #$seqId] Using URI: $uri');
      final source = AudioSource.uri(uri);

      // Set the audio source
      logger.d('[ADAPTER SET_SOURCE_URL #$seqId] Setting audio source...');
      final duration = await _audioPlayer.setAudioSource(source);

      final loadDuration =
          DateTime.now().millisecondsSinceEpoch - startLoadTime;
      logger.d(
        '[ADAPTER SET_SOURCE_URL #$seqId] Success! Duration: ${duration?.inMilliseconds}ms, Loading took: ${loadDuration}ms',
      );
    } catch (e, s) {
      final loadDuration =
          DateTime.now().millisecondsSinceEpoch - startLoadTime;
      logger.e(
        '[ADAPTER SET_SOURCE_URL #$seqId] FAILED after ${loadDuration}ms',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }
}
