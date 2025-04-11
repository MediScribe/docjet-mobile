import 'dart:async';

// import 'package:audioplayers/audioplayers.dart'; // Removed
import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart'; // Added
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:flutter/foundation.dart'; // For @visibleForTesting
import 'package:rxdart/rxdart.dart';

// Using centralized logger with level OFF
final logger = Logger(level: Level.off);

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
    _playbackStateStream = _createCombinedStream().asBroadcastStream();
  }

  Stream<PlaybackState> _createCombinedStream() {
    return Rx.merge([
      positionController.stream.map((pos) {
        _currentPosition = pos;
        // Clear error only if not in a terminal state
        if (_currentPlayerState != DomainPlayerState.stopped && // Changed type
            _currentPlayerState != DomainPlayerState.completed) {
          // Changed type
          _maybeClearError();
        }
        return _constructState();
      }),
      durationController.stream.map((dur) {
        _currentDuration = dur;
        _maybeClearError();
        return _constructState();
      }),
      completeController.stream.map((_) {
        _currentPlayerState = DomainPlayerState.completed; // Changed value
        _currentPosition = _currentDuration;
        _maybeClearError();
        return _constructState();
      }),
      playerStateController.stream.map((state) {
        // state is now DomainPlayerState
        final previousState = _currentPlayerState;
        _currentPlayerState = state;

        // Reset position if stopped/completed
        if ((state == DomainPlayerState.stopped || // Changed type
                state == DomainPlayerState.completed) && // Changed type
            previousState != DomainPlayerState.completed) {
          // Changed type
          _currentPosition = Duration.zero;
        }

        // Clear error when entering a non-error state
        if (state != DomainPlayerState.error) {
          // Changed condition
          _maybeClearError();
        }
        return _constructState();
      }),
      errorController.stream.map((errorMsg) {
        _currentError = errorMsg;
        return _constructState();
      }),
    ]).startWith(const PlaybackState.initial()).distinct();
  }

  void _maybeClearError() {
    if (_currentError != null) {
      _currentError = null;
    }
  }

  PlaybackState _constructState() {
    if (_currentError != null) {
      return PlaybackState.error(
        message: _currentError!,
        currentPosition: _currentPosition,
        totalDuration: _currentDuration,
      );
    }

    // Map DomainPlayerState to the appropriate PlaybackState
    switch (_currentPlayerState) {
      // Now switching on DomainPlayerState
      case DomainPlayerState.playing:
        return PlaybackState.playing(
          currentPosition: _currentPosition,
          totalDuration: _currentDuration,
        );
      case DomainPlayerState.paused:
        return PlaybackState.paused(
          currentPosition: _currentPosition,
          totalDuration: _currentDuration,
        );
      case DomainPlayerState.stopped:
      case DomainPlayerState
          .initial: // Treat initial domain state as stopped playback state
        return const PlaybackState.stopped();
      case DomainPlayerState.completed:
        return const PlaybackState.completed();
      case DomainPlayerState.loading:
        return const PlaybackState.loading();
      case DomainPlayerState.error:
        // This case should ideally be handled by the _currentError check above,
        // but include a fallback just in case.
        return PlaybackState.error(
          message: 'Playback error state encountered',
          currentPosition: _currentPosition,
          totalDuration: _currentDuration,
        );
    }
  }

  @override
  Stream<PlaybackState> get playbackStateStream => _playbackStateStream;

  @override
  void initialize({
    required Stream<Duration> positionStream,
    required Stream<Duration> durationStream,
    required Stream<void> completeStream,
    required Stream<DomainPlayerState>
    playerStateStream, // Changed parameter type
  }) {
    dispose();

    _subscriptions.add(
      positionStream.listen(positionController.add, onError: _handleError),
    );
    _subscriptions.add(
      durationStream.listen(durationController.add, onError: _handleError),
    );
    _subscriptions.add(
      completeStream.listen(completeController.add, onError: _handleError),
    );
    _subscriptions.add(
      playerStateStream.listen(
        // Listens to Stream<DomainPlayerState>
        playerStateController.add, // Adds DomainPlayerState to controller
        onError: _handleError,
      ),
    );
  }

  void _handleError(Object error, StackTrace stackTrace) {
    logger.e('PlaybackStateMapper Error: $error\n$stackTrace');
    final errorMsg =
        'Error in input stream: $error'; // Make error message clearer
    _currentError = errorMsg;
    errorController.add(errorMsg);
  }

  @override
  void setCurrentFilePath(String? filePath) {
    // Kept for interface compliance, no internal use.
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
