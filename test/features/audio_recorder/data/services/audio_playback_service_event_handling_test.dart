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

    // Initialize controllers (sync for fakeAsync)
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

    // Stub methods (essential for setup/error handling)
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
    // Dispose the service first
    await service.dispose();

    // Close controllers AFTER service disposal
    await playerStateController.close();
    await durationController.close();
    await positionController.close();
    await completionController.close();
    await logController.close();
  });

  group('AudioPlayer Stream Events', () {
    test('onPlayerStateChanged(playing) updates state correctly', () {
      fakeAsync((async) async {
        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks(); // Process initial state emission

        playerStateController.add(PlayerState.playing);
        async.flushMicrotasks(); // Process event

        expect(
          states.last,
          isA<PlaybackState>().having((s) => s.isPlaying, 'isPlaying', true),
        );
        await sub.cancel();
      });
    });

    test('onPlayerStateChanged(paused) updates state correctly', () {
      fakeAsync((async) async {
        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks();

        // Ensure playing state first
        playerStateController.add(PlayerState.playing);
        async.flushMicrotasks();
        expect(service.currentState.isPlaying, isTrue);

        // Add paused state
        playerStateController.add(PlayerState.paused);
        async.flushMicrotasks();

        expect(
          states.last,
          isA<PlaybackState>().having((s) => s.isPlaying, 'isPlaying', false),
        );
        await sub.cancel();
      });
    });

    test('onPlayerStateChanged(stopped) updates state correctly', () {
      fakeAsync((async) async {
        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks();

        // Ensure playing state first
        playerStateController.add(PlayerState.playing);
        async.flushMicrotasks();
        expect(service.currentState.isPlaying, isTrue);

        // Add stopped state
        playerStateController.add(PlayerState.stopped);
        async.flushMicrotasks();

        expect(
          states.last,
          isA<PlaybackState>()
              .having((s) => s.isPlaying, 'isPlaying', false)
              .having(
                (s) => s.position,
                'position',
                Duration.zero,
              ), // Also resets position
        );
        await sub.cancel();
      });
    });

    test('onDurationChanged updates state correctly', () {
      fakeAsync((async) async {
        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks();

        const tDuration = Duration(minutes: 2);
        durationController.add(tDuration);
        async.flushMicrotasks();

        expect(
          states.last,
          isA<PlaybackState>().having(
            (s) => s.totalDuration,
            'totalDuration',
            tDuration,
          ),
        );
        await sub.cancel();
      });
    });

    test(
      'onPositionChanged updates state correctly only if duration is known',
      () {
        fakeAsync((async) async {
          final states = <PlaybackState>[];
          final sub = service.playbackStateStream.listen(states.add);
          async.flushMicrotasks();

          const tDuration = Duration(minutes: 1);
          const tPosition = Duration(seconds: 15);

          // Ensure duration is known first
          durationController.add(tDuration);
          async.flushMicrotasks();
          expect(service.currentState.totalDuration, tDuration);

          // Add position update
          positionController.add(tPosition);
          async.flushMicrotasks();

          expect(
            states.last,
            isA<PlaybackState>().having(
              (s) => s.position,
              'position',
              tPosition,
            ),
          );
          await sub.cancel();
        });
      },
    );

    test('onPositionChanged does not update state if duration is zero', () {
      fakeAsync((async) async {
        // Arrange
        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks();

        expect(
          service.currentState.totalDuration,
          Duration.zero,
        ); // Verify precondition

        const tPosition = Duration(seconds: 15);
        bool receivedPositionUpdate = false;
        for (var state in states) {
          if (state.position == tPosition &&
              state.totalDuration == Duration.zero) {
            receivedPositionUpdate = true;
            break;
          }
        }

        // Act: Emit position while duration is zero
        positionController.add(tPosition);
        async.flushMicrotasks();

        // Assert: Check collected states again after the event
        receivedPositionUpdate = false; // Reset flag
        for (var state in states) {
          if (state.position == tPosition &&
              state.totalDuration == Duration.zero) {
            receivedPositionUpdate = true;
            break;
          }
        }
        expect(
          receivedPositionUpdate,
          isFalse,
          reason:
              'Position $tPosition should not have been emitted while duration was zero. States received: $states',
        );
        await sub.cancel();
      });
    });

    test('onPlayerComplete updates state correctly', () {
      fakeAsync((async) async {
        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks();

        // Arrange: Set playing state and known duration/position near end
        const tDur = Duration(seconds: 30);
        durationController.add(tDur);
        playerStateController.add(PlayerState.playing);
        positionController.add(tDur);
        async.flushMicrotasks();
        expect(service.currentState.isPlaying, isTrue);
        expect(service.currentState.position, tDur);

        // Act
        completionController.add(null); // Simulate completion event
        async.flushMicrotasks();

        // Assert
        expect(
          states.last,
          isA<PlaybackState>()
              .having((s) => s.isCompleted, 'isCompleted', true)
              .having((s) => s.isPlaying, 'isPlaying', false)
              .having(
                (s) => s.position,
                'position',
                Duration.zero,
              ), // Resets position
        );
        await sub.cancel();
      });
    });

    test('onLog (Error) updates state correctly and calls stop', () {
      fakeAsync((async) async {
        final states = <PlaybackState>[];
        final sub = service.playbackStateStream.listen(states.add);
        async.flushMicrotasks();

        const errorMsg = 'Error: Something bad happened';
        when(mockAudioPlayer.stop()).thenAnswer((_) async => {});

        // Act
        logController.add(errorMsg);
        async.flushMicrotasks(); // Allow async error handling

        // Assert
        expect(
          states.last,
          isA<PlaybackState>()
              .having((s) => s.hasError, 'hasError', true)
              .having((s) => s.errorMessage, 'errorMessage', errorMsg),
        );
        verify(mockAudioPlayer.stop()).called(1);
        await sub.cancel();
      });
    });
  });
}
