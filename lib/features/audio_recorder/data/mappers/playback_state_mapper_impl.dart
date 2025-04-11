import 'dart:async';

// import 'package:audioplayers/audioplayers.dart'; // Removed
import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart'; // Added
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:flutter/foundation.dart'; // For @visibleForTesting
import 'package:rxdart/rxdart.dart';

// RE-ENABLE DEBUG LOGGING FOR MAPPER
final logger = Logger(level: Level.debug);

/// Implementation of [PlaybackStateMapper] that uses RxDart to combine and
/// transform audio player streams into a unified [PlaybackState] stream.
class PlaybackStateMapperImpl implements PlaybackStateMapper {
  // Controllers for input streams
  @visibleForTesting
  final positionController = StreamController<Duration>.broadcast();
  @visibleForTesting
  final durationController = StreamController<Duration>.broadcast();
  @visibleForTesting
  final completeController = StreamController<void>.broadcast();
  @visibleForTesting
  final playerStateController = StreamController<DomainPlayerState>.broadcast(); // Changed type
  @visibleForTesting
  final errorController = StreamController<String>.broadcast();

  // The merged and mapped output stream
  late final Stream<PlaybackState> _playbackStateStream;

  // Internal state variables
  DomainPlayerState _currentPlayerState =
      DomainPlayerState.initial; // Changed type and initial value
  Duration _currentDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  String? _currentError;

  // Subscriptions to input streams for cleanup
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  PlaybackStateMapperImpl() {
    logger.d('[MAPPER_INIT] Creating PlaybackStateMapperImpl instance.');
    _playbackStateStream = _createCombinedStream().asBroadcastStream(
      onListen:
          (_) => logger.d(
            '[MAPPER_STREAM] Listener added to playbackStateStream.',
          ),
      onCancel:
          (_) => logger.d(
            '[MAPPER_STREAM] Listener removed from playbackStateStream.',
          ),
    );
    logger.d('[MAPPER_INIT] PlaybackState stream created.');
  }

  Stream<PlaybackState> _createCombinedStream() {
    logger.d('[MAPPER_COMBINE] Creating combined stream...');
    return Rx.merge([
      positionController.stream
          .doOnData((pos) {
            // COMMENT OUT HIGH-FREQUENCY POSITION LOG
            // logger.d(
            //   '[MAPPER_RX] Input Position Update: ${pos.inMilliseconds}ms',
            // );
          })
          .map((pos) {
            _currentPosition = pos;
            if (_currentPlayerState != DomainPlayerState.stopped &&
                _currentPlayerState != DomainPlayerState.completed) {
              _maybeClearError('Position Update');
            }
            return _constructState('Position Update');
          }),
      durationController.stream
          .doOnData((dur) {
            logger.d(
              '[MAPPER_RX] Input Duration Update: ${dur.inMilliseconds}ms',
            );
          })
          .map((dur) {
            _currentDuration = dur;
            _maybeClearError('Duration Update');
            return _constructState('Duration Update');
          }),
      completeController.stream
          .doOnData((_) {
            logger.d('[MAPPER_RX] Input Complete Event');
          })
          .map((_) {
            _currentPlayerState = DomainPlayerState.completed;
            // Set position to duration on completion for consistency
            _currentPosition = _currentDuration;
            _maybeClearError('Complete Event');
            return _constructState('Complete Event');
          }),
      playerStateController.stream
          .doOnData((state) {
            // COMMENT OUT VERBOSE LOG
            // logger.d('[MAPPER_RX] Input PlayerState Update: $state');
          })
          .map((state) {
            final previousState = _currentPlayerState;
            _currentPlayerState = state;

            // Reset position if stopped/completed
            if ((state == DomainPlayerState.stopped ||
                    state == DomainPlayerState.completed) &&
                previousState != state) {
              // Avoid resetting if already stopped/completed
              logger.d(
                '[MAPPER_LOGIC] Resetting position due to state change: $previousState -> $state',
              );
              _currentPosition = Duration.zero;
            }

            // Clear error when entering a non-error state
            if (state != DomainPlayerState.error) {
              _maybeClearError('PlayerState Update');
            }
            return _constructState('PlayerState Update');
          }),
      errorController.stream
          .doOnData((errMsg) {
            logger.w(
              '[MAPPER_RX] Input Error Event: $errMsg',
            ); // Log errors as warnings
          })
          .map((errorMsg) {
            _currentError = errorMsg;
            // Don't clear position/duration on error
            return _constructState('Error Event');
          }),
    ]).startWith(const PlaybackState.initial())
    // Log before distinct to see everything coming through (COMMENT OUT)
    // .doOnData(
    //   (state) => logger.d('[MAPPER_COMBINE_OUT] Pre-Distinct: $state'),
    // )
    .distinct((prev, next) {
      // Consider states the same if their core type and duration match,
      // ignoring the currentPosition for distinctness.
      final bool sameType = prev.runtimeType == next.runtimeType;
      Duration prevDuration = Duration.zero;
      Duration nextDuration = Duration.zero;
      const Duration durationTolerance = Duration(
        milliseconds: 20,
      ); // Tolerance

      // Extract duration safely based on type
      prev.mapOrNull(
        playing: (s) => prevDuration = s.totalDuration,
        paused: (s) => prevDuration = s.totalDuration,
        error: (s) => prevDuration = s.totalDuration ?? Duration.zero,
      );
      next.mapOrNull(
        playing: (s) => nextDuration = s.totalDuration,
        paused: (s) => nextDuration = s.totalDuration,
        error: (s) => nextDuration = s.totalDuration ?? Duration.zero,
      );

      // Check duration within tolerance
      final bool durationWithinTolerance =
          (prevDuration - nextDuration).abs() <= durationTolerance;

      final bool areSame = sameType && durationWithinTolerance;

      // Log the comparison result for debugging (COMMENT OUT NOW)
      // logger.d(
      //   '[MAPPER_DISTINCT] Comparing: prev=$prev, next=$next => sameType: $sameType, durationWithinTolerance: $durationWithinTolerance (${prevDuration.inMilliseconds}ms vs ${nextDuration.inMilliseconds}ms), Result: ${areSame ? \'SAME (Filter)\' : \'DIFFERENT (Emit)\'}',\n          // );
      return areSame;
    })
    // Log after distinct to see what gets emitted (COMMENT OUT)
    // .doOnData(
    //   (state) =>
    //       logger.d('[MAPPER_COMBINE_OUT] Post-Distinct (Emitting): $state'),
    // );
    ;
  }

  void _maybeClearError(String trigger) {
    if (_currentError != null) {
      logger.d(
        '[MAPPER_LOGIC] Clearing error (was: $_currentError) due to $trigger',
      );
      _currentError = null;
    }
  }

  PlaybackState _constructState(String trigger) {
    PlaybackState newState;
    if (_currentError != null) {
      newState = PlaybackState.error(
        message: _currentError!,
        currentPosition: _currentPosition,
        totalDuration: _currentDuration,
      );
    } else {
      switch (_currentPlayerState) {
        case DomainPlayerState.playing:
          newState = PlaybackState.playing(
            currentPosition: _currentPosition,
            totalDuration: _currentDuration,
          );
          break;
        case DomainPlayerState.paused:
          newState = PlaybackState.paused(
            currentPosition: _currentPosition,
            totalDuration: _currentDuration,
          );
          break;
        case DomainPlayerState.stopped:
        case DomainPlayerState.initial:
          newState = const PlaybackState.stopped();
          break;
        case DomainPlayerState.completed:
          newState = const PlaybackState.completed();
          break;
        case DomainPlayerState.loading:
          newState = const PlaybackState.loading();
          break;
        case DomainPlayerState.error:
          // Should be caught by _currentError check, but fallback
          logger.w(
            '[MAPPER_CONSTRUCT] Constructing state from DomainPlayerState.error - this might indicate an issue.',
          );
          newState = PlaybackState.error(
            message: 'Playback error state encountered',
            currentPosition: _currentPosition,
            totalDuration: _currentDuration,
          );
          break;
      }
    }
    // logger.d('[MAPPER_CONSTRUCT] State constructed from trigger '$trigger': $newState');
    return newState;
  }

  @override
  Stream<PlaybackState> get playbackStateStream => _playbackStateStream;

  @override
  void initialize({
    required Stream<Duration> positionStream,
    required Stream<Duration> durationStream,
    required Stream<void> completeStream,
    required Stream<DomainPlayerState> playerStateStream,
  }) {
    logger.d(
      '[MAPPER_INIT] initialize() called. Disposing existing subscriptions...',
    );
    dispose(); // Ensure clean state before re-initializing

    logger.d('[MAPPER_INIT] Subscribing to input streams...');
    try {
      _subscriptions.add(
        positionStream.listen(
          positionController.add,
          onError: _handleError,
          onDone: () => logger.d('[MAPPER_RX_DONE] positionStream closed'),
        ),
      );
      _subscriptions.add(
        durationStream.listen(
          durationController.add,
          onError: _handleError,
          onDone: () => logger.d('[MAPPER_RX_DONE] durationStream closed'),
        ),
      );
      _subscriptions.add(
        completeStream.listen(
          completeController.add,
          onError: _handleError,
          onDone: () => logger.d('[MAPPER_RX_DONE] completeStream closed'),
        ),
      );
      _subscriptions.add(
        playerStateStream.listen(
          (domainState) {
            logger.d(
              '[MAPPER_RX] Received DomainPlayerState for forwarding: $domainState',
            );
            playerStateController.add(domainState);
          },
          onError: _handleError,
          onDone: () => logger.d('[MAPPER_RX_DONE] playerStateStream closed'),
        ),
      );
      logger.d('[MAPPER_INIT] Input streams subscribed successfully.');
    } catch (e, s) {
      logger.e(
        '[MAPPER_INIT] FAILED to subscribe to input streams',
        error: e,
        stackTrace: s,
      );
      // Consider how to handle initialization failure
      _handleError(e, s); // Report error via the mapper's error stream
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    logger.e(
      '[MAPPER_ERROR] Error received in input stream',
      error: error,
      stackTrace: stackTrace,
    );
    final errorMsg = 'Mapper Input Stream Error: $error';
    _currentError = errorMsg; // Update internal state immediately
    errorController.add(errorMsg); // Emit error state
    // Avoid calling _constructState here as it might lead to infinite loops if the error state itself causes issues
  }

  @override
  void setCurrentFilePath(String? filePath) {
    // This function seems unused internally, but log if called.
    logger.d(
      '[MAPPER_SET_PATH] setCurrentFilePath called with: $filePath (Note: This seems unused)',
    );
  }

  @override
  void dispose() {
    logger.d(
      '[MAPPER_DISPOSE] dispose() called. Cancelling ${_subscriptions.length} subscriptions.',
    );
    for (final sub in _subscriptions) {
      try {
        sub.cancel();
      } catch (e, s) {
        logger.w(
          '[MAPPER_DISPOSE] Error cancelling subscription: $e',
          stackTrace: s,
        );
      }
    }
    _subscriptions.clear();
    logger.d('[MAPPER_DISPOSE] Subscriptions cancelled and cleared.');
    // Note: We don't close the input controllers here as they might be managed externally
  }
}
