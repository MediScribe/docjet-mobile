import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:docjet_mobile/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';

// Import the generated mocks file
import 'audio_player_adapter_impl_test.mocks.dart';

// Import the new logging helpers
import 'package:docjet_mobile/core/utils/log_helpers.dart';

// Import the new logging test utilities package
// import 'package:docjet_test/docjet_test.dart'; // Obsolete

// Generate mocks for the AudioPlayer class from just_audio and FileSystem
@GenerateMocks([AudioPlayer, FileSystem])
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
    test('should emit paused state after pause is called', () async {
      // Arrange
      final completer = Completer<void>();
      final emittedStates = <DomainPlayerState>[];
      final subscription = audioPlayerAdapter.onPlayerStateChanged.listen((
        state,
      ) {
        emittedStates.add(state);
        if (emittedStates.contains(DomainPlayerState.paused)) {
          completer.complete();
        }
      });
      // Act
      await audioPlayerAdapter.pause();
      // Simulate player emitting paused state
      playerStateController.add(PlayerState(false, ProcessingState.ready));
      // Assert
      await completer.future.timeout(const Duration(seconds: 2));
      expect(emittedStates, contains(DomainPlayerState.paused));
      await subscription.cancel();
    });
  });

  group('resume', () {
    test('should emit playing state after resume is called', () async {
      final completer = Completer<void>();
      final emittedStates = <DomainPlayerState>[];
      final subscription = audioPlayerAdapter.onPlayerStateChanged.listen((
        state,
      ) {
        emittedStates.add(state);
        if (emittedStates.contains(DomainPlayerState.playing)) {
          completer.complete();
        }
      });
      await audioPlayerAdapter.resume();
      playerStateController.add(PlayerState(true, ProcessingState.ready));
      await completer.future.timeout(const Duration(seconds: 2));
      expect(emittedStates, contains(DomainPlayerState.playing));
      await subscription.cancel();
    });
  });

  group('seek', () {
    test('should emit correct position after seek is called', () async {
      final completer = Completer<void>();
      final expectedPosition = Duration(seconds: 10);
      final emittedPositions = <Duration>[];
      final subscription = audioPlayerAdapter.onPositionChanged.listen((pos) {
        emittedPositions.add(pos);
        if (emittedPositions.contains(expectedPosition)) {
          completer.complete();
        }
      });
      await audioPlayerAdapter.seek('', expectedPosition);
      positionController.add(expectedPosition);
      await completer.future.timeout(const Duration(seconds: 2));
      expect(emittedPositions, contains(expectedPosition));
      await subscription.cancel();
    });
  });

  group('stop', () {
    test('should emit stopped state after stop is called', () async {
      final completer = Completer<void>();
      final emittedStates = <DomainPlayerState>[];
      final subscription = audioPlayerAdapter.onPlayerStateChanged.listen((
        state,
      ) {
        emittedStates.add(state);
        if (emittedStates.contains(DomainPlayerState.stopped)) {
          completer.complete();
        }
      });
      await audioPlayerAdapter.stop();
      playerStateController.add(PlayerState(false, ProcessingState.idle));
      await completer.future.timeout(const Duration(seconds: 2));
      expect(emittedStates, contains(DomainPlayerState.stopped));
      await subscription.cancel();
    });
  });

  group('dispose', () {
    test('should not emit any more states after dispose is called', () async {
      final emittedStates = <DomainPlayerState>[];
      final subscription = audioPlayerAdapter.onPlayerStateChanged.listen((
        state,
      ) {
        emittedStates.add(state);
      });
      await audioPlayerAdapter.dispose();
      playerStateController.add(PlayerState(true, ProcessingState.ready));
      // Wait a short time to ensure no new states are emitted
      await Future.delayed(const Duration(milliseconds: 200));
      // After dispose, no new states should be added
      expect(emittedStates.length, equals(0));
      await subscription.cancel();
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

    test('should throw when given a missing local file path', () async {
      // Arrange: mock FileSystem to return false for fileExists
      final mockFileSystem = MockFileSystem();
      when(mockFileSystem.fileExists(any)).thenAnswer((_) async => false);
      final adapter = AudioPlayerAdapterImpl(
        mockAudioPlayer,
        fileSystem: mockFileSystem,
      );
      // Act & Assert
      expect(
        () => adapter.setSourceUrl('/missing/file.mp3'),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw when given a malformed (empty string) path', () async {
      // Arrange: no FileSystem needed, just pass empty string
      // Act & Assert
      expect(
        () => audioPlayerAdapter.setSourceUrl(''),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw when given an invalid URI', () async {
      expect(
        () => audioPlayerAdapter.setSourceUrl('::not_a_uri::'),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'should skip file existence check and play remote URLs even if FileSystem is injected',
      () async {
        final mockFileSystem = MockFileSystem();
        final adapter = AudioPlayerAdapterImpl(
          mockAudioPlayer,
          fileSystem: mockFileSystem,
        );
        const remoteUrl = 'https://example.com/audio.mp3';
        await adapter.setSourceUrl(remoteUrl);
        verifyNever(mockFileSystem.fileExists(any));
        verify(mockAudioPlayer.setAudioSource(any)).called(1);
      },
    );

    test(
      'should throw if underlying player throws on setAudioSource',
      () async {
        when(
          mockAudioPlayer.setAudioSource(any),
        ).thenThrow(Exception('player fail'));
        expect(
          () => audioPlayerAdapter.setSourceUrl('/path/to/local/audio.mp3'),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('should throw if called after dispose()', () async {
      await audioPlayerAdapter.dispose();
      expect(
        () => audioPlayerAdapter.setSourceUrl('/path/to/local/audio.mp3'),
        throwsA(isA<StateError>()),
      );
    });

    test('should play relative path if file exists, throw if not', () async {
      final mockFileSystem = MockFileSystem();
      when(
        mockFileSystem.fileExists('audio.mp3'),
      ).thenAnswer((_) async => true);
      final adapter = AudioPlayerAdapterImpl(
        mockAudioPlayer,
        fileSystem: mockFileSystem,
      );
      await adapter.setSourceUrl('audio.mp3');
      verify(mockFileSystem.fileExists('audio.mp3')).called(1);
      verify(mockAudioPlayer.setAudioSource(any)).called(1);

      // Now test missing file
      when(
        mockFileSystem.fileExists('missing.mp3'),
      ).thenAnswer((_) async => false);
      expect(
        () => adapter.setSourceUrl('missing.mp3'),
        throwsA(isA<Exception>()),
      );
    });

    test('should play absolute path if file exists, throw if not', () async {
      final mockFileSystem = MockFileSystem();
      when(
        mockFileSystem.fileExists('/abs/path/audio.mp3'),
      ).thenAnswer((_) async => true);
      final adapter = AudioPlayerAdapterImpl(
        mockAudioPlayer,
        fileSystem: mockFileSystem,
      );
      await adapter.setSourceUrl('/abs/path/audio.mp3');
      verify(mockFileSystem.fileExists('/abs/path/audio.mp3')).called(1);
      verify(mockAudioPlayer.setAudioSource(any)).called(1);

      // Now test missing file
      when(
        mockFileSystem.fileExists('/abs/path/missing.mp3'),
      ).thenAnswer((_) async => false);
      expect(
        () => adapter.setSourceUrl('/abs/path/missing.mp3'),
        throwsA(isA<Exception>()),
      );
    });
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
