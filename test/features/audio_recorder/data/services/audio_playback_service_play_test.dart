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

// Import the generated mocks
import 'audio_playback_service_impl_test.mocks.dart';

// Annotation to generate MockAudioPlayer (can be here or in a shared file)
@GenerateMocks([AudioPlayer])
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

    // Use plain 'test' instead of 'testWidgets'
    test(
      'should call setSource and resume on AudioPlayer for device file',
      () async {
        // Arrange: Service is set up in setUp

        // Act
        await service.play(tFilePathDevice);
        // Allow microtasks to complete
        await Future.delayed(Duration.zero);

        // Assert
        final captured =
            verify(mockAudioPlayer.setSource(captureAny)).captured.single
                as Source;
        expect(captured, isA<DeviceFileSource>());
        expect((captured as DeviceFileSource).path, tFilePathDevice);
        verify(mockAudioPlayer.resume()).called(1);
      },
    );

    test(
      'should call setSource and resume on AudioPlayer for asset file',
      () async {
        // Arrange: Service is set up in setUp

        // Act
        await service.play(tFilePathAsset);
        await Future.delayed(Duration.zero);

        // Assert
        final captured =
            verify(mockAudioPlayer.setSource(captureAny)).captured.single
                as Source;
        expect(captured, isA<AssetSource>());
        expect((captured as AssetSource).path, tFilePathAsset);
        verify(mockAudioPlayer.resume()).called(1);
      },
    );

    test('should emit loading state then playing state on successful play', () async {
      // Make test async for expectLater
      // Use fakeAsync to control time and microtasks precisely
      fakeAsync((async) {
        // Arrange: Service is set up in setUp

        // 1. Verify initial state synchronously after setup
        expect(service.currentState, const PlaybackState.initial());

        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async
            .flushMicrotasks(); // Process any initial events *after* subscription (though unlikely with broadcast)

        const expectedLoadingState = PlaybackState(
          currentFilePath: tFilePathDevice,
          isLoading: true,
          isPlaying: false,
          isCompleted: false,
          hasError: false,
          position: Duration.zero,
          totalDuration: Duration.zero,
        );
        const expectedPlayingState = PlaybackState(
          currentFilePath: tFilePathDevice,
          isLoading: false,
          isPlaying: true,
          isCompleted: false,
          hasError: false,
          position: Duration.zero,
          totalDuration: Duration.zero,
        );

        // Act
        service.play(tFilePathDevice);
        async.flushMicrotasks(); // Process loading state emission

        playerStateController.add(PlayerState.playing);
        async.flushMicrotasks(); // Process playing state emission

        // Assert state sequence using expectLater with emitsInOrder
        // Only expect states *after* the initial one, as the listener missed it
        expectLater(
          Stream.fromIterable(states), // Use collected states
          emitsInOrder([
            // const PlaybackState.initial(), // DO NOT expect initial state here
            expectedLoadingState, // Expect Loading
            expectedPlayingState, // Expect Playing
          ]),
        );

        // Elapse time to ensure expectLater completes
        async.elapse(Duration.zero);

        sub.cancel();
      });
    });

    test('should call stop before playing a new file if already playing', () {
      fakeAsync((async) {
        // Arrange: Use a separate controller for fine-grained state control in this test
        final localPlayerStateController =
            StreamController<PlayerState>.broadcast(
              sync: true,
            ); // Use sync for fakeAsync
        when(
          mockAudioPlayer.onPlayerStateChanged,
        ).thenAnswer((_) => localPlayerStateController.stream);
        when(mockAudioPlayer.stop()).thenAnswer((_) async {
          if (!localPlayerStateController.isClosed) {
            localPlayerStateController.add(PlayerState.stopped);
          }
        });
        when(mockAudioPlayer.setSource(any)).thenAnswer((_) async {});
        when(mockAudioPlayer.resume()).thenAnswer((_) async {});
        when(mockAudioPlayer.play(any)).thenAnswer((_) async {});
        when(mockAudioPlayer.pause()).thenAnswer((_) async {});
        when(mockAudioPlayer.seek(any)).thenAnswer((_) async {});

        // Re-initialize service with the specific controller for this test
        // Note: This might conflict with the global setUp service instance if not careful.
        // Let's stick with the global one for now and see if it works.
        // service = AudioPlaybackServiceImpl(audioPlayer: mockAudioPlayer);
        // service.initializeListeners(); // Already done in global setUp

        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async
            .flushMicrotasks(); // Ensure initial state is processed if stream was lazy

        // Act 1: Play first file and force playing state
        service.play(tFilePathAsset);
        async.flushMicrotasks(); // Process loading state
        localPlayerStateController.add(PlayerState.playing);
        async.flushMicrotasks(); // Process playing state

        // Reset interactions ONLY for the mock player before the second action
        clearInteractions(mockAudioPlayer);
        // Re-stub methods that will be called by the second play action
        when(mockAudioPlayer.setSource(any)).thenAnswer((_) async {});
        when(mockAudioPlayer.resume()).thenAnswer((_) async {});
        when(mockAudioPlayer.stop()).thenAnswer((_) async {
          if (!localPlayerStateController.isClosed) {
            localPlayerStateController.add(PlayerState.stopped);
          }
        });

        // Act 2: Play second file
        service.play(tFilePathDevice);
        async.flushMicrotasks(); // Process stop, reset, loading etc.

        // Assert
        verify(mockAudioPlayer.stop()).called(1);
        verify(mockAudioPlayer.setSource(captureAny)).called(1);
        verify(mockAudioPlayer.resume()).called(1);

        // Clean up
        localPlayerStateController.close();
        sub.cancel();
      });
    });

    test('should emit error state if setSource throws', () {
      fakeAsync((async) {
        // Arrange: Service is set up in setUp
        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks(); // Process initial state

        final exception = Exception('Failed to set source');
        when(mockAudioPlayer.setSource(any)).thenThrow(exception);
        // Ensure stop is stubbed for the error handler
        when(mockAudioPlayer.stop()).thenAnswer((_) async {});

        // Act
        service.play(tFilePathDevice);
        // Allow play() and subsequent error handling to complete
        async.flushMicrotasks();

        // Assert
        expect(
          states.last, // Check the final state after error handling
          isA<PlaybackState>()
              .having((s) => s.isLoading, 'isLoading', false)
              .having((s) => s.hasError, 'hasError', true)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('Failed to set source'),
              ), // Use contains
        );
        verifyNever(mockAudioPlayer.resume());
        verify(
          mockAudioPlayer.stop(),
        ).called(1); // Stop should be called by error handler

        sub.cancel();
      });
    });

    test('should emit error state if resume throws', () {
      fakeAsync((async) {
        // Arrange: Service is set up in setUp
        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks(); // Process initial state

        final exception = Exception('Failed to resume');
        // setSource succeeds, resume throws
        when(mockAudioPlayer.setSource(any)).thenAnswer((_) async {});
        when(mockAudioPlayer.resume()).thenThrow(exception);
        // Ensure stop is stubbed for the error handler
        when(mockAudioPlayer.stop()).thenAnswer((_) async {});

        // Act
        service.play(tFilePathDevice);
        // Allow play() and subsequent error handling to complete
        async.flushMicrotasks();

        // Assert
        expect(
          states.last,
          isA<PlaybackState>()
              .having(
                (s) => s.isLoading,
                'isLoading',
                false,
              ) // Should not be loading anymore
              .having((s) => s.hasError, 'hasError', true)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('Failed to resume'),
              ), // Use contains
        );
        verify(mockAudioPlayer.setSource(any)).called(1);
        verify(
          mockAudioPlayer.resume(),
        ).called(1); // Resume was called, but threw
        verify(
          mockAudioPlayer.stop(),
        ).called(1); // Stop should be called by error handler

        sub.cancel();
      });
    });
  });
}
