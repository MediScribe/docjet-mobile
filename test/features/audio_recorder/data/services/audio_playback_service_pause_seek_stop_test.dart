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
    when(mockAudioPlayer.stop()).thenAnswer((_) async {});
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

  group('pause', () {
    // Use local controller as tests manipulate state directly
    late StreamController<PlayerState> localPlayerStateController;

    setUp(() {
      localPlayerStateController = StreamController<PlayerState>.broadcast(
        sync: true,
      );
      when(
        mockAudioPlayer.onPlayerStateChanged,
      ).thenAnswer((_) => localPlayerStateController.stream);
      when(mockAudioPlayer.pause()).thenAnswer((_) async {});
      when(mockAudioPlayer.stop()).thenAnswer((_) async => {});
    });

    tearDown(() async {
      await localPlayerStateController.close();
    });

    test('should call pause on AudioPlayer if playing', () {
      fakeAsync((async) {
        // Arrange: Service is ready from setUp
        final sub = service.playbackStateStream.listen(null);
        async.flushMicrotasks(); // Process initial state if any

        // Force playing state via controller
        localPlayerStateController.add(PlayerState.playing);
        async.flushMicrotasks(); // Allow state to process
        // Verify we are actually in playing state
        expect(service.currentState.isPlaying, isTrue);

        // Act
        service.pause();
        async.flushMicrotasks(); // Allow pause command to process

        // Assert
        verify(mockAudioPlayer.pause()).called(1);
        sub.cancel();
      });
    });

    test('should not call pause on AudioPlayer if not playing', () {
      fakeAsync((async) {
        // Arrange: Service is ready from setUp
        final sub = service.playbackStateStream.listen(null);
        async.flushMicrotasks();

        // Ensure service is in a non-playing state
        expect(service.currentState.isPlaying, isFalse);

        // Act
        service.pause();
        async.flushMicrotasks(); // Allow pause command to process

        // Assert
        verifyNever(mockAudioPlayer.pause());
        sub.cancel();
      });
    });

    test('should emit error state if pause throws', () {
      fakeAsync((async) {
        // Arrange
        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks();

        // Force playing state
        localPlayerStateController.add(PlayerState.playing);
        async.flushMicrotasks();
        expect(service.currentState.isPlaying, isTrue); // Verify precondition

        final exception = Exception('Failed to pause');
        when(mockAudioPlayer.pause()).thenThrow(exception);
        when(mockAudioPlayer.stop()).thenAnswer((_) async => {});

        // Act
        service.pause();
        async.flushMicrotasks(); // Allow error handling

        // Assert state
        expect(
          states.last,
          isA<PlaybackState>()
              .having((s) => s.hasError, 'hasError', true)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('Failed to pause'),
              ),
        );
        // Assert interactions
        verify(mockAudioPlayer.pause()).called(1); // Pause was called
        verify(
          mockAudioPlayer.stop(),
        ).called(1); // Error handler should call stop
        sub.cancel();
      });
    });
  });

  group('seek', () {
    const tFilePath = '/path/to/file.mp3';
    const tTotalDuration = Duration(seconds: 60);
    const tSeekPosition = Duration(seconds: 30);

    // Helper to set up playing state for seek tests using fakeAsync
    Future<StreamSubscription> setupPlayingState(
      FakeAsync async,
      String filePath,
      Duration totalDuration,
    ) async {
      // service is already initialized in global setUp
      final sub = service.playbackStateStream.listen(null);
      async.flushMicrotasks();

      // Simulate play and state events
      service.play(filePath);
      async.flushMicrotasks(); // Loading
      durationController.add(totalDuration); // Set duration
      playerStateController.add(PlayerState.playing); // Set playing
      positionController.add(Duration.zero); // Set initial position
      async.flushMicrotasks(); // Allow events to process
      clearInteractions(mockAudioPlayer);

      // Re-stub methods
      when(mockAudioPlayer.seek(any)).thenAnswer((realInvocation) async {
        final requestedPosition =
            realInvocation.positionalArguments[0] as Duration;
        if (!positionController.isClosed) {
          positionController.add(
            requestedPosition > totalDuration
                ? totalDuration
                : requestedPosition,
          );
        }
      });
      when(mockAudioPlayer.stop()).thenAnswer((_) async {
        if (!playerStateController.isClosed) {
          playerStateController.add(PlayerState.stopped);
        }
      });
      when(mockAudioPlayer.pause()).thenAnswer((_) async => {});
      when(mockAudioPlayer.resume()).thenAnswer((_) async => {});
      when(mockAudioPlayer.setSource(any)).thenAnswer((_) async => {});

      return sub;
    }

    test('should call seek on AudioPlayer with correct position', () {
      fakeAsync((async) async {
        final sub = await setupPlayingState(async, tFilePath, tTotalDuration);
        service.seek(tSeekPosition);
        async.flushMicrotasks(); // Allow seek to process
        verify(mockAudioPlayer.seek(tSeekPosition)).called(1);
        await sub.cancel();
      });
    });

    test('should clamp seek position to total duration if exceeding', () {
      fakeAsync((async) async {
        final sub = await setupPlayingState(async, tFilePath, tTotalDuration);
        final tExcessiveSeek = tTotalDuration + const Duration(seconds: 10);
        service.seek(tExcessiveSeek);
        async.flushMicrotasks();
        verify(mockAudioPlayer.seek(tTotalDuration)).called(1);
        await sub.cancel();
      });
    });

    test('should not call seek if no file is loaded (initial state)', () {
      fakeAsync((async) {
        // Arrange: Service is in initial state from setUp
        final sub = service.playbackStateStream.listen(null);
        async.flushMicrotasks();
        expect(service.currentState.currentFilePath, isNull);

        // Act
        service.seek(tSeekPosition);
        async.flushMicrotasks();

        // Assert
        verifyNever(mockAudioPlayer.seek(any));
        sub.cancel();
      });
    });

    test('should emit state with updated position after seek', () {
      fakeAsync((async) async {
        final states = <PlaybackState>[];
        final sub = await setupPlayingState(async, tFilePath, tTotalDuration);
        // Listen *after* setup to avoid capturing setup states
        final stateSub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks(); // process subscription

        // Act
        service.seek(tSeekPosition);
        async.flushMicrotasks(); // Allow seek and position update

        // Assert
        // Check the LAST state emitted after seek
        expect(
          states.last,
          isA<PlaybackState>().having(
            (s) => s.position,
            'position',
            tSeekPosition,
          ),
        );

        await sub.cancel();
        await stateSub.cancel();
      });
    });

    test('should emit error state if seek throws', () {
      fakeAsync((async) async {
        final states = <PlaybackState>[];
        final sub = await setupPlayingState(async, tFilePath, tTotalDuration);
        final stateSub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks();

        final exception = Exception('Seek failed');
        when(mockAudioPlayer.seek(any)).thenThrow(exception);
        when(mockAudioPlayer.stop()).thenAnswer((_) async {});

        // Act
        service.seek(tSeekPosition);
        async.flushMicrotasks(); // Allow error handling

        // Assert state
        expect(
          states.last,
          isA<PlaybackState>()
              .having((s) => s.hasError, 'hasError', true)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('Seek failed'),
              ),
        );
        // Assert interactions
        verify(
          mockAudioPlayer.seek(tSeekPosition),
        ).called(1); // Seek was called
        verify(mockAudioPlayer.stop()).called(1); // Error handler calls stop
        await sub.cancel();
        await stateSub.cancel();
      });
    });
  });

  group('stop', () {
    late StreamController<PlayerState> localPlayerStateController;

    setUp(() {
      localPlayerStateController = StreamController<PlayerState>.broadcast(
        sync: true,
      );
      when(
        mockAudioPlayer.onPlayerStateChanged,
      ).thenAnswer((_) => localPlayerStateController.stream);
      when(mockAudioPlayer.stop()).thenAnswer((_) async {
        if (!localPlayerStateController.isClosed) {
          localPlayerStateController.add(PlayerState.stopped);
        }
      });
      when(mockAudioPlayer.setSource(any)).thenAnswer((_) async {});
      when(mockAudioPlayer.resume()).thenAnswer((_) async => {});
    });

    tearDown(() async {
      await localPlayerStateController.close();
    });

    // Helper using fakeAsync
    Future<StreamSubscription> setupPlayingForStop(FakeAsync async) async {
      // service is ready from global setUp
      final sub = service.playbackStateStream.listen(null);
      async.flushMicrotasks();

      // Simulate playing state
      service.play('some/path');
      async.flushMicrotasks(); // Loading
      localPlayerStateController.add(PlayerState.playing);
      async.flushMicrotasks(); // Allow playing state to process
      clearInteractions(mockAudioPlayer);

      // Re-stub stop
      when(mockAudioPlayer.stop()).thenAnswer((_) async {
        if (!localPlayerStateController.isClosed) {
          localPlayerStateController.add(PlayerState.stopped);
        }
      });
      when(mockAudioPlayer.resume()).thenAnswer((_) async => {});
      when(mockAudioPlayer.setSource(any)).thenAnswer((_) async => {});

      return sub;
    }

    test('should call stop on AudioPlayer', () {
      fakeAsync((async) async {
        final sub = await setupPlayingForStop(async);
        service.stop();
        async.flushMicrotasks(); // Allow stop to process
        verify(mockAudioPlayer.stop()).called(1);
        await sub.cancel();
      });
    });

    test('should emit initial state eventually after stop', () {
      fakeAsync((async) async {
        final sub = await setupPlayingForStop(async);
        final states = <PlaybackState>[];
        final stateSub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks();

        // Act
        service.stop();
        async.flushMicrotasks(); // Allow state reset

        // Assert - Check the LAST state emitted after stop/reset
        expect(states.last, const PlaybackState.initial());
        await sub.cancel();
        await stateSub.cancel();
      });
    });

    test('should emit error then initial state if stop throws', () {
      fakeAsync((async) async {
        final sub = await setupPlayingForStop(async);
        final states = <PlaybackState>[];
        final stateSub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks();

        final exception = Exception('Stop failed miserably');
        // Make stop throw, but the internal reset should still happen
        when(mockAudioPlayer.stop()).thenThrow(exception);

        // Act
        service.stop();
        async.flushMicrotasks(); // Allow error handling and reset

        // Assert state sequence
        expectLater(
          Stream.fromIterable(states),
          emitsInOrder([
            isA<PlaybackState>()
                .having((s) => s.hasError, 'hasError', true)
                .having(
                  (s) => s.errorMessage,
                  'errorMessage',
                  contains('Stop failed'),
                ),
            const PlaybackState.initial(), // Reset should still occur
          ]),
        );
        async.elapse(Duration.zero); // Ensure expectLater completes

        // Assert interaction
        verify(mockAudioPlayer.stop()).called(1); // Verify stop was called
        await sub.cancel();
        await stateSub.cancel();
      });
    });
  });
}
