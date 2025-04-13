import 'dart:async';

// import 'package:audioplayers/audioplayers.dart'; // Removed
import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart'; // Added
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:flutter/foundation.dart'; // For @visibleForTesting
import 'package:rxdart/rxdart.dart' as rx;
import 'package:meta/meta.dart';

// Set Logger Level to DEBUG for active development/debugging in this file
final logger = Logger(level: Level.debug);

// Special debug flag for state transition tracking - set to true to enable detailed transition logs
const bool _debugStateTransitions = true;

/// Implementation of [PlaybackStateMapper] that uses RxDart to combine and
/// transform audio player streams into a unified [PlaybackState] stream.
class PlaybackStateMapperImpl implements PlaybackStateMapper {
  // Stream Controllers for input streams from the Adapter
  @visibleForTesting
  final positionController = StreamController<Duration>.broadcast();
  @visibleForTesting
  final durationController = StreamController<Duration>.broadcast();
  @visibleForTesting
  final completeController = StreamController<void>.broadcast();
  @visibleForTesting
  final playerStateController = StreamController<DomainPlayerState>.broadcast();
  @visibleForTesting
  final errorController = StreamController<String>.broadcast();

  // The merged and mapped output stream
  late final Stream<PlaybackState> _playbackStateStream;

  // Flag to disable debouncing in test mode
  bool _testMode = false;

  // Debounce duration in milliseconds
  static const int _debounceDurationMs = 80;

  // Subscriptions to input streams (held for potential cleanup)
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  // Internal state variables tracking the latest values from input streams
  DomainPlayerState _currentPlayerState = DomainPlayerState.initial;
  Duration _currentDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  String? _currentError;

  PlaybackStateMapperImpl() {
    _playbackStateStream = _createCombinedStream().asBroadcastStream();
  }

  // --- Interface Implementation ---

  @override
  Stream<PlaybackState> get playbackStateStream => _playbackStateStream;

  @override
  void initialize({
    required Stream<Duration> positionStream,
    required Stream<Duration> durationStream,
    required Stream<void> completeStream,
    required Stream<DomainPlayerState> playerStateStream,
    Stream<String>? errorStream,
  }) {
    logger.d(
      '[MAPPER_INIT] Initializing and subscribing to adapter streams...',
    );
    // Clear any existing subscriptions before creating new ones
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    // Subscribe to the provided streams and pipe them to internal controllers
    _subscriptions.add(
      positionStream.listen(
        positionController.add,
        onError: (e, s) {
          logger.e(
            '[MAPPER_INIT] Error on adapter positionStream',
            error: e,
            stackTrace: s,
          );
          errorController.add('Adapter position stream error: $e');
        },
      ),
    );
    _subscriptions.add(
      durationStream.listen(
        durationController.add,
        onError: (e, s) {
          logger.e(
            '[MAPPER_INIT] Error on adapter durationStream',
            error: e,
            stackTrace: s,
          );
          errorController.add('Adapter duration stream error: $e');
        },
      ),
    );
    _subscriptions.add(
      completeStream.listen(
        completeController.add,
        onError: (e, s) {
          logger.e(
            '[MAPPER_INIT] Error on adapter completeStream',
            error: e,
            stackTrace: s,
          );
          errorController.add('Adapter complete stream error: $e');
        },
      ),
    );
    _subscriptions.add(
      playerStateStream.listen(
        playerStateController.add,
        onError: (e, s) {
          logger.e(
            '[MAPPER_INIT] Error on adapter playerStateStream',
            error: e,
            stackTrace: s,
          );
          errorController.add('Adapter player state stream error: $e');
        },
      ),
    );

    // Subscribe to error stream if provided
    if (errorStream != null) {
      _subscriptions.add(
        errorStream.listen(
          errorController.add,
          onError:
              (e, s) => logger.e(
                '[MAPPER_INIT] Error in error stream (meta-error)',
                error: e,
                stackTrace: s,
              ),
        ),
      );
    }

    logger.d('[MAPPER_INIT] Subscriptions complete.');
  }

  @override
  void dispose() {
    logger.d('[MAPPER_DISPOSE] Disposing PlaybackStateMapperImpl...');
    // Cancel all stream subscriptions
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    // Close all internal controllers
    positionController.close();
    durationController.close();
    completeController.close();
    playerStateController.close();
    errorController.close();
    logger.d('[MAPPER_DISPOSE] Dispose complete.');
  }

  /// Sets test mode which disables debouncing for more predictable test behavior
  @visibleForTesting
  void setTestMode(bool enabled) {
    _testMode = enabled;
    logger.d(
      '[MAPPER_CONFIG] Test mode ${enabled ? 'enabled' : 'disabled'} - debouncing will be ${enabled ? 'skipped' : 'applied'}',
    );
  }

  // --- Internal Stream Combination Logic ---

  Stream<PlaybackState> _createCombinedStream() {
    var stream = rx.Rx.merge([
          positionController.stream.map((pos) {
            _currentPosition = pos;
            if (_currentPlayerState != DomainPlayerState.stopped &&
                _currentPlayerState != DomainPlayerState.completed) {
              _maybeClearError('Position Update');
            }
            return _constructState('Position Update');
          }),
          durationController.stream.map((dur) {
            _currentDuration = dur;
            _maybeClearError('Duration Update');
            return _constructState('Duration Update');
          }),
          completeController.stream.map((_) {
            _currentPlayerState = DomainPlayerState.completed;
            _currentPosition =
                _currentDuration; // Set position to duration on completion
            _maybeClearError('Complete Event');
            return _constructState('Complete Event');
          }),
          playerStateController.stream.map((state) {
            final previousState = _currentPlayerState;
            _currentPlayerState = state;

            if ((state == DomainPlayerState.stopped ||
                    state == DomainPlayerState.completed) &&
                previousState != state) {
              _currentPosition = Duration.zero;
              // Clear file path context ONLY on explicit stop/completion, AFTER potential playback
              // No, completion handler above already clears it.
              // Stop might or might not clear it depending on desired resume behavior.
              // For now, let's NOT clear path on stop.
            }

            if (state != DomainPlayerState.error) {
              _maybeClearError('PlayerState Update');
            }
            return _constructState('PlayerState Update');
          }),
          errorController.stream.map((errorMsg) {
            _currentError = errorMsg;
            return _constructState('Error Event');
          }),
        ])
        .startWith(const PlaybackState.initial())
        .doOnData(
          // Demoted from DEBUG to TRACE due to high frequency
          (state) => logger.t('[MAPPER_PRE_DISTINCT] State: $state'),
        )
        .distinct(_areStatesEquivalent);

    // Apply debouncing only in production mode (not in tests)
    if (!_testMode) {
      logger.d(
        '[MAPPER_CONFIG] Production mode - applying ${_debounceDurationMs}ms debounce to prevent UI flicker',
      );
      // Wrap debounce in doOnData to log before and after
      stream = stream
          .doOnData(
            (state) => logger.t(
              '[MAPPER_DEBOUNCE_IN] State: $state',
            ), // Log state entering debounce
          )
          .debounceTime(Duration(milliseconds: _debounceDurationMs))
          .doOnData(
            (state) => logger.t(
              '[MAPPER_DEBOUNCE_OUT] State: $state',
            ), // Log state exiting debounce
          );
    } else {
      logger.d('[MAPPER_CONFIG] Test mode - no debouncing applied');
    }

    return stream.doOnData(
      // Demoted from DEBUG to TRACE due to high frequency
      (state) => logger.t('[MAPPER_POST_DISTINCT] State (Emitting): $state'),
    );
  }

  /// Clears the internal error state if it's currently set.
  void _maybeClearError(String trigger) {
    if (_currentError != null) {
      // logger.d('[MAPPER_LOGIC] Clearing error due to: $trigger'); // Keep DEBUG
      _currentError = null;
    }
  }

  /// Constructs the appropriate [PlaybackState] based on the current internal state.
  PlaybackState _constructState(String trigger) {
    logger.t(
      '[STATE_FLOW Mapper] Constructing state: playerState=$_currentPlayerState, position=$_currentPosition, duration=$_currentDuration, isComplete=${_currentPlayerState == DomainPlayerState.completed}',
    );

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
        case DomainPlayerState.loading:
          newState = const PlaybackState.loading();
          break;
        case DomainPlayerState.completed:
          newState = const PlaybackState.completed();
          break;
        case DomainPlayerState.stopped:
          newState = const PlaybackState.stopped();
          break;
        case DomainPlayerState.error:
          logger.w(
            '[MAPPER_CONSTRUCT] Constructing state from DomainPlayerState.error, but _currentError was null?',
          );
          newState = PlaybackState.error(
            message: 'Unknown player error',
            currentPosition: _currentPosition,
            totalDuration: _currentDuration,
          );
          break;
        case DomainPlayerState.initial:
          newState = const PlaybackState.initial();
          break;
      }
    }

    if (_debugStateTransitions) {
      // Demote this transition log as it can be noisy
      logger.t(
        '[STATE_TRANSITION] MAPPER: DomainPlayerState = $_currentPlayerState → PlaybackState = ${newState.runtimeType}',
      );
    }

    return newState;
  }

  /// Comparison logic for the `distinct` operator.
  bool _areStatesEquivalent(PlaybackState prev, PlaybackState next) {
    logger.t(
      '[STATE_FLOW Mapper] Comparing states for distinct: prev=$prev, next=$next',
    );
    final bool sameType = prev.runtimeType == next.runtimeType;
    if (!sameType) {
      // logger.t('[MAPPER_DISTINCT] Different Type: $prev vs $next => DIFFERENT (Emit)'); // Demoted
      return false;
    }

    Duration prevDuration = Duration.zero;
    Duration nextDuration = Duration.zero;
    Duration prevPosition = Duration.zero;
    Duration nextPosition = Duration.zero;
    const Duration tolerance = Duration(
      milliseconds: 100,
    ); // Tolerance for position/duration

    // Extract data using mapOrNull
    prev.mapOrNull(
      playing: (s) {
        prevDuration = s.totalDuration;
        prevPosition = s.currentPosition;
      },
      paused: (s) {
        prevDuration = s.totalDuration;
        prevPosition = s.currentPosition;
      },
      completed: (s) {
        // Completed state has no fields in the definition
        // prevDuration = s.totalDuration; // REMOVED
        // prevPosition = s.finalPosition; // REMOVED
      },
      error: (s) {
        prevDuration = s.totalDuration ?? Duration.zero;
        prevPosition = s.currentPosition ?? Duration.zero;
      },
    );
    next.mapOrNull(
      playing: (s) {
        nextDuration = s.totalDuration;
        nextPosition = s.currentPosition;
      },
      paused: (s) {
        nextDuration = s.totalDuration;
        nextPosition = s.currentPosition;
      },
      completed: (s) {
        // Completed state has no fields in the definition
        // nextDuration = s.totalDuration; // REMOVED
        // nextPosition = s.finalPosition; // REMOVED
      },
      error: (s) {
        nextDuration = s.totalDuration ?? Duration.zero;
        nextPosition = s.currentPosition ?? Duration.zero;
      },
    );

    final bool durationWithinTolerance =
        (prevDuration - nextDuration).abs() <= tolerance;
    final bool positionWithinTolerance =
        (prevPosition - nextPosition).abs() <= tolerance;

    // Consider states equivalent only if type, duration, AND position are within tolerance.
    final bool areSame = durationWithinTolerance && positionWithinTolerance;

    // logger.t(
    //   '[MAPPER_DISTINCT] Comparing ($sameType): pD=${prevDuration.inMilliseconds}, nD=${nextDuration.inMilliseconds} -> $durationWithinTolerance | pP=${prevPosition.inMilliseconds}, nP=${nextPosition.inMilliseconds} -> $positionWithinTolerance | Result: ${areSame ? \'SAME (Filter)\' : \'DIFFERENT (Emit)\'}',
    // ); // Demoted

    return areSame;
  }
}
