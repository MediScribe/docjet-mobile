import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:docjet_mobile/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Import the generated mocks file
import 'audio_player_adapter_impl_test.mocks.dart';

// Import the new logging helpers
import 'package:docjet_mobile/core/utils/log_helpers.dart';

// Import the new logging test utilities package
// import 'package:docjet_test/docjet_test.dart'; // Obsolete

// Generate mocks for the AudioPlayer class from just_audio
@GenerateMocks([AudioPlayer])
void main() {
  late MockAudioPlayer mockAudioPlayer;
  late AudioPlayerAdapter audioPlayerAdapter;
  late StreamController<PlayerState> playerStateController;
  late StreamController<Duration?> durationController;
  late StreamController<Duration> positionController;

  setUp(() {
    // 1. Instantiate the mock player
    mockAudioPlayer = MockAudioPlayer();

    // 2. Instantiate the stream controllers
    playerStateController = StreamController<PlayerState>.broadcast();
    durationController = StreamController<Duration?>.broadcast();
    positionController = StreamController<Duration>.broadcast();

    // 3. Stub the streams BEFORE passing the mock to the implementation
    when(
      mockAudioPlayer.playerStateStream,
    ).thenAnswer((_) => playerStateController.stream);
    when(
      mockAudioPlayer.durationStream,
    ).thenAnswer((_) => durationController.stream);
    when(
      mockAudioPlayer.positionStream,
    ).thenAnswer((_) => positionController.stream);
    when(
      mockAudioPlayer.playbackEventStream,
    ).thenAnswer((_) => const Stream.empty());

    // 4. Stub basic methods needed by implementation
    when(mockAudioPlayer.pause()).thenAnswer((_) async {});
    when(mockAudioPlayer.play()).thenAnswer((_) async {});
    when(
      mockAudioPlayer.seek(any, index: anyNamed('index')),
    ).thenAnswer((_) async {});
    when(mockAudioPlayer.stop()).thenAnswer((_) async {});
    when(
      mockAudioPlayer.setAudioSource(any),
    ).thenAnswer((_) async => Duration.zero);
    when(mockAudioPlayer.dispose()).thenAnswer((_) async {});

    // 5. Stub getters with default values
    when(
      mockAudioPlayer.playerState,
    ).thenReturn(PlayerState(false, ProcessingState.ready));
    when(mockAudioPlayer.playing).thenReturn(false);
    when(mockAudioPlayer.processingState).thenReturn(ProcessingState.ready);

    // 6. Set default log level *before* initializing the adapter
    LoggerFactory.setLogLevel(AudioPlayerAdapterImpl, Level.debug);

    // 7. Initialize adapter with the fully stubbed mock
    audioPlayerAdapter = AudioPlayerAdapterImpl(mockAudioPlayer);

    // 8. Add initial events to get things moving
    playerStateController.add(PlayerState(false, ProcessingState.ready));
  });

  tearDown(() {
    playerStateController.close();
    durationController.close();
    positionController.close();

    // Reset log levels after each test
    LoggerFactory.resetLogLevels();
  });

  // Basic functional tests

  group('pause', () {
    test('should call pause on AudioPlayer', () async {
      await audioPlayerAdapter.pause();
      verify(mockAudioPlayer.pause()).called(1);
    });
  });

  group('resume', () {
    test('should call play on AudioPlayer', () async {
      await audioPlayerAdapter.resume();
      verify(mockAudioPlayer.play()).called(1);
    });
  });

  group('seek', () {
    test('should call seek on AudioPlayer with correct position', () async {
      const position = Duration(seconds: 10);
      await audioPlayerAdapter.seek('', position);
      verify(mockAudioPlayer.seek(position)).called(1);
    });
  });

  group('stop', () {
    test('should call stop on AudioPlayer', () async {
      await audioPlayerAdapter.stop();
      verify(mockAudioPlayer.stop()).called(1);
    });
  });

  group('dispose', () {
    test('should call dispose on AudioPlayer', () async {
      await audioPlayerAdapter.dispose();
      verify(mockAudioPlayer.dispose()).called(1);
    });
  });

  group('setSourceUrl', () {
    test(
      'should call setAudioSource on AudioPlayer with correct AudioSource for local paths',
      () async {
        const localPath = '/path/to/local/audio.mp3';
        await audioPlayerAdapter.setSourceUrl(localPath);

        final verification = verify(mockAudioPlayer.setAudioSource(captureAny));
        verification.called(1);

        final capturedSource = verification.captured.single as AudioSource;
        expect(capturedSource, isA<UriAudioSource>());
        expect((capturedSource as UriAudioSource).uri.scheme, 'file');
      },
    );

    test(
      'should call setAudioSource on AudioPlayer with correct AudioSource for remote URLs',
      () async {
        const remoteUrl = 'https://example.com/audio.mp3';

        when(mockAudioPlayer.playing).thenReturn(false);
        when(mockAudioPlayer.processingState).thenReturn(ProcessingState.idle);

        await audioPlayerAdapter.setSourceUrl(remoteUrl);

        final verification = verify(mockAudioPlayer.setAudioSource(captureAny));
        verification.called(1);

        final capturedSource = verification.captured.single as AudioSource;
        expect(capturedSource, isA<UriAudioSource>());

        final uri = (capturedSource as UriAudioSource).uri;
        expect(uri.toString(), contains('example.com/audio.mp3'));
      },
    );
  });

  // Stream tests - adding back with proper completion handling
  group('streams', () {
    test(
      'onPlayerStateChanged should map just_audio PlayerState to DomainPlayerState',
      () async {
        // Arrange: Set up the test with a Completer to control when the test completes
        final completer = Completer<void>();
        final expectedStates = [
          DomainPlayerState.loading,
          DomainPlayerState.playing,
          DomainPlayerState.paused,
          DomainPlayerState.completed,
        ];
        final emittedStates = <DomainPlayerState>[];

        // Act: Subscribe to the stream before adding events
        final subscription = audioPlayerAdapter.onPlayerStateChanged.listen((
          state,
        ) {
          emittedStates.add(state);
          if (emittedStates.length == expectedStates.length) {
            completer.complete();
          }
        });

        // Add the events that should trigger state changes
        playerStateController.add(PlayerState(false, ProcessingState.loading));
        playerStateController.add(PlayerState(true, ProcessingState.ready));
        playerStateController.add(PlayerState(false, ProcessingState.ready));
        playerStateController.add(
          PlayerState(false, ProcessingState.completed),
        );

        // Wait for the completer to complete
        await completer.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => throw TimeoutException('Stream test timed out'),
        );

        // Clean up
        await subscription.cancel();

        // Assert: Verify the emitted states match expected states
        expect(emittedStates, expectedStates);
      },
    );

    test(
      "onDurationChanged should expose player's durationStream, filtering nulls",
      () async {
        // Arrange
        final completer = Completer<void>();
        final expectedDurations = [
          const Duration(seconds: 60),
          const Duration(seconds: 120),
        ];
        final emittedDurations = <Duration>[];

        // Act: Subscribe to the stream
        final subscription = audioPlayerAdapter.onDurationChanged.listen((
          duration,
        ) {
          emittedDurations.add(duration);
          if (emittedDurations.length == expectedDurations.length) {
            completer.complete();
          }
        });

        // Add test events
        durationController.add(null); // Should be filtered out
        durationController.add(expectedDurations[0]);
        durationController.add(null); // Should be filtered out
        durationController.add(expectedDurations[1]);

        // Wait for the completer
        await completer.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => throw TimeoutException('Stream test timed out'),
        );

        // Clean up
        await subscription.cancel();

        // Assert
        expect(emittedDurations, expectedDurations);
      },
    );

    test("onPositionChanged should expose player's positionStream", () async {
      // Arrange
      final completer = Completer<void>();
      final expectedPositions = [
        const Duration(seconds: 5),
        const Duration(seconds: 10),
      ];
      final emittedPositions = <Duration>[];

      // Act: Subscribe to the stream
      final subscription = audioPlayerAdapter.onPositionChanged.listen((
        position,
      ) {
        emittedPositions.add(position);
        if (emittedPositions.length == expectedPositions.length) {
          completer.complete();
        }
      });

      // Add test events
      positionController.add(expectedPositions[0]);
      positionController.add(expectedPositions[1]);

      // Wait for the completer
      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('Stream test timed out'),
      );

      // Clean up
      await subscription.cancel();

      // Assert
      expect(emittedPositions, expectedPositions);
    });

    test(
      'onPlayerComplete should emit when processing state is completed',
      () async {
        // Arrange
        final completer = Completer<void>();
        int completeEvents = 0;

        // Act: Subscribe to the stream
        final subscription = audioPlayerAdapter.onPlayerComplete.listen((_) {
          completeEvents++;
          completer.complete();
        });

        // Add test events - only the completed state should trigger an emit
        playerStateController.add(PlayerState(false, ProcessingState.loading));
        playerStateController.add(PlayerState(true, ProcessingState.ready));
        playerStateController.add(PlayerState(false, ProcessingState.ready));
        playerStateController.add(
          PlayerState(false, ProcessingState.completed),
        ); // Should trigger emit

        // Wait for the completer
        await completer.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => throw TimeoutException('Stream test timed out'),
        );

        // Clean up
        await subscription.cancel();

        // Assert
        expect(
          completeEvents,
          1,
          reason: 'Should emit exactly once when state is completed',
        );
      },
    );
  });
}

// IMPORTANT: After saving this file, run:
// flutter pub run build_runner build --delete-conflicting-outputs
// to regenerate the audio_player_adapter_impl_test.mocks.dart file.
