import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:flutter/foundation.dart'; // For @visibleForTesting
import 'package:rxdart/rxdart.dart';

/// Implementation of [PlaybackStateMapper] that uses RxDart to combine and
/// transform audio player streams into a unified [PlaybackState] stream.
class PlaybackStateMapperImpl implements PlaybackStateMapper {
  // Controllers for input streams - allows testing and external control
  @visibleForTesting
  final positionController = StreamController<Duration>.broadcast();
  @visibleForTesting
  final durationController = StreamController<Duration>.broadcast();
  @visibleForTesting
  final completeController = StreamController<void>.broadcast();
  @visibleForTesting
  final playerStateController = StreamController<PlayerState>.broadcast();
  // For emitting errors directly - needed for test reliability
  @visibleForTesting
  final errorController = StreamController<String>.broadcast();

  // The merged and mapped output stream
  late final Stream<PlaybackState> _playbackStateStream;

  // Internal state variables to hold the latest values
  PlayerState _currentPlayerState = PlayerState.stopped;
  Duration _currentDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  String? _currentError;

  // Subscriptions to input streams for cleanup
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  PlaybackStateMapperImpl() {
    _playbackStateStream = _createCombinedStream().asBroadcastStream();
  }

  Stream<PlaybackState> _createCombinedStream() {
    // Using merge: reacts to any event on any stream immediately.
    return Rx.merge([
          positionController.stream.map((pos) {
            _currentPosition = pos;
            // Clear error only if we are not in a terminal state from the player
            if (_currentPlayerState != PlayerState.stopped &&
                _currentPlayerState != PlayerState.completed) {
              _maybeClearError();
            }
            return _constructState();
          }),
          durationController.stream.map((dur) {
            _currentDuration = dur;
            _maybeClearError(); // Receiving duration implies things are likely okay
            return _constructState();
          }),
          completeController.stream.map((_) {
            _currentPlayerState = PlayerState.completed;
            _currentPosition =
                _currentDuration; // Position usually matches duration on completion
            _maybeClearError(); // Completion is a success state
            return _constructState();
          }),
          playerStateController.stream.map((state) {
            final previousState = _currentPlayerState;
            _currentPlayerState = state;

            // Reset position if stopped/completed only if it wasn't already completed
            // (completeController stream handles setting position for completion)
            if ((state == PlayerState.stopped ||
                    state == PlayerState.completed) &&
                previousState != PlayerState.completed) {
              _currentPosition = Duration.zero;
            }

            // Clear error when entering a stable state
            if (state == PlayerState.playing ||
                state == PlayerState.paused ||
                state == PlayerState.stopped ||
                state == PlayerState.completed) {
              _maybeClearError();
            }
            return _constructState();
          }),
          // Add the error stream to emit error states immediately
          errorController.stream.map((errorMsg) {
            _currentError = errorMsg;
            return _constructState();
          }),
        ])
        .startWith(const PlaybackState.initial()) // Start with an initial state
        .distinct(); // Avoid emitting identical consecutive states
  }

  // Clears the error state if it's currently set.
  void _maybeClearError() {
    if (_currentError != null) {
      _currentError = null;
    }
  }

  // Helper to construct the current state object
  PlaybackState _constructState() {
    // Prioritize error state
    if (_currentError != null) {
      return PlaybackState.error(
        message: _currentError!,
        currentPosition: _currentPosition,
        totalDuration: _currentDuration,
      );
    }

    // Map PlayerState to the appropriate PlaybackState subtype
    switch (_currentPlayerState) {
      case PlayerState.playing:
        return PlaybackState.playing(
          currentPosition: _currentPosition,
          totalDuration: _currentDuration,
        );
      case PlayerState.paused:
        return PlaybackState.paused(
          currentPosition: _currentPosition,
          totalDuration: _currentDuration,
        );
      case PlayerState.stopped:
        return const PlaybackState.stopped();
      case PlayerState.completed:
        return const PlaybackState.completed();
      case PlayerState.disposed:
        // Treat disposed as stopped
        return const PlaybackState.stopped();
    }
  }

  @override
  Stream<PlaybackState> get playbackStateStream => _playbackStateStream;

  @override
  void initialize({
    required Stream<Duration> positionStream,
    required Stream<Duration> durationStream,
    required Stream<void> completeStream,
    required Stream<PlayerState> playerStateStream,
  }) {
    // Cancel any existing subscriptions before creating new ones
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
        playerStateController.add,
        onError: _handleError,
      ),
    );
  }

  // Internal error handler
  void _handleError(Object error, StackTrace stackTrace) {
    debugPrint('PlaybackStateMapper Error: $error\n$stackTrace');
    final errorMsg = error.toString();
    _currentError = errorMsg;

    // IMPORTANT: Emit error immediately through the error controller
    // This ensures tests don't hang waiting for the next event
    errorController.add(errorMsg);
  }

  @override
  void dispose() {
    // Cancel stream subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    // Don't close controllers here if the mapper instance might be reused
    // or if tests need to inject events after disposal of subscriptions.
    // Let the owner of the mapper instance manage controller lifecycle if needed.
    // positionController.close();
    // durationController.close();
    // completeController.close();
    // playerStateController.close();
    // errorController.close();
  }
}
