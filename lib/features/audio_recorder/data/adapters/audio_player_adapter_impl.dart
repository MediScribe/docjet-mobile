import 'dart:async';

import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

/// Concrete implementation of [AudioPlayerAdapter] using the `just_audio` package.
class AudioPlayerAdapterImpl implements AudioPlayerAdapter {
  final logger = LoggerFactory.getLogger(
    AudioPlayerAdapterImpl,
    level: Level.debug,
  );
  final String _tag = logTag(AudioPlayerAdapterImpl);

  // Core just_audio player instance
  final AudioPlayer _audioPlayer;

  // File system dependency for consistent path handling
  final FileSystem? _fileSystem;

  // Counter to help track and correlate log messages for specific operations
  int _eventSequence = 0;

  // Stream controllers for contract streams
  late final StreamController<DomainPlayerState> _playerStateController;
  late final StreamController<Duration> _durationController;
  late final StreamController<Duration> _positionController;
  late final StreamController<void> _playerCompleteController;
  late final List<StreamSubscription> _internalSubscriptions;
  bool _disposed = false;

  AudioPlayerAdapterImpl(
    this._audioPlayer, {
    PathProvider? pathProvider,
    FileSystem? fileSystem,
  }) : _fileSystem = fileSystem {
    logger.d('$_tag Creating AudioPlayerAdapterImpl instance.');
    _playerStateController = StreamController<DomainPlayerState>.broadcast();
    _durationController = StreamController<Duration>.broadcast();
    _positionController = StreamController<Duration>.broadcast();
    _playerCompleteController = StreamController<void>.broadcast();
    _internalSubscriptions = [];
    _setupInternalListeners();
  }

  void _setupInternalListeners() {
    // Internal listeners for logging/debugging if needed
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
          _playerStateController.add(domainState);
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

  @override
  Future<void> seek(String filePath, Duration position) async {
    if (_disposed) throw StateError('Adapter is disposed');
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

  @override
  Future<void> dispose() async {
    logger.d('[ADAPTER DISPOSE] START');
    try {
      await _audioPlayer.dispose();
      logger.d('[ADAPTER DISPOSE] Call complete.');
    } catch (e, s) {
      logger.e('[ADAPTER DISPOSE] FAILED', error: e, stackTrace: s);
    }
    for (final sub in _internalSubscriptions) {
      await sub.cancel();
    }
    await _playerStateController.close();
    await _durationController.close();
    await _positionController.close();
    await _playerCompleteController.close();
    _disposed = true;
    logger.d('[ADAPTER DISPOSE] END');
  }

  @override
  Stream<DomainPlayerState> get onPlayerStateChanged =>
      _playerStateController.stream;

  @override
  Stream<Duration> get onDurationChanged => _durationController.stream;

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Stream<void> get onPlayerComplete => _playerCompleteController.stream;

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

      // Stricter check for invalid file paths (not remote)
      if (!isRemote) {
        final isAbs = p.isAbsolute(url);
        final isRel = p.isRelative(url);
        // ':' is only allowed at the start for Windows drive letters, but not in the middle (e.g. '::not_a_uri::')
        final hasIllegalColon =
            url.contains(':') &&
            !RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(url) &&
            !url.startsWith('/');
        if ((!isAbs && !isRel) || hasIllegalColon) {
          logger.e('[ADAPTER SET_SOURCE_URL #$seqId] Invalid file path: $url');
          throw Exception('Invalid audio file path: $url');
        }
      }

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
      // Only throw for truly invalid file paths (e.g., empty)
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
}
