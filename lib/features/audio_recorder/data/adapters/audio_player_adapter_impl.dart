import 'dart:async';

import 'package:docjet_mobile/core/platform/src/path_resolver.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';
import 'package:just_audio/just_audio.dart';

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

  /// Factory for creating new player instances (used for getDuration)
  final AudioPlayerFactory _audioPlayerFactory;

  /// Counter to help track and correlate log messages for specific operations
  int _eventSequence = 0;

  /// Internal state tracking
  bool _disposed = false;

  /// Path resolver for resolving paths
  final PathResolver _pathResolver;

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
  /// [audioPlayerFactory]: Factory for creating temporary players for getDuration
  /// [pathResolver]: Path resolver for resolving paths for getDuration method
  AudioPlayerAdapterImpl(
    this._audioPlayer, {
    AudioPlayerFactory? audioPlayerFactory,
    required PathResolver pathResolver,
  }) : _audioPlayerFactory = audioPlayerFactory ?? defaultAudioPlayerFactory,
       _pathResolver = pathResolver {
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
  /// The caller is responsible for providing a valid, resolved path that points
  /// to an existing audio file. This adapter does not validate file existence.
  @override
  Future<void> setSourceUrl(String url) async {
    if (_disposed) throw StateError('Adapter is disposed');

    if (url.isEmpty) {
      throw Exception('Path cannot be empty');
    }

    final Uri uri;

    try {
      // Properly handle different URL types
      if (url.startsWith('http://') || url.startsWith('https://')) {
        // Handle remote URLs
        uri = Uri.parse(url);
      } else {
        // For local file paths, use PathResolver to handle both absolute and relative paths
        final resolvedPath = await _pathResolver.resolve(url, mustExist: true);
        // Then use URI.file to ensure proper encoding
        uri = Uri.file(resolvedPath);
      }

      // Additional validation - ensure we have a valid scheme
      if (uri.scheme.isEmpty) {
        throw FormatException('Invalid URI: missing scheme');
      }
    } catch (e) {
      throw Exception('Invalid URI: $e');
    }

    logger.d('[ADAPTER SET_SOURCE_URL] Using URI: $uri');

    try {
      logger.d('[ADAPTER SET_SOURCE_URL] Setting audio source...');
      final startTime = DateTime.now();

      // Create the audio source with the URI
      final source = AudioSource.uri(uri);

      await _audioPlayer.setAudioSource(source);
      final endTime = DateTime.now();
      final duration = _audioPlayer.duration;
      logger.d(
        '[ADAPTER SET_SOURCE_URL] Success! Duration: ${duration?.inMilliseconds ?? 0}ms, Loading took: ${endTime.difference(startTime).inMilliseconds}ms',
      );
    } catch (e) {
      final startTime = DateTime.now();
      logger.e(
        '[ADAPTER SET_SOURCE_URL] FAILED after ${DateTime.now().difference(startTime).inMilliseconds}ms',
        error: e,
      );
      throw Exception(e);
    }
  }

  /// Determines the duration of an audio file without fully loading it for playback.
  ///
  /// [relativePath]: The relative path to the audio file (subdirectories allowed).
  /// Resolves the path using PathResolver and passes the absolute path to just_audio.
  @override
  Future<Duration> getDuration(String relativePath) async {
    logger.d('[ADAPTER GET_DURATION] START: $relativePath');
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final player = _audioPlayerFactory();
    try {
      // Resolve the relative path to an absolute path
      final absolutePath = await _pathResolver.resolve(
        relativePath,
        mustExist: true,
      );
      logger.d('[ADAPTER GET_DURATION] Resolved path: $absolutePath');
      final duration = await player.setFilePath(absolutePath);
      if (duration == null) {
        logger.e('[ADAPTER GET_DURATION] Failed to get duration (null result)');
        throw Exception(
          'Could not determine duration for file $absolutePath (possibly invalid/corrupt).',
        );
      }
      final elapsedTime = DateTime.now().millisecondsSinceEpoch - startTime;
      logger.d(
        '[ADAPTER GET_DURATION] Success: ${duration.inMilliseconds}ms, took ${elapsedTime}ms',
      );
      return duration;
    } catch (e, s) {
      final elapsedTime = DateTime.now().millisecondsSinceEpoch - startTime;
      logger.e(
        '[ADAPTER GET_DURATION] Failed after ${elapsedTime}ms',
        error: e,
        stackTrace: s,
      );
      rethrow;
    } finally {
      logger.d('[ADAPTER GET_DURATION] Disposing temp player');
      await player.dispose();
      logger.d('[ADAPTER GET_DURATION] END');
    }
  }
}
