// Imports
import 'dart:async';

// Import logger
import 'package:docjet_mobile/core/utils/logger.dart'; // Import logger explicitly
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart'
    as entity;
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Import the generated mocks
import 'audio_playback_service_play_test.mocks.dart';

// Set Logger Level to DEBUG for active development/debugging in this file
final logger = Logger(level: Level.debug);

// Annotation to generate mocks for Adapter and Mapper ONLY
@GenerateMocks([AudioPlayerAdapter, PlaybackStateMapper])
// Define a common test exception
final testException = Exception('Test Exception: Something went boom!');

void main() {
  // Set logger level to off for tests
  // setLogLevel(Level.off);

  // Add new mocks
  late MockAudioPlayerAdapter mockAudioPlayerAdapter;
  late MockPlaybackStateMapper mockPlaybackStateMapper;

  late AudioPlaybackServiceImpl service;

  // Add controller for the MAPPED state stream
  late StreamController<entity.PlaybackState> mockPlaybackStateController;

  setUp(() {
    logger.d('PLAY_TEST_SETUP: START');
    // Instantiate new mocks
    mockAudioPlayerAdapter = MockAudioPlayerAdapter();
    mockPlaybackStateMapper = MockPlaybackStateMapper();

    // Initialize the new controller WITHOUT sync: true
    mockPlaybackStateController =
        StreamController<entity.PlaybackState>.broadcast();

    // Stub the mapper's stream to return our controlled stream
    when(
      mockPlaybackStateMapper.playbackStateStream,
    ).thenAnswer((_) => mockPlaybackStateController.stream);

    when(mockPlaybackStateMapper.dispose()).thenReturn(null);

    // Stub adapter methods using Future.value() for void returns
    when(mockAudioPlayerAdapter.stop()).thenAnswer((_) => Future.value());
    when(mockAudioPlayerAdapter.dispose()).thenAnswer((_) => Future.value());
    when(
      mockAudioPlayerAdapter.setSourceUrl(any),
    ).thenAnswer((_) => Future.value());
    when(mockAudioPlayerAdapter.resume()).thenAnswer((_) => Future.value());
    when(mockAudioPlayerAdapter.pause()).thenAnswer((_) => Future.value());
    when(
      mockAudioPlayerAdapter.seek(any, any),
    ).thenAnswer((_) => Future.value());

    // Stub adapter streams (return empty streams for these tests)
    when(
      mockAudioPlayerAdapter.onPlayerStateChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(
      mockAudioPlayerAdapter.onDurationChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(
      mockAudioPlayerAdapter.onPositionChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(
      mockAudioPlayerAdapter.onPlayerComplete,
    ).thenAnswer((_) => const Stream.empty());

    // Instantiate service with NEW mocks
    service = AudioPlaybackServiceImpl(
      audioPlayerAdapter: mockAudioPlayerAdapter,
      playbackStateMapper: mockPlaybackStateMapper,
    );

    logger.d('PLAY_TEST_SETUP: END');
  });

  tearDown(() async {
    logger.d('PLAY_TEST_TEARDOWN: START');
    // Dispose the service first
    await service.dispose();
    logger.d('PLAY_TEST_TEARDOWN: Service disposed');
    // Close the new controller
    await mockPlaybackStateController.close();
    logger.d('PLAY_TEST_TEARDOWN: Controllers closed');
    logger.d('PLAY_TEST_TEARDOWN: END');
  });

  group('play', () {
    const tFilePathDevice = '/path/to/recording.mp3';
    const tFilePathAsset =
        'assets/audio/asset.mp3'; // Assume assets path convention

    test(
      'initial play should call adapter.setSourceUrl, adapter.resume and emit loading then playing state',
      () async {
        logger.d('TEST [initial play]: START');
        // Arrange
        logger.d('TEST [initial play]: Arranging...');
        const expectedLoadingState = entity.PlaybackState.loading();
        const expectedPlayingState = entity.PlaybackState.playing(
          currentPosition: Duration.zero, // Assume initial
          totalDuration: Duration.zero, // Assume initial
        );

        // **DEBUG: Log all emitted states**
        final emittedStates = <entity.PlaybackState>[];
        final debugSubscription = service.playbackStateStream.listen((state) {
          logger.d('*** DEBUG: State Emitted: $state');
          emittedStates.add(state);
        });

        try {
          // Act 1: Call play, AWAIT it now that we are not in fakeAsync
          logger.d('TEST [initial play]: Calling service.play (awaiting)...');
          await service.play(tFilePathDevice);
          logger.d('TEST [initial play]: service.play called (awaiting).');
          // Yield to allow stream processing after service call completes
          await Future.delayed(Duration.zero);
          logger.d('TEST [initial play]: >> After delay post-play');

          // Assert Interactions AFTER await
          logger.d('TEST [initial play]: Verifying adapter calls...');
          verify(mockAudioPlayerAdapter.stop()).called(1);
          verify(
            mockAudioPlayerAdapter.setSourceUrl(tFilePathDevice),
          ).called(1);
          verify(mockAudioPlayerAdapter.resume()).called(1);
          logger.d('TEST [initial play]: Adapter calls verified.');

          // Act 2: Simulate mapper emitting the loading state FIRST
          logger.d(
            'TEST [initial play]: Adding loading state to controller...',
          );
          mockPlaybackStateController.add(expectedLoadingState);
          logger.d('TEST [initial play]: >> After adding LOADING state');
          // Yield AGAIN immediately after adding to controller
          await Future.delayed(Duration.zero);
          logger.d('TEST [initial play]: >> After SECOND delay post-LOADING');

          // Act 3: Simulate mapper emitting the final state
          logger.d(
            'TEST [initial play]: Adding playing state to controller...',
          );
          mockPlaybackStateController.add(expectedPlayingState);
          logger.d('TEST [initial play]: >> After adding PLAYING state');
          // Yield AGAIN immediately after adding to controller
          await Future.delayed(Duration.zero);
          logger.d('TEST [initial play]: >> After THIRD delay post-PLAYING');

          // **Assert collected states**
          expect(
            emittedStates,
            equals([expectedLoadingState, expectedPlayingState]),
          );
          logger.d('TEST [initial play]: Asserted collected states.');
        } finally {
          // **DEBUG: Cancel subscription**
          await debugSubscription.cancel();
          logger.d('TEST [initial play]: Subscription cancelled.');
        }
        logger.d('TEST [initial play]: END');
      },
    );

    test(
      'play should emit playing state ONLY after receiving PlaybackState.playing from mapper',
      () async {
        // Arrange
        const initialExpectedState = entity.PlaybackState.initial();
        const expectedLoadingState = entity.PlaybackState.loading();
        const expectedPlayingState = entity.PlaybackState.playing(
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
        );

        // Expect initial -> initial -> loading -> playing
        final stateExpectation = expectLater(
          service.playbackStateStream,
          emitsInOrder([
            initialExpectedState, // Expect initial emitted by controller first
            expectedLoadingState,
            expectedPlayingState,
          ]),
        );

        // Ensure initial state is emitted first & processed
        mockPlaybackStateController.add(initialExpectedState);
        await Future.delayed(Duration.zero);

        // Act 1: Call play (await it)
        await service.play(tFilePathDevice);

        // Act 2: Simulate mapper emitting loading state & process
        mockPlaybackStateController.add(expectedLoadingState);
        await Future.delayed(Duration.zero);

        // Verify interactions happened before playing state
        verify(mockAudioPlayerAdapter.stop()).called(1);
        verify(mockAudioPlayerAdapter.setSourceUrl(tFilePathDevice)).called(1);
        verify(mockAudioPlayerAdapter.resume()).called(1);

        // Act 3: Simulate mapper emitting playing state & process
        mockPlaybackStateController.add(expectedPlayingState);
        await Future.delayed(Duration.zero);

        // Await the expectLater future
        await stateExpectation;
      },
    );

    test(
      'play should call adapter.setSourceUrl with asset path for assets',
      () async {
        // Arrange
        const initialExpectedState = entity.PlaybackState.initial();
        const expectedLoadingState = entity.PlaybackState.loading();
        const expectedPlayingState = entity.PlaybackState.playing(
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
        );

        final stateExpectation = expectLater(
          service.playbackStateStream,
          emitsInOrder([
            initialExpectedState,
            expectedLoadingState,
            expectedPlayingState,
          ]),
        );

        mockPlaybackStateController.add(initialExpectedState);
        await Future.delayed(Duration.zero);

        // Act
        await service.play(tFilePathAsset);

        // Simulate loading/playing from mapper
        mockPlaybackStateController.add(expectedLoadingState);
        await Future.delayed(Duration.zero);
        mockPlaybackStateController.add(expectedPlayingState);
        await Future.delayed(Duration.zero);

        // Assert Interactions
        verify(mockAudioPlayerAdapter.stop()).called(1);
        verify(mockAudioPlayerAdapter.setSourceUrl(tFilePathAsset)).called(1);
        verify(mockAudioPlayerAdapter.resume()).called(1);

        // Await the expectLater future
        await stateExpectation;
      },
    );

    test(
      'play called again with different file should call stop, setSourceUrl, resume',
      () async {
        const tFilePathDevice2 = '/path/to/other_recording.mp3';
        const initialPlayingState = entity.PlaybackState.initial();
        const playingState1 = entity.PlaybackState.playing(
          currentPosition: Duration(seconds: 10),
          totalDuration: Duration(seconds: 60),
        );
        const loadingState2 = entity.PlaybackState.loading();
        const playingState2 = entity.PlaybackState.playing(
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
        );

        // Setup state collection
        final emittedStates = <entity.PlaybackState>[];
        final subscription = service.playbackStateStream.listen((state) {
          logger.d('TEST [diff file restart]: State received: $state');
          emittedStates.add(state);
        });

        try {
          // Simulate initial state
          mockPlaybackStateController.add(initialPlayingState);
          await Future.delayed(Duration.zero);

          // Act 1: First play
          await service.play(tFilePathDevice);
          mockPlaybackStateController.add(playingState1);
          await Future.delayed(Duration.zero); // Process state 1

          // Verify first play interactions
          verify(mockAudioPlayerAdapter.stop()).called(1); // Stop for play 1
          verify(
            mockAudioPlayerAdapter.setSourceUrl(tFilePathDevice),
          ).called(1);
          verify(
            mockAudioPlayerAdapter.resume(),
          ).called(1); // Resume for play 1

          // Clear interactions before second play for cleaner verification
          clearInteractions(mockAudioPlayerAdapter);
          clearInteractions(mockPlaybackStateMapper);
          // Re-stub the essential mapper stream getter
          when(
            mockPlaybackStateMapper.playbackStateStream,
          ).thenAnswer((_) => mockPlaybackStateController.stream);

          // Act 2: Second play (different file)
          await service.play(tFilePathDevice2);

          // Simulate second play loading/playing states from mapper
          mockPlaybackStateController.add(loadingState2);
          await Future.delayed(Duration.zero);
          mockPlaybackStateController.add(playingState2);
          await Future.delayed(Duration.zero);

          // Give the stream time to propagate the state
          await Future.delayed(const Duration(milliseconds: 50));

          // Assert Interactions for second play (relative to clearInteractions)
          verify(mockAudioPlayerAdapter.stop()).called(1); // Stop for play 2
          verify(
            mockAudioPlayerAdapter.setSourceUrl(tFilePathDevice2),
          ).called(1);
          verify(
            mockAudioPlayerAdapter.resume(),
          ).called(1); // Resume for play 2

          // Assert the full sequence of collected states
          expect(
            emittedStates,
            equals([
              initialPlayingState,
              playingState1, // First play playing
              loadingState2, // Second play loading
              playingState2, // Second play playing
            ]),
            reason: 'Should emit the correct sequence of states for restart',
          );
        } finally {
          // Always clean up the subscription
          await subscription.cancel();
        }
      },
    );

    test('play should throw if adapter.resume throws', () async {
      // Arrange
      final testError = Exception('Resume failed!');
      // Stub stop, setSourceUrl to succeed, but resume to throw
      when(mockAudioPlayerAdapter.stop()).thenAnswer((_) async {});
      when(mockAudioPlayerAdapter.setSourceUrl(any)).thenAnswer((_) async {});
      when(mockAudioPlayerAdapter.resume()).thenThrow(testError);

      // Act & Assert: Use expectLater for async throws check
      await expectLater(
        service.play(tFilePathDevice),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'toString',
            contains('Resume failed!'),
          ),
        ),
      );

      // Verify interactions up to the point of failure
      verify(mockAudioPlayerAdapter.stop()).called(1);
      verify(mockAudioPlayerAdapter.setSourceUrl(tFilePathDevice)).called(1);
      verify(mockAudioPlayerAdapter.resume()).called(1); // Resume was attempted
    });

    test('play should throw if adapter.setSourceUrl throws', () async {
      // Arrange
      final testError = Exception('SetSourceUrl failed!');
      // Stub stop to succeed, but setSourceUrl to throw
      when(mockAudioPlayerAdapter.stop()).thenAnswer((_) async {});
      when(mockAudioPlayerAdapter.setSourceUrl(any)).thenThrow(testError);

      // Act & Assert: Use expectLater for async throws check
      await expectLater(
        service.play(tFilePathDevice),
        throwsA(predicate((e) => e is Exception && e == testError)),
      );

      // Verify interactions up to the point of failure
      verify(mockAudioPlayerAdapter.stop()).called(1);
      verify(mockAudioPlayerAdapter.setSourceUrl(tFilePathDevice)).called(1);
      verifyNever(
        mockAudioPlayerAdapter.resume(),
      ); // Resume should NOT be called
    });

    test(
      'play called again with same file while playing should restart (stop, setSourceUrl, resume)',
      () async {
        // Arrange: Simulate playing state
        const initialPlayingState = entity.PlaybackState.initial();
        const playingState1 = entity.PlaybackState.playing(
          currentPosition: Duration(seconds: 10),
          totalDuration: Duration(seconds: 60),
        );
        const loadingState2 = entity.PlaybackState.loading();
        const playingState2 = entity.PlaybackState.playing(
          currentPosition: Duration.zero, // Restarted
          totalDuration: Duration.zero, // Restarted
        );

        // Setup state collection
        final emittedStates = <entity.PlaybackState>[];
        final subscription = service.playbackStateStream.listen((state) {
          logger.d('TEST [same file restart]: State received: $state');
          emittedStates.add(state);
        });

        try {
          mockPlaybackStateController.add(initialPlayingState);
          await Future.delayed(Duration.zero);

          // Simulate first play
          await service.play(tFilePathDevice);
          mockPlaybackStateController.add(playingState1);
          await Future.delayed(Duration.zero); // Process state 1

          // Verify first play interactions
          verify(mockAudioPlayerAdapter.stop()).called(1);
          verify(
            mockAudioPlayerAdapter.setSourceUrl(tFilePathDevice),
          ).called(1);
          verify(mockAudioPlayerAdapter.resume()).called(1);

          // Clear interactions before second play for cleaner verification
          clearInteractions(mockAudioPlayerAdapter);
          clearInteractions(mockPlaybackStateMapper);
          // Re-stub the essential mapper stream getter
          when(
            mockPlaybackStateMapper.playbackStateStream,
          ).thenAnswer((_) => mockPlaybackStateController.stream);

          // Act: Call play again with the SAME file
          await service.play(tFilePathDevice);

          // Simulate restart loading/playing states
          mockPlaybackStateController.add(loadingState2);
          await Future.delayed(Duration.zero);
          mockPlaybackStateController.add(playingState2);
          await Future.delayed(Duration.zero);

          // Give the stream time to propagate the state
          await Future.delayed(const Duration(milliseconds: 50));

          // Assert interactions for second play (relative to clearInteractions)
          verify(
            mockAudioPlayerAdapter.stop(),
          ).called(1); // Stop called for second play
          verify(
            mockAudioPlayerAdapter.setSourceUrl(tFilePathDevice),
          ).called(1); // SetSourceUrl called for second play
          verify(
            mockAudioPlayerAdapter.resume(),
          ).called(1); // Resume called for second play

          // Assert the full sequence of collected states
          expect(
            emittedStates,
            equals([
              initialPlayingState,
              playingState1,
              loadingState2, // Loading for restart
              playingState2, // Playing after restart
            ]),
            reason: 'Should emit the correct sequence of states for restart',
          );
        } finally {
          // Always clean up the subscription
          await subscription.cancel();
        }
      },
    );

    test(
      'play called on the same file while paused should RESUME playback, not restart',
      () async {
        // Arrange
        const tFilePath = 'test/path_resume.mp3';
        const initialDuration = Duration(seconds: 60);
        const pausedPosition = Duration(seconds: 25);

        // Create states to be emitted
        const initialPlayingState = entity.PlaybackState.playing(
          currentPosition: Duration.zero,
          totalDuration: initialDuration,
        );
        const pausedState = entity.PlaybackState.paused(
          currentPosition: pausedPosition,
          totalDuration: initialDuration,
        );
        const resumedPlayingState = entity.PlaybackState.playing(
          currentPosition: pausedPosition, // Resume from paused position
          totalDuration: initialDuration,
        );

        // -- First Play --
        logger.d('TEST [resume paused]: Initial play call...');
        await service.play(tFilePath);

        // Verify initial interactions
        verify(mockAudioPlayerAdapter.stop()).called(1);
        verify(mockAudioPlayerAdapter.setSourceUrl(tFilePath)).called(1);
        verify(mockAudioPlayerAdapter.resume()).called(1);

        // Simulate mapper emitting the initial playing state
        mockPlaybackStateController.add(initialPlayingState);
        await Future.delayed(Duration.zero); // Process stream

        // -- Pause --
        logger.d('TEST [resume paused]: Pause call...');
        await service.pause();
        verify(mockAudioPlayerAdapter.pause()).called(1);

        // Simulate mapper emitting the paused state
        mockPlaybackStateController.add(pausedState);
        await Future.delayed(Duration.zero); // Process stream

        // Clear interactions before the second play call
        clearInteractions(mockAudioPlayerAdapter);

        // -- Act: Setup a subscription to verify states after this point --
        final emittedStates = <entity.PlaybackState>[];
        final subscription = service.playbackStateStream.listen((state) {
          logger.d('TEST [resume paused]: State received: $state');
          emittedStates.add(state);
        });

        try {
          // Call play again on the paused file
          logger.d('TEST [resume paused]: Second play call (should resume)...');
          await service.play(tFilePath);

          // Verify ONLY resume was called
          verifyNever(mockAudioPlayerAdapter.stop());
          verifyNever(mockAudioPlayerAdapter.setSourceUrl(any));
          verify(mockAudioPlayerAdapter.resume()).called(1);

          // Simulate mapper emitting the resumed playing state
          mockPlaybackStateController.add(resumedPlayingState);
          await Future.delayed(Duration.zero); // Process stream

          // Give the stream time to propagate the state
          await Future.delayed(const Duration(milliseconds: 50));

          // Verify we received the resumed state
          expect(
            emittedStates.last,
            equals(resumedPlayingState),
            reason: 'Service should emit the resumed playing state',
          );

          logger.d('TEST [resume paused]: Test completed successfully!');
        } finally {
          // Always clean up the subscription
          await subscription.cancel();
        }
      },
    );

    // TODO: Add test for play throwing if adapter.stop throws (initial play)
    // TODO: Add test for play throwing if adapter.stop throws (subsequent play - restart)
  }); // Close the group
} // Close main
