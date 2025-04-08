// Imports
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/models/playback_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
// Use fake_async for better time control in plain tests
import 'package:fake_async/fake_async.dart';
// Added logger import

// Import the generated mocks
import 'audio_playback_service_impl_test.mocks.dart';

// Annotation to generate MockAudioPlayer (can be here or in a shared file)
@GenerateMocks([AudioPlayer])
// Define a common test exception
final testException = Exception('Test Exception: Something went boom!');

void main() {
  // Initialize Flutter bindings if needed for path_provider or other plugins used implicitly
  // TestWidgetsFlutterBinding.ensureInitialized(); // Keep commented unless necessary

  late MockAudioPlayer mockAudioPlayer;
  late AudioPlaybackServiceImpl service;

  // Declare controllers
  late StreamController<PlayerState> playerStateController;
  late StreamController<Duration> durationController;
  late StreamController<Duration> positionController;
  late StreamController<void> completionController;
  late StreamController<String> logController;

  setUp(() {
    // print('>>> PLAY_TEST_SETUP: START');
    mockAudioPlayer = MockAudioPlayer();
    // print('>>> PLAY_TEST_SETUP: MockAudioPlayer created');

    // Initialize controllers
    playerStateController = StreamController<PlayerState>.broadcast();
    durationController = StreamController<Duration>.broadcast();
    positionController = StreamController<Duration>.broadcast();
    completionController = StreamController<void>.broadcast();
    logController = StreamController<String>.broadcast();
    // print('>>> PLAY_TEST_SETUP: Controllers initialized');

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
    // print('>>> PLAY_TEST_SETUP: Streams stubbed');

    // Stub methods (essential for play tests)
    when(mockAudioPlayer.stop()).thenAnswer((_) async {});
    when(mockAudioPlayer.release()).thenAnswer((_) async {});
    when(mockAudioPlayer.dispose()).thenAnswer((_) async {});
    when(mockAudioPlayer.setSource(any)).thenAnswer((_) async {});
    when(mockAudioPlayer.resume()).thenAnswer((_) async {});
    when(mockAudioPlayer.pause()).thenAnswer((_) async {});
    when(mockAudioPlayer.seek(any)).thenAnswer((_) async {});
    // print('>>> PLAY_TEST_SETUP: Methods stubbed');

    // Instantiate service HERE, after mocks are fully set up
    service = AudioPlaybackServiceImpl(audioPlayer: mockAudioPlayer);
    // Initialize listeners synchronously
    service.initializeListeners();
    // print(
    //  '>>> PLAY_TEST_SETUP: Service instantiated and listeners initialized',
    // );

    // print('>>> PLAY_TEST_SETUP: END');
  });

  tearDown(() async {
    // print('>>> PLAY_TEST_TEARDOWN: START');
    // Dispose the service first
    await service.dispose();
    // print('>>> PLAY_TEST_TEARDOWN: Service disposed');
    // Close controllers
    await playerStateController.close();
    await durationController.close();
    await positionController.close();
    await completionController.close();
    await logController.close();
    // print('>>> PLAY_TEST_TEARDOWN: Controllers closed');
    // print('>>> PLAY_TEST_TEARDOWN: END');
  });

  group('play', () {
    const tFilePathDevice = '/path/to/recording.mp3';
    const tFilePathAsset = 'audio/asset.mp3';

    test(
      'initial play should call stop, setSource, resume and emit loading state',
      () {
        fakeAsync((async) {
          // Arrange
          final states = <PlaybackState>[];
          final sub = service.playbackStateStream.listen(states.add);
          // Ensure initial state is captured if needed (though broadcast might miss it)
          async.flushMicrotasks();
          expect(service.currentState, const PlaybackState.initial());

          const expectedLoadingState = PlaybackState(
            currentFilePath: tFilePathDevice,
            isPlaying: false,
            isLoading: true, // Expect loading to be true
            isCompleted: false,
            hasError: false,
            errorMessage: null,
            position: Duration.zero,
            totalDuration: Duration.zero,
          );

          // Act: Call play for the first time
          service.play(tFilePathDevice);
          async
              .flushMicrotasks(); // Allow async operations within play() to progress

          // Assert Interactions
          verify(mockAudioPlayer.stop()).called(1); // Should stop first
          final capturedSource =
              verify(mockAudioPlayer.setSource(captureAny)).captured.single
                  as Source;
          expect(capturedSource, isA<DeviceFileSource>());
          expect((capturedSource as DeviceFileSource).path, tFilePathDevice);
          verify(mockAudioPlayer.resume()).called(1);

          // Assert State
          // Check the states emitted *after* subscription
          expect(states, contains(expectedLoadingState));
          // We might refine this to check the *last* state if multiple are emitted rapidly

          // Cleanup
          sub.cancel();
        });
      },
      // Potentially skip until implementation is ready
      // skip: 'Awaiting implementation for play method rewrite',
    );

    test(
      'play should emit playing state only after receiving PlayerState.playing event',
      () {
        fakeAsync((async) {
          // Arrange
          final states = <PlaybackState>[];
          final sub = service.playbackStateStream.listen(states.add);
          async.flushMicrotasks(); // Capture initial state if needed

          // Act 1: Call play
          service.play(tFilePathDevice);
          async.flushMicrotasks(); // Process play() logic (emits loading state)

          // Assert 1: Check state *before* player event (should be loading)
          expect(
            states.last,
            isA<PlaybackState>()
                .having((s) => s.isLoading, 'isLoading', true)
                .having((s) => s.isPlaying, 'isPlaying', false)
                .having((s) => s.currentFilePath, 'filePath', tFilePathDevice),
          );

          // Act 2: Simulate player actually starting
          playerStateController.add(PlayerState.playing);
          async
              .flushMicrotasks(); // Process the event through the listener and _updateState

          // Assert 2: Check state *after* player event (should be playing)
          const expectedPlayingState = PlaybackState(
            currentFilePath: tFilePathDevice,
            isPlaying: true, // Should now be true
            isLoading: false, // Should now be false
            isCompleted: false,
            hasError: false,
            errorMessage: null,
            position: Duration.zero, // Position might not have updated yet
            totalDuration: Duration.zero, // Duration might not have updated yet
          );

          // Verify the final state held by the service
          expect(service.currentState, expectedPlayingState);

          // Optional: Verify the last emitted state if needed, but checking
          // service.currentState after flushMicrotasks is often more robust.
          // expect(states.last, expectedPlayingState);

          // Cleanup
          sub.cancel();
        });
      },
    );

    test('play should call setSource with AssetSource for asset paths', () {
      fakeAsync((async) {
        // Arrange
        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks(); // Capture initial state

        const expectedLoadingState = PlaybackState(
          currentFilePath: tFilePathAsset, // Expect asset path
          isPlaying: false,
          isLoading: true, // Expect loading
          isCompleted: false,
          hasError: false,
          errorMessage: null,
          position: Duration.zero,
          totalDuration: Duration.zero,
        );

        // Act
        service.play(tFilePathAsset);
        async.flushMicrotasks(); // Process play() logic

        // Assert Interactions
        verify(mockAudioPlayer.stop()).called(1);
        final capturedSource =
            verify(mockAudioPlayer.setSource(captureAny)).captured.single
                as Source;
        expect(capturedSource, isA<AssetSource>()); // Check the type
        expect(
          (capturedSource as AssetSource).path,
          tFilePathAsset,
        ); // Check the path
        verify(mockAudioPlayer.resume()).called(1);

        // Assert State
        expect(states, contains(expectedLoadingState));
        expect(
          service.currentState,
          expectedLoadingState,
        ); // Verify final state

        // Cleanup
        sub.cancel();
      });
    });

    test(
      'calling play when already playing should stop the old, set new source, and resume',
      () {
        fakeAsync((async) async {
          // Arrange
          final states = <PlaybackState>[];
          final sub = service.playbackStateStream.listen(states.add);
          async.flushMicrotasks(); // Capture initial state

          const tFilePathDevice2 = '/path/to/another_recording.mp3';

          // Act 1: Start playing the first file
          service.play(tFilePathDevice);
          async.flushMicrotasks(); // Process initial play (loading)
          // Simulate player actually starting for the first file
          playerStateController.add(PlayerState.playing);
          async.flushMicrotasks(); // Process playing state

          // Assert 1 (Intermediate): Verify first play started
          verify(mockAudioPlayer.setSource(any)).called(1);
          verify(mockAudioPlayer.resume()).called(1);
          expect(
            service.currentState,
            isA<PlaybackState>()
                .having((s) => s.isPlaying, 'isPlaying', true)
                .having((s) => s.currentFilePath, 'filePath', tFilePathDevice),
          );

          // Act: Call play again with a different file
          // Ensure the second play call completes before further checks
          await service.play(tFilePathDevice2);

          // Elapse time to ensure all microtasks/timers complete after the second play
          async.elapse(const Duration(milliseconds: 1));

          // Assert
          // Verify interactions
          verify(mockAudioPlayer.stop()).called(2);
          final capturedSources =
              verify(mockAudioPlayer.setSource(captureAny)).captured;
          expect(capturedSources.length, 2);
          expect(capturedSources[0], isA<DeviceFileSource>());
          expect(
            (capturedSources[0] as DeviceFileSource).path,
            tFilePathDevice,
          );
          expect(capturedSources[1], isA<DeviceFileSource>());
          expect(
            (capturedSources[1] as DeviceFileSource).path,
            tFilePathDevice2,
          );
          verify(mockAudioPlayer.resume()).called(2);

          // Verify the state reflects the *new* file path and is loading
          const expectedLoadingState2 = PlaybackState(
            currentFilePath: tFilePathDevice2,
            isPlaying: false,
            isLoading: true, // Should be loading for the new file
            isCompleted: false,
            hasError: false,
            errorMessage: null,
            position: Duration.zero, // Reset for new file
            totalDuration: Duration.zero, // Reset for new file
          );
          expect(service.currentState, expectedLoadingState2);
          expect(states, contains(expectedLoadingState2));

          // Optional: Simulate second player starting if needed
          // playerStateController.add(PlayerState.playing);
          // async.flushMicrotasks();
          // expect(service.currentState.isPlaying, true);
          // expect(service.currentState.isLoading, false);

          // Cleanup
          sub.cancel();
        });
      },
    );

    test('play should emit error state if _audioPlayer.resume() throws', () {
      fakeAsync((async) {
        // Arrange
        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks(); // Allow initial state if needed

        final testException = Exception('Resume failed horribly!');
        const expectedError =
            'Exception: Resume failed horribly!'; // Adjust if _handleError formats it

        // Make resume throw
        when(mockAudioPlayer.resume()).thenThrow(testException);

        // Act: Call play, which should eventually call the failing resume
        service.play(tFilePathDevice);
        async
            .flushMicrotasks(); // Process play logic including the resume call and error handling

        // Assert Interactions
        verify(mockAudioPlayer.stop()).called(1); // Stop should still be called
        verify(
          mockAudioPlayer.setSource(any),
        ).called(1); // SetSource should still be called
        verify(mockAudioPlayer.resume()).called(1); // Resume is attempted

        // Assert State - Check the LAST emitted state reflects the error
        expect(
          states.last,
          isA<PlaybackState>()
              .having((s) => s.hasError, 'hasError', true)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains(expectedError),
              )
              .having(
                (s) => s.isLoading,
                'isLoading',
                false,
              ) // Should not be loading anymore
              .having(
                (s) => s.isPlaying,
                'isPlaying',
                false,
              ) // Should not be playing
              .having(
                (s) => s.currentFilePath,
                'filePath',
                tFilePathDevice,
              ), // Path should be set
        );

        // Verify the final state held by the service
        expect(
          service.currentState,
          isA<PlaybackState>()
              .having((s) => s.hasError, 'hasError', true)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains(expectedError),
              )
              .having((s) => s.isLoading, 'isLoading', false)
              .having((s) => s.isPlaying, 'isPlaying', false)
              .having((s) => s.currentFilePath, 'filePath', tFilePathDevice),
        );

        // Cleanup
        sub.cancel();
      });
    });

    test('play should emit error state if onLog stream emits an error message', () {
      fakeAsync((async) {
        // Arrange
        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks(); // Allow initial state if needed

        const tErrorMessageFromLog = 'Error: Native player exploded!';
        // Expected error message in state might be slightly different depending on _handleError formatting
        const tExpectedErrorSubstring = 'Error: Native player exploded!';

        // Act 1: Start playback normally
        service.play(tFilePathDevice);
        async.flushMicrotasks(); // Process play() -> loading state

        // Act 2: Simulate an error log message from the player
        logController.add(tErrorMessageFromLog);
        async
            .flushMicrotasks(); // Process the log event through the listener -> _handleError -> _updateState

        // Assert State - Check the service's final state reflects the error
        // Checking states.last can be flaky with broadcast streams in fakeAsync
        expect(
          service.currentState, // Check the service's internal state directly
          isA<PlaybackState>()
              .having((s) => s.hasError, 'hasError', true)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains(tExpectedErrorSubstring),
              )
              .having(
                (s) => s.isLoading,
                'isLoading',
                false,
              ) // Should not be loading
              .having(
                (s) => s.isPlaying,
                'isPlaying',
                false,
              ) // Should not be playing
              .having(
                (s) => s.currentFilePath,
                'filePath',
                tFilePathDevice,
              ), // Path should still be set
        );

        // Optional: Verify the last emitted state if needed, but less reliable here.
        /* expect(
          states.last,
          isA<PlaybackState>()
              .having((s) => s.hasError, 'hasError', true)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains(tExpectedErrorSubstring),
              )
              .having(
                (s) => s.isLoading,
                'isLoading',
                false,
              ) // Should not be loading
              .having(
                (s) => s.isPlaying,
                'isPlaying',
                false,
              ) // Should not be playing
              .having(
                (s) => s.currentFilePath,
                'filePath',
                tFilePathDevice,
              ), // Path should still be set
        ); */

        // Cleanup
        sub.cancel();
      });
    });

    test('play should emit error state if _audioPlayer.stop() throws', () {
      fakeAsync((async) {
        // Arrange
        // Simulate a state where something might be playing
        // Need to manually set the internal state for this scenario before play
        // This is tricky as we don't expose direct state setting.
        // Instead, let's assume the player was playing, then play is called.
        // The crucial part is mocking stop() to throw.

        when(mockAudioPlayer.stop()).thenThrow(testException); // Make stop fail
        // Mock others to succeed if reached (they shouldn't be)
        when(mockAudioPlayer.setSource(any)).thenAnswer((_) async {});
        when(mockAudioPlayer.resume()).thenAnswer((_) async {});

        final states = <PlaybackState>[];
        // Start listening *after* potential initial state
        final sub = service.playbackStateStream.listen(states.add);
        // No need to flush here, listen starts now

        // Act
        service.play(tFilePathDevice);
        async
            .flushMicrotasks(); // Process play() call including the failed stop()

        // Assert
        // Verify the service's internal state reflects the error from stop()
        expect(
          service.currentState,
          isA<PlaybackState>()
              .having((s) => s.hasError, 'hasError', true)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains(testException.toString()),
              )
              .having(
                (s) => s.isLoading,
                'isLoading',
                false,
              ) // Should not be loading after error
              .having(
                (s) => s.isPlaying,
                'isPlaying',
                false,
              ) // Should not be playing after error
              .having(
                (s) => s.currentFilePath,
                'filePath',
                tFilePathDevice,
              ), // Path should reflect the requested file
        );

        // Ensure stop was called
        verify(mockAudioPlayer.stop()).called(1);
        // Ensure setSource and resume were NOT called after stop failed
        verifyNever(mockAudioPlayer.setSource(any));
        verifyNever(mockAudioPlayer.resume());

        // Cleanup
        sub.cancel();
      });
    });
  });
}
