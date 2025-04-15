import 'dart:async';

import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

/// Function type for creating AudioPlayer instances.
/// Used for dependency injection to enable proper testing.
typedef AudioPlayerFactory = AudioPlayer Function();

/// Default factory that creates real AudioPlayer instances.
/// This provides the real implementation for production use.
AudioPlayer defaultAudioPlayerFactory() => AudioPlayer();

/// Concrete implementation of [AudioPlayerAdapter] using the `just_audio` package.
///
/// This adapter encapsulates all direct interactions with the just_audio library,
/// providing a clean domain-specific interface for the rest of the application.
/// It handles state mapping, error handling, and resource management.
class AudioPlayerAdapterImpl implements AudioPlayerAdapter {
  // ============================================================
  // Fields and Dependencies
  // ============================================================

  /// Logger instance for this class
  final logger = LoggerFactory.getLogger(
    AudioPlayerAdapterImpl,
    level: Level.debug,
  );

  /// Tag for logging
  final String _tag = logTag(AudioPlayerAdapterImpl);

  /// Core just_audio player instance managed by this adapter
  final AudioPlayer _audioPlayer;

  /// File system dependency for checking file existence
  final FileSystem? _fileSystem;

  /// Factory for creating new player instances (used for getDuration)
  final AudioPlayerFactory _audioPlayerFactory;

  /// Counter to help track and correlate log messages for specific operations
  int _eventSequence = 0;

  /// Internal state tracking
  bool _disposed = false;

  // ============================================================
  // Stream Controllers (for domain-specific events)
  // ============================================================

  /// Exposes player state changes (playing, paused, etc.)
  late final StreamController<DomainPlayerState> _playerStateController;

  /// Exposes duration changes
  late final StreamController<Duration> _durationController;

  /// Exposes position changes during playback
  late final StreamController<Duration> _positionController;

  /// Exposes completion events
  late final StreamController<void> _playerCompleteController;

  /// Tracks all internal subscriptions for proper cleanup
  late final List<StreamSubscription> _internalSubscriptions;

  // ============================================================
  // Constructor and Initialization
  // ============================================================

  /// Creates a new adapter instance with the provided dependencies.
  ///
  /// [_audioPlayer]: The main player instance for playback operations
  /// [pathProvider]: Optional path provider for resolving paths (legacy)
  /// [fileSystem]: Optional file system for checking file existence
  /// [audioPlayerFactory]: Factory for creating temporary players for getDuration
  AudioPlayerAdapterImpl(
    this._audioPlayer, {
    PathProvider? pathProvider,
    FileSystem? fileSystem,
    AudioPlayerFactory? audioPlayerFactory,
  }) : _fileSystem = fileSystem,
       _audioPlayerFactory = audioPlayerFactory ?? defaultAudioPlayerFactory {
    logger.d('$_tag Creating AudioPlayerAdapterImpl instance.');

    // Initialize stream controllers
    _playerStateController = StreamController<DomainPlayerState>.broadcast();
    _durationController = StreamController<Duration>.broadcast();
    _positionController = StreamController<Duration>.broadcast();
    _playerCompleteController = StreamController<void>.broadcast();
    _internalSubscriptions = [];

    // Set up event listeners
    _setupInternalListeners();
  }

  // ============================================================
  // Internal Setup and Event Handling
  // ============================================================

  /// Sets up listeners for the underlying player events and maps them
  /// to domain-specific events using the stream controllers.
  void _setupInternalListeners() {
    // Listen for player state changes and map to domain states
    _internalSubscriptions.add(
      _audioPlayer.playerStateStream.listen(
        (state) {
          final seqId = _eventSequence++;
          logger.t(
            '[ADAPTER_RAW_STATE #$seqId] Raw player state changed: playing=${state.playing}, processingState=${state.processingState}',
          );

          // Map to DomainPlayerState and add to controller
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

          // Emit the domain state to listeners
          _playerStateController.add(domainState);

          // Emit a completion event if needed
          if (state.processingState == ProcessingState.completed) {
            _playerCompleteController.add(null);
          }
        },
        onError: (e, s) {
          logger.e(
            '[ADAPTER_INTERNAL] Error in playerStateStream',
            error: e,
            stackTrace: s,
          );
        },
      ),
    );

    // Listen for position updates
    _internalSubscriptions.add(
      _audioPlayer.positionStream.listen(
        (pos) {
          logger.t('[ADAPTER_RAW_POS] Position: ${pos.inMilliseconds}ms');
          _positionController.add(pos);
        },
        onError: (e, s) {
          logger.e(
            '[ADAPTER_INTERNAL] Error in positionStream',
            error: e,
            stackTrace: s,
          );
        },
      ),
    );

    // Listen for duration updates, filtering out nulls
    _internalSubscriptions.add(
      _audioPlayer.durationStream.listen(
        (dur) {
          logger.t(
            '[ADAPTER_RAW_DURATION] Duration changed: ${dur?.inMilliseconds ?? 0}ms',
          );
          if (dur != null) _durationController.add(dur);
        },
        onError: (e, s) {
          logger.e(
            '[ADAPTER_INTERNAL] Error in durationStream',
            error: e,
            stackTrace: s,
          );
        },
      ),
    );
  }

  // ============================================================
  // Public API Implementation (AudioPlayerAdapter Interface)
  // ============================================================

  /// Pauses the currently playing audio.
  @override
  Future<void> pause() async {
    if (_disposed) throw StateError('Adapter is disposed');

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

  /// Resumes playback if paused.
  @override
  Future<void> resume() async {
    if (_disposed) throw StateError('Adapter is disposed');

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

  /// Seeks to the specified position in the audio file.
  ///
  /// Note: filePath is required by the interface but not used by just_audio's seek.
  @override
  Future<void> seek(String filePath, Duration position) async {
    if (_disposed) throw StateError('Adapter is disposed');

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

  /// Stops playback completely.
  @override
  Future<void> stop() async {
    if (_disposed) throw StateError('Adapter is disposed');

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

  /// Releases all resources and disposes this adapter.
  ///
  /// After calling this method, the adapter is no longer usable.
  @override
  Future<void> dispose() async {
    logger.d('[ADAPTER DISPOSE] START');

    try {
      await _audioPlayer.dispose();
      logger.d('[ADAPTER DISPOSE] Call complete.');
    } catch (e, s) {
      logger.e('[ADAPTER DISPOSE] FAILED', error: e, stackTrace: s);
    }

    // Clean up all resources
    for (final sub in _internalSubscriptions) {
      await sub.cancel();
    }

    // Close all stream controllers
    await _playerStateController.close();
    await _durationController.close();
    await _positionController.close();
    await _playerCompleteController.close();

    _disposed = true;
    logger.d('[ADAPTER DISPOSE] END');
  }

  // ============================================================
  // Stream Getters (Public)
  // ============================================================

  /// Stream of player state changes.
  @override
  Stream<DomainPlayerState> get onPlayerStateChanged =>
      _playerStateController.stream;

  /// Stream of audio duration changes.
  @override
  Stream<Duration> get onDurationChanged => _durationController.stream;

  /// Stream of playback position changes.
  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  /// Stream of playback completion events.
  @override
  Stream<void> get onPlayerComplete => _playerCompleteController.stream;

  // ============================================================
  // File and Source Management
  // ============================================================

  /// Sets the audio source from a URL or file path.
  ///
  /// Supports both remote URLs (http/https) and local file paths.
  /// If FileSystem is provided, local paths are checked for existence.
  @override
  Future<void> setSourceUrl(String url) async {
    if (_disposed) throw StateError('Adapter is disposed');

    if (url.trim().isEmpty) {
      throw Exception('Audio file path cannot be empty');
    }

    final isRemote = url.startsWith('http://') || url.startsWith('https://');
    final seqId = _eventSequence++;
    final startLoadTime = DateTime.now().millisecondsSinceEpoch;

    logger.d('[ADAPTER SET_SOURCE_URL #$seqId] START: $url');

    try {
      String resolvedPath = url;
      bool fileExists = false;

      // Check file existence for local paths if FileSystem is available
      if (!isRemote && _fileSystem != null) {
        fileExists = await _fileSystem.fileExists(url);
        if (!fileExists) {
          logger.e('[ADAPTER SET_SOURCE_URL #$seqId] File not found: $url');
          throw Exception('Audio file not found: $url');
        }
        // No need to resolve to absolute, just use the path as is
        // The FileSystem implementation already resolves it internally
      } else if (!isRemote && _fileSystem == null) {
        logger.w(
          '[ADAPTER SET_SOURCE_URL #$seqId] No FileSystem provided, skipping existence check.',
        );
      }

      // Perform stricter validation for local file paths
      if (!isRemote) {
        final isAbs = p.isAbsolute(url);
        final isRel = p.isRelative(url);

        // ':' is only allowed at the start for Windows drive letters, not in the middle
        final hasIllegalColon =
            url.contains(':') &&
            !RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(url) &&
            !url.startsWith('/');

        if ((!isAbs && !isRel) || hasIllegalColon) {
          logger.e('[ADAPTER SET_SOURCE_URL #$seqId] Invalid file path: $url');
          throw Exception('Invalid audio file path: $url');
        }
      }

      // Create proper URI from the path
      Uri uri;
      try {
        if (isRemote) {
          uri = Uri.parse(resolvedPath);
        } else {
          uri = Uri.file(resolvedPath);
        }
      } catch (e) {
        logger.e(
          '[ADAPTER SET_SOURCE_URL #$seqId] Invalid URI: $resolvedPath',
          error: e,
        );
        throw Exception('Invalid audio file path or URI: $resolvedPath');
      }

      // Final validation check
      if (!isRemote && (resolvedPath.trim().isEmpty)) {
        logger.e(
          '[ADAPTER SET_SOURCE_URL #$seqId] Invalid file path: $resolvedPath',
        );
        throw Exception('Invalid audio file path: $resolvedPath');
      }

      logger.d('[ADAPTER SET_SOURCE_URL #$seqId] Using URI: $uri');
      final source = AudioSource.uri(uri);

      // Set the audio source
      logger.d('[ADAPTER SET_SOURCE_URL #$seqId] Setting audio source...');
      final duration = await _audioPlayer.setAudioSource(source);

      // Log success with timing information
      final loadDuration =
          DateTime.now().millisecondsSinceEpoch - startLoadTime;
      logger.d(
        '[ADAPTER SET_SOURCE_URL #$seqId] Success! Duration: \x1B[36m${duration?.inMilliseconds}ms\x1B[0m, Loading took: ${loadDuration}ms',
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

  /// Determines the duration of an audio file without fully loading it for playback.
  ///
  /// This method uses a temporary player instance created by the injected factory.
  /// It disposes the player correctly regardless of success or failure.
  @override
  Future<Duration> getDuration(String absolutePath) async {
    logger.d('[ADAPTER GET_DURATION] START: $absolutePath');
    final startTime = DateTime.now().millisecondsSinceEpoch;

    // Create a temporary player instance
    final player = _audioPlayerFactory();
    try {
      logger.d(
        '[ADAPTER GET_DURATION] Created temp player, setting file path...',
      );

      // Request duration from just_audio
      final duration = await player.setFilePath(absolutePath);

      // Handle null durations (just_audio returns null for invalid files)
      if (duration == null) {
        logger.e('[ADAPTER GET_DURATION] Failed to get duration (null result)');
        throw Exception(
          'Could not determine duration for file $absolutePath (possibly invalid/corrupt).',
        );
      }

      // Log success with timing information
      final elapsedTime = DateTime.now().millisecondsSinceEpoch - startTime;
      logger.d(
        '[ADAPTER GET_DURATION] Success: ${duration.inMilliseconds}ms, took ${elapsedTime}ms',
      );
      return duration;
    } catch (e, s) {
      // Catch and log any errors, but rethrow to notify caller
      final elapsedTime = DateTime.now().millisecondsSinceEpoch - startTime;
      logger.e(
        '[ADAPTER GET_DURATION] Failed after ${elapsedTime}ms',
        error: e,
        stackTrace: s,
      );
      rethrow;
    } finally {
      // Always dispose the temporary player, even on error
      logger.d('[ADAPTER GET_DURATION] Disposing temp player');
      await player.dispose();
      logger.d('[ADAPTER GET_DURATION] END');
    }
  }
}
