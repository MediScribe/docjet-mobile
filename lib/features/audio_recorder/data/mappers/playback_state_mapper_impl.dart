import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:rxdart/rxdart.dart'; // Using rxdart for combining streams later

class PlaybackStateMapperImpl implements PlaybackStateMapper {
  // Controller for the output stream
  final _playbackStateController = BehaviorSubject<PlaybackState>.seeded(
    const PlaybackState.initial(),
  );

  // Input stream subscriptions (to be managed)
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _completeSubscription;

  // Keep track of the latest known values
  Duration _currentDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;

  @override
  Stream<PlaybackState> get playbackStateStream =>
      _playbackStateController.stream;

  @override
  void initialize({
    required Stream<Duration> positionStream,
    required Stream<Duration> durationStream,
    required Stream<void> completeStream,
    required Stream<PlayerState> playerStateStream,
  }) {
    // Clean up any existing listeners first
    dispose();

    // Store latest values from input streams
    _durationSubscription = durationStream.listen((duration) {
      _currentDuration = duration;
      // Potentially update state if already playing/paused
      _updateStateBasedOnCurrentValues();
    });

    _positionSubscription = positionStream.listen((position) {
      _currentPosition = position;
      // Potentially update state if already playing/paused
      _updateStateBasedOnCurrentValues();
    });

    // Listen to player state changes (CORE LOGIC FOR THIS TEST)
    _playerStateSubscription = playerStateStream.listen(
      (playerState) {
        switch (playerState) {
          case PlayerState.playing:
            _playbackStateController.add(
              PlaybackState.playing(
                currentPosition: _currentPosition,
                totalDuration: _currentDuration,
              ),
            );
            break;
          // Other states will be handled in subsequent TDD steps
          case PlayerState.paused:
          case PlayerState.stopped:
          case PlayerState.completed:
          case PlayerState.disposed: // Or handle specific logic
            // For now, do nothing for other states to pass the specific test
            break;
        }
      },
      onError: (error) {
        // Handle potential errors from the player state stream
        _playbackStateController.add(
          PlaybackState.error(message: error.toString()),
        );
      },
    );

    _completeSubscription = completeStream.listen((_) {
      // Handle completion -> Will be tested later
    });

    // Add error handling for other streams too?
    // durationStream.handleError(...)?
    // positionStream.handleError(...)?
    // Consider how errors in duration/position should affect the state.
  }

  // Helper to re-emit state when position/duration changes while playing/paused
  void _updateStateBasedOnCurrentValues() {
    final currentState = _playbackStateController.value;
    // Use map to handle the specific states we care about and update accordingly
    currentState.map(
      initial: (_) {}, // Do nothing for initial state
      loading: (_) {}, // Do nothing for loading state
      playing: (playingState) {
        _playbackStateController.add(
          playingState.copyWith(
            currentPosition: _currentPosition,
            totalDuration: _currentDuration,
          ),
        );
      },
      paused: (pausedState) {
        _playbackStateController.add(
          pausedState.copyWith(
            currentPosition: _currentPosition,
            totalDuration: _currentDuration,
          ),
        );
      },
      stopped: (_) {}, // Do nothing for stopped state
      completed: (_) {}, // Do nothing for completed state
      error: (errorState) {
        // Optionally update position/duration even in error state if relevant
        // For now, do nothing.
      },
    );
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _completeSubscription?.cancel();
    // Don't close the controller here if the service manages the mapper lifecycle
    // and might re-initialize it. Let the owner close it if needed.
    // _playbackStateController.close();
  }
}
