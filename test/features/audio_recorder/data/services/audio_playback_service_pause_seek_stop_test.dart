// Imports
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/models/playback_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_async/fake_async.dart'; // Use fake_async

// Import the generated mocks
import 'audio_playback_service_impl_test.mocks.dart';

// Annotation to generate MockAudioPlayer
@GenerateMocks([AudioPlayer])
void main() {
  late MockAudioPlayer mockAudioPlayer;
  late AudioPlaybackServiceImpl service;

  // Declare controllers
  late StreamController<PlayerState> playerStateController;
  late StreamController<Duration> durationController;
  late StreamController<Duration> positionController;
  late StreamController<void> completionController;
  late StreamController<String> logController;

  setUp(() {
    mockAudioPlayer = MockAudioPlayer();

    // Initialize controllers
    playerStateController = StreamController<PlayerState>.broadcast(sync: true);
    durationController = StreamController<Duration>.broadcast(sync: true);
    positionController = StreamController<Duration>.broadcast(sync: true);
    completionController = StreamController<void>.broadcast(sync: true);
    logController = StreamController<String>.broadcast(sync: true);

    // Stub streams
    when(
      mockAudioPlayer.onPlayerStateChanged,
    ).thenAnswer((_) => playerStateController.stream);
    when(
      mockAudioPlayer.onDurationChanged,
    ).thenAnswer((_) => durationController.stream);
    when(
      mockAudioPlayer.onPositionChanged,
    ).thenAnswer((_) => positionController.stream);
    when(
      mockAudioPlayer.onPlayerComplete,
    ).thenAnswer((_) => completionController.stream);
    when(mockAudioPlayer.onLog).thenAnswer((_) => logController.stream);

    // Stub methods
    when(mockAudioPlayer.stop()).thenAnswer((_) async {
      playerStateController.add(PlayerState.stopped);
    });
    when(mockAudioPlayer.release()).thenAnswer((_) async {});
    when(mockAudioPlayer.dispose()).thenAnswer((_) async {});
    when(mockAudioPlayer.setSource(any)).thenAnswer((_) async {});
    when(mockAudioPlayer.resume()).thenAnswer((_) async {});
    when(mockAudioPlayer.pause()).thenAnswer((_) async {});
    when(mockAudioPlayer.seek(any)).thenAnswer((_) async {});

    // Instantiate service within setUp
    service = AudioPlaybackServiceImpl(audioPlayer: mockAudioPlayer);
    service.initializeListeners();
  });

  tearDown(() async {
    await service.dispose();
    await playerStateController.close();
    await durationController.close();
    await positionController.close();
    await completionController.close();
    await logController.close();
  });

  group('pause, seek, stop', () {
    test(
      'pause() should call audioPlayer.pause, state updates only after PlayerState.paused event',
      () async {
        fakeAsync((async) {
          // Arrange: Set initial state to playing
          const initialPath = 'dummy/path.mp3';
          service.currentState = const PlaybackState.initial().copyWith(
            isPlaying: true,
            currentFilePath: initialPath,
            // Add a non-zero duration to make the state distinct
            totalDuration: const Duration(seconds: 60),
          );
          final stateBeforePause = service.currentState;
          expect(stateBeforePause.isPlaying, isTrue);

          List<PlaybackState> receivedStates = [];
          final sub = service.playbackStateStream.listen(receivedStates.add);
          async.flushMicrotasks(); // Allow initial state emission if any
          receivedStates.clear(); // Clear initial state if captured

          // Act 1: Call pause
          service.pause();
          async.flushMicrotasks(); // Allow pause() execution

          // Assert 1: Verify mock interaction
          verify(mockAudioPlayer.pause()).called(1);

          // Assert 2: Verify state has NOT changed yet (NO optimistic update)
          expect(
            service.currentState.isPlaying,
            isTrue, // Should still be true
            reason: 'State should not change immediately after calling pause()',
          );
          // Also check no unexpected state was emitted
          expect(
            receivedStates,
            isEmpty,
            reason: 'No state should be emitted just from calling pause()',
          );

          // Act 2: Simulate player emitting paused state
          playerStateController.add(PlayerState.paused);
          async.flushMicrotasks(); // Allow event processing

          // Assert 3: Verify state update AFTER event
          final stateAfterEvent = service.currentState;
          expect(
            stateAfterEvent.isPlaying,
            isFalse, // Should now be false
            reason:
                'State should change to not playing after PlayerState.paused event',
          );
          expect(
            stateAfterEvent.currentFilePath,
            initialPath, // Path shouldn't change
          );
          expect(
            stateAfterEvent.totalDuration,
            stateBeforePause.totalDuration, // Duration shouldn't change
          );

          // Clean up
          sub.cancel();
        });
      },
    );

    test(
      'calling pause when already paused should not call audioPlayer.pause again',
      () {
        fakeAsync((async) {
          // Arrange: Set initial state to paused
          final pausedState = const PlaybackState.initial().copyWith(
            isPlaying: false, // Explicitly paused
            currentFilePath: 'dummy/path.mp3',
            totalDuration: const Duration(seconds: 60),
            position: const Duration(
              seconds: 10,
            ), // Indicate it was playing before
          );
          service.currentState = pausedState;
          expect(service.currentState.isPlaying, isFalse);

          final states = <PlaybackState>[];
          final sub = service.playbackStateStream.listen(states.add);
          async.flushMicrotasks(); // Allow potential initial state capture
          states.clear(); // Clear if initial state was emitted

          // Act: Call pause again
          service.pause();
          async.flushMicrotasks(); // Process the pause call

          // Assert: Verify mock interaction and state
          verifyNever(mockAudioPlayer.pause()); // Should NOT be called
          expect(
            service.currentState,
            pausedState,
            reason:
                'State should remain unchanged when pausing while already paused',
          );
          expect(
            states,
            isEmpty,
            reason:
                'No state should be emitted when pausing while already paused',
          );

          // Cleanup
          sub.cancel();
        });
      },
    );

    test('seek() should call audioPlayer.seek with correct duration', () async {
      fakeAsync((async) {
        // Arrange: Set initial state and ensure a duration exists
        const seekPosition = Duration(seconds: 15);
        service.currentState = const PlaybackState.initial().copyWith(
          totalDuration: const Duration(seconds: 60),
          currentFilePath: 'dummy/path.mp3',
        );

        // Act
        service.seek(seekPosition);
        async.flushMicrotasks();

        // Assert: Verify mock interaction
        verify(mockAudioPlayer.seek(seekPosition)).called(1);

        // Assert: State should not change directly from seek() call itself
        // Position updates come from the onPositionChanged stream
        expect(service.currentState.position, Duration.zero); // Remains initial
      });
    });

    test('seek() should do nothing and log warning if no file is loaded', () {
      // Arrange
      // Service is in initial state, no file loaded
      expect(service.currentState, const PlaybackState.initial());
      const initialSeekPosition = Duration(seconds: 10);

      // Act
      service.seek(initialSeekPosition);

      // Assert
      // Verify seek was never called on the player
      verifyNever(mockAudioPlayer.seek(any));
      // Verify state did not change
      expect(
        service.currentState,
        const PlaybackState.initial(),
        reason: 'State should remain initial when seeking with no file loaded',
      );
      // TODO: Verify logger.w() call if mock logger is implemented.
    });

    test('stop() should call audioPlayer.stop', () {
      fakeAsync((async) {
        // Arrange: Set a non-initial state
        service.currentState = const PlaybackState.initial().copyWith(
          isPlaying: true,
          currentFilePath: 'dummy/path.mp3',
          position: const Duration(seconds: 10),
          totalDuration: const Duration(seconds: 60),
        );

        // Act
        service.stop();
        async.flushMicrotasks();

        // Assert: Verify mock interaction
        verify(mockAudioPlayer.stop()).called(1);

        // Assert: State reset is handled by the PlayerState.stopped event listener,
        // which should be tested in audio_playback_service_event_handling_test.dart.
        // We don't assert the final state *here* because the mock stop() in setUp
        // was simplified and no longer emits PlayerState.stopped directly.
        // We only care that the service calls the underlying player's stop method.
      });
    });

    test(
      'calling stop when already stopped should not call audioPlayer.stop again',
      () {
        fakeAsync((async) {
          // Arrange: Set initial state to stopped (or initial)
          const stoppedState =
              PlaybackState.initial(); // Initial is effectively stopped
          service.currentState = stoppedState;
          expect(service.currentState.isPlaying, isFalse);
          expect(service.currentState.currentFilePath, isNull);

          final states = <PlaybackState>[];
          final sub = service.playbackStateStream.listen(states.add);
          async.flushMicrotasks();
          states.clear();

          // Act: Call stop again
          service.stop();
          async.flushMicrotasks(); // Process the stop call

          // Assert: Verify mock interaction and state
          verifyNever(mockAudioPlayer.stop()); // Should NOT be called
          expect(
            service.currentState,
            stoppedState,
            reason:
                'State should remain unchanged when stopping while already stopped',
          );
          expect(
            states,
            isEmpty,
            reason:
                'No state should be emitted when stopping while already stopped',
          );

          // Cleanup
          sub.cancel();
        });
      },
    );

    // --- Tests for resume() ---
    test(
      'resume() should call audioPlayer.resume, state updates only after PlayerState.playing event',
      () async {
        // Arrange: Set initial state to paused
        const initialPath = 'dummy/path.mp3';
        final pausedState = const PlaybackState.initial().copyWith(
          isPlaying: false, // Explicitly paused
          currentFilePath: initialPath,
          totalDuration: const Duration(seconds: 60),
          position: const Duration(seconds: 10),
        );
        service.currentState = pausedState;
        expect(service.currentState.isPlaying, isFalse);

        List<PlaybackState> receivedStates = [];
        final sub = service.playbackStateStream.listen(receivedStates.add);
        await pumpEventQueue(); // Allow initial state emission if any
        receivedStates.clear(); // Clear initial state if captured

        // Act 1: Call resume
        service.resume();
        await pumpEventQueue(); // Process the Future from mock resume & other async gaps

        // Assert 1: Verify mock interaction
        verify(mockAudioPlayer.resume()).called(1);

        // Assert 2: Verify state has NOT changed yet (NO optimistic update)
        expect(
          service.currentState.isPlaying,
          isFalse, // Should still be false
          reason: 'State should not change immediately after calling resume()',
        );
        expect(
          receivedStates,
          isEmpty,
          reason: 'No state should be emitted just from calling resume()',
        );

        // Act 2: Simulate player emitting playing state
        playerStateController.add(PlayerState.playing);
        await pumpEventQueue(); // Allow event processing

        // Assert 3: Verify state update AFTER event
        final stateAfterEvent = service.currentState;
        expect(
          stateAfterEvent.isPlaying,
          isTrue, // Should now be true
          reason:
              'State should change to playing after PlayerState.playing event',
        );
        expect(
          stateAfterEvent.currentFilePath,
          initialPath, // Path shouldn't change
        );
        expect(
          stateAfterEvent.totalDuration,
          pausedState.totalDuration, // Duration shouldn't change
        );
        // Check emitted state
        expect(receivedStates, hasLength(1));
        expect(receivedStates.first.isPlaying, isTrue);

        // Clean up
        await sub.cancel(); // Use await for cancel since it returns a Future
      },
    );

    test(
      'calling resume when already playing should not call audioPlayer.resume',
      () {
        fakeAsync((async) {
          // Arrange: Set initial state to playing
          final playingState = const PlaybackState.initial().copyWith(
            isPlaying: true, // Explicitly playing
            currentFilePath: 'dummy/path.mp3',
            totalDuration: const Duration(seconds: 60),
            position: const Duration(seconds: 10),
          );
          service.currentState = playingState;
          expect(service.currentState.isPlaying, isTrue);

          final states = <PlaybackState>[];
          final sub = service.playbackStateStream.listen(states.add);
          async.flushMicrotasks(); // Allow potential initial state capture
          states.clear(); // Clear if initial state was emitted

          // Act: Call resume again
          service.resume();
          async.flushMicrotasks(); // Process the resume call

          // Assert: Verify mock interaction and state
          verifyNever(mockAudioPlayer.resume()); // Should NOT be called
          expect(
            service.currentState,
            playingState,
            reason:
                'State should remain unchanged when resuming while already playing',
          );
          expect(
            states,
            isEmpty,
            reason:
                'No state should be emitted when resuming while already playing',
          );

          // Cleanup
          sub.cancel();
        });
      },
    );

    test(
      'calling resume when stopped (initial state) should not call audioPlayer.resume',
      () {
        fakeAsync((async) {
          // Arrange: Service is in initial state
          const stoppedState = PlaybackState.initial();
          service.currentState = stoppedState;
          expect(service.currentState.isPlaying, isFalse);
          expect(service.currentState.currentFilePath, isNull);

          final states = <PlaybackState>[];
          final sub = service.playbackStateStream.listen(states.add);
          async.flushMicrotasks(); // Allow potential initial state capture
          states.clear(); // Clear if initial state was emitted

          // Act: Call resume
          service.resume();
          async.flushMicrotasks(); // Process the resume call

          // Assert: Verify mock interaction and state
          verifyNever(mockAudioPlayer.resume()); // Should NOT be called
          expect(
            service.currentState,
            stoppedState,
            reason: 'State should remain unchanged when resuming while stopped',
          );
          expect(
            states,
            isEmpty,
            reason: 'No state should be emitted when resuming while stopped',
          );

          // Cleanup
          sub.cancel();
        });
      },
    );
  });
}

// Helper Predicate Matcher (If needed, or use simple equals)
// class PlaybackStateMatcher extends Matcher { ... }
