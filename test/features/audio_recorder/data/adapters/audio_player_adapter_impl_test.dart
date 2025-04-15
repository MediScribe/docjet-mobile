import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:docjet_mobile/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/src/path_resolver.dart';

// Import the generated mocks file
import 'audio_player_adapter_impl_test.mocks.dart';

// Import logging utilities
import 'package:docjet_mobile/core/utils/log_helpers.dart';

// ==========================================================================
// Test Helpers & Setup
// ==========================================================================

/// Helper class to manage stream controllers for player state testing.
/// Centralizes controller creation and disposal to prevent memory leaks.
class PlayerStreamStubs {
  final StreamController<PlayerState> playerStateController;
  final StreamController<Duration> positionController;
  final StreamController<Duration?> durationController;

  PlayerStreamStubs({
    required this.playerStateController,
    required this.positionController,
    required this.durationController,
  });

  /// Clean up resources to prevent memory leaks
  Future<void> close() async {
    await playerStateController.close();
    await positionController.close();
    await durationController.close();
  }
}

/// Creates and configures stream controllers for a mock AudioPlayer.
/// Returns a helper object that can be used to manage the controllers.
PlayerStreamStubs stubPlayerStreams(MockAudioPlayer mockAudioPlayer) {
  // Create broadcast controllers for multi-subscriber support
  final playerStateController = StreamController<PlayerState>.broadcast();
  final positionController = StreamController<Duration>.broadcast();
  final durationController = StreamController<Duration?>.broadcast();

  // Configure mock to return the stream controllers
  when(
    mockAudioPlayer.playerStateStream,
  ).thenAnswer((_) => playerStateController.stream);
  when(
    mockAudioPlayer.positionStream,
  ).thenAnswer((_) => positionController.stream);
  when(
    mockAudioPlayer.durationStream,
  ).thenAnswer((_) => durationController.stream);

  return PlayerStreamStubs(
    playerStateController: playerStateController,
    positionController: positionController,
    durationController: durationController,
  );
}

// ==========================================================================
// Main Test Body
// ==========================================================================

// Generate mocks for all needed classes with custom names to avoid conflicts
@GenerateMocks(
  [AudioPlayer, FileSystem],
  customMocks: [MockSpec<PathResolver>(as: #GeneratedMockPathResolver)],
)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test-wide variables
  late MockAudioPlayer mockAudioPlayer;
  late AudioPlayerAdapter audioPlayerAdapter;
  late StreamController<PlayerState> playerStateController;
  late StreamController<Duration?> durationController;
  late StreamController<Duration> positionController;
  late GeneratedMockPathResolver mockPathResolver;

  setUp(() {
    // STEP 1: Initialize the mock player
    mockAudioPlayer = MockAudioPlayer();
    mockPathResolver = GeneratedMockPathResolver();
    // Default stub for PathResolver - specific values for simplicity
    when(
      mockPathResolver.resolve("audio/test.m4a", mustExist: true),
    ).thenAnswer((_) async => '/dummy/path.m4a');

    // STEP 2: Create stream controllers for event simulation
    playerStateController = StreamController<PlayerState>.broadcast();
    durationController = StreamController<Duration?>.broadcast();
    positionController = StreamController<Duration>.broadcast();

    // STEP 3: Configure the mock to return our controlled streams
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

    // STEP 4: Configure basic method behavior
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

    // STEP 5: Configure property getters
    when(
      mockAudioPlayer.playerState,
    ).thenReturn(PlayerState(false, ProcessingState.ready));
    when(mockAudioPlayer.playing).thenReturn(false);
    when(mockAudioPlayer.processingState).thenReturn(ProcessingState.ready);
    when(mockAudioPlayer.duration).thenReturn(const Duration(seconds: 30));

    // STEP 6: Configure logging for tests
    LoggerFactory.setLogLevel(AudioPlayerAdapterImpl, Level.debug);

    // STEP 7: Create the adapter instance to test
    audioPlayerAdapter = AudioPlayerAdapterImpl(
      mockAudioPlayer,
      pathResolver: mockPathResolver,
    );

    // STEP 8: Emit initial state to simulate a ready player
    playerStateController.add(PlayerState(false, ProcessingState.ready));
  });

  tearDown(() {
    // Clean up resources to prevent memory leaks
    playerStateController.close();
    durationController.close();
    positionController.close();

    // Reset log configuration to avoid affecting other tests
    LoggerFactory.resetLogLevels();
  });

  // ==========================================================================
  // Basic Playback Control Tests
  // ==========================================================================

  group('pause', () {
    test('should emit paused state after pause is called', () async {
      // Arrange: Set up state tracking and completion trigger
      final completer = Completer<void>();
      final emittedStates = <DomainPlayerState>[];

      // Subscribe to state changes
      final subscription = audioPlayerAdapter.onPlayerStateChanged.listen((
        state,
      ) {
        emittedStates.add(state);
        if (emittedStates.contains(DomainPlayerState.paused)) {
          completer.complete();
        }
      });

      // Act: Pause playback and simulate player response
      await audioPlayerAdapter.pause();
      playerStateController.add(PlayerState(false, ProcessingState.ready));

      // Assert: Wait for and verify the expected state
      await completer.future.timeout(const Duration(seconds: 2));
      expect(emittedStates, contains(DomainPlayerState.paused));

      // Clean up
      await subscription.cancel();
    });
  });

  group('resume', () {
    test('should emit playing state after resume is called', () async {
      // Arrange: Set up state tracking and completion trigger
      final completer = Completer<void>();
      final emittedStates = <DomainPlayerState>[];

      // Subscribe to state changes
      final subscription = audioPlayerAdapter.onPlayerStateChanged.listen((
        state,
      ) {
        emittedStates.add(state);
        if (emittedStates.contains(DomainPlayerState.playing)) {
          completer.complete();
        }
      });

      // Act: Resume playback and simulate player response
      await audioPlayerAdapter.resume();
      playerStateController.add(PlayerState(true, ProcessingState.ready));

      // Assert: Wait for and verify the expected state
      await completer.future.timeout(const Duration(seconds: 2));
      expect(emittedStates, contains(DomainPlayerState.playing));

      // Clean up
      await subscription.cancel();
    });
  });

  group('seek', () {
    test('should emit correct position after seek is called', () async {
      // Arrange: Set up position tracking and completion trigger
      final completer = Completer<void>();
      final expectedPosition = Duration(seconds: 10);
      final emittedPositions = <Duration>[];

      // Subscribe to position changes
      final subscription = audioPlayerAdapter.onPositionChanged.listen((pos) {
        emittedPositions.add(pos);
        if (emittedPositions.contains(expectedPosition)) {
          completer.complete();
        }
      });

      // Act: Seek to position and simulate player response
      await audioPlayerAdapter.seek('', expectedPosition);
      positionController.add(expectedPosition);

      // Assert: Wait for and verify the expected position
      await completer.future.timeout(const Duration(seconds: 2));
      expect(emittedPositions, contains(expectedPosition));

      // Clean up
      await subscription.cancel();
    });
  });

  group('stop', () {
    test('should emit stopped state after stop is called', () async {
      // Arrange: Set up state tracking and completion trigger
      final completer = Completer<void>();
      final emittedStates = <DomainPlayerState>[];

      // Subscribe to state changes
      final subscription = audioPlayerAdapter.onPlayerStateChanged.listen((
        state,
      ) {
        emittedStates.add(state);
        if (emittedStates.contains(DomainPlayerState.stopped)) {
          completer.complete();
        }
      });

      // Act: Stop playback and simulate player response
      await audioPlayerAdapter.stop();
      playerStateController.add(PlayerState(false, ProcessingState.idle));

      // Assert: Wait for and verify the expected state
      await completer.future.timeout(const Duration(seconds: 2));
      expect(emittedStates, contains(DomainPlayerState.stopped));

      // Clean up
      await subscription.cancel();
    });
  });

  group('dispose', () {
    test('should not emit any more states after dispose is called', () async {
      // Arrange: Set up state tracking
      final emittedStates = <DomainPlayerState>[];
      final subscription = audioPlayerAdapter.onPlayerStateChanged.listen((
        state,
      ) {
        emittedStates.add(state);
      });

      // Act: Dispose adapter and attempt to emit state
      await audioPlayerAdapter.dispose();
      playerStateController.add(PlayerState(true, ProcessingState.ready));

      // Assert: Wait briefly and verify no states were emitted
      await Future.delayed(const Duration(milliseconds: 200));
      expect(emittedStates.length, equals(0));

      // Clean up
      await subscription.cancel();
    });
  });

  // ==========================================================================
  // Source URL Tests
  // ==========================================================================

  group('setSourceUrl', () {
    test(
      'should call setAudioSource on AudioPlayer with correct AudioSource for local paths',
      () async {
        // Arrange: Define a local path
        const localPath = '/path/to/local/audio.mp3';

        // Set up the path resolver to resolve the path
        when(
          mockPathResolver.resolve(localPath, mustExist: true),
        ).thenAnswer((_) async => localPath);

        // Act: Set the source URL
        await audioPlayerAdapter.setSourceUrl(localPath);

        // Assert: Verify the correct AudioSource was created
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
        // Arrange: Define a remote URL and configure player state
        const remoteUrl = 'https://example.com/audio.mp3';
        when(mockAudioPlayer.playing).thenReturn(false);
        when(mockAudioPlayer.processingState).thenReturn(ProcessingState.idle);

        // Act: Set the source URL
        await audioPlayerAdapter.setSourceUrl(remoteUrl);

        // Assert: Verify the correct AudioSource was created
        final verification = verify(mockAudioPlayer.setAudioSource(captureAny));
        verification.called(1);

        final capturedSource = verification.captured.single as AudioSource;
        expect(capturedSource, isA<UriAudioSource>());

        final uri = (capturedSource as UriAudioSource).uri;
        expect(uri.toString(), contains('example.com/audio.mp3'));
      },
    );

    test('should throw when given a malformed (empty string) path', () async {
      // Arrange: No specific setup needed

      // Act & Assert: Verify exception is thrown for empty path
      expect(
        () => audioPlayerAdapter.setSourceUrl(''),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw when given an invalid URI', () async {
      // Arrange: No specific setup needed
      // Using a truly invalid URI that will fail Uri parsing
      const invalidUri = 'some://://invalid';

      // Act & Assert: Verify exception is thrown for invalid URI
      expect(
        () => audioPlayerAdapter.setSourceUrl(invalidUri),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'should throw if underlying player throws on setAudioSource',
      () async {
        // Arrange: Configure player to throw on setAudioSource
        when(
          mockAudioPlayer.setAudioSource(any),
        ).thenThrow(Exception('player fail'));

        // Act & Assert: Verify exception is propagated
        expect(
          () => audioPlayerAdapter.setSourceUrl('/path/to/local/audio.mp3'),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('should throw if called after dispose()', () async {
      // Arrange: Dispose the adapter
      await audioPlayerAdapter.dispose();

      // Act & Assert: Verify StateError is thrown
      expect(
        () => audioPlayerAdapter.setSourceUrl('/path/to/local/audio.mp3'),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'should resolve relative paths using PathResolver before creating URI',
      () async {
        // Arrange: Define a relative path and its resolved absolute path
        const relativePath = 'audio/test.m4a';
        const absolutePath = '/resolved/path/audio/test.m4a';

        // Setup the path resolver to return the absolute path
        when(
          mockPathResolver.resolve(relativePath, mustExist: true),
        ).thenAnswer((_) async => absolutePath);

        // Act: Set the source URL with a relative path
        await audioPlayerAdapter.setSourceUrl(relativePath);

        // Assert:
        // 1. Verify that PathResolver.resolve was called with the relative path
        verify(
          mockPathResolver.resolve(relativePath, mustExist: true),
        ).called(1);

        // 2. Verify setAudioSource was called with a URI using the absolute path
        final verification = verify(mockAudioPlayer.setAudioSource(captureAny));
        verification.called(1);

        final capturedSource = verification.captured.single as AudioSource;
        expect(capturedSource, isA<UriAudioSource>());
        expect(
          (capturedSource as UriAudioSource).uri.path,
          contains('/resolved/path/audio/test.m4a'),
        );
      },
    );
  });

  // ==========================================================================
  // Stream Tests
  // ==========================================================================

  group('streams', () {
    test(
      'onPlayerStateChanged should map just_audio PlayerState to DomainPlayerState',
      () async {
        // Arrange: Set up state tracking and completion trigger
        final completer = Completer<void>();
        final expectedStates = [
          DomainPlayerState.loading,
          DomainPlayerState.playing,
          DomainPlayerState.paused,
          DomainPlayerState.completed,
        ];
        final emittedStates = <DomainPlayerState>[];

        // Act: Subscribe to state changes
        final subscription = audioPlayerAdapter.onPlayerStateChanged.listen((
          state,
        ) {
          emittedStates.add(state);
          if (emittedStates.length == expectedStates.length) {
            completer.complete();
          }
        });

        // Add events to simulate various player states
        playerStateController.add(PlayerState(false, ProcessingState.loading));
        playerStateController.add(PlayerState(true, ProcessingState.ready));
        playerStateController.add(PlayerState(false, ProcessingState.ready));
        playerStateController.add(
          PlayerState(false, ProcessingState.completed),
        );

        // Wait for all states to be processed
        await completer.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => throw TimeoutException('Stream test timed out'),
        );

        // Clean up
        await subscription.cancel();

        // Assert: Verify all expected states were emitted in order
        expect(emittedStates, expectedStates);
      },
    );

    test(
      "onDurationChanged should expose player's durationStream, filtering nulls",
      () async {
        // Arrange: Set up duration tracking and completion trigger
        final completer = Completer<void>();
        final expectedDurations = [
          const Duration(seconds: 60),
          const Duration(seconds: 120),
        ];
        final emittedDurations = <Duration>[];

        // Act: Subscribe to duration changes
        final subscription = audioPlayerAdapter.onDurationChanged.listen((
          duration,
        ) {
          emittedDurations.add(duration);
          if (emittedDurations.length == expectedDurations.length) {
            completer.complete();
          }
        });

        // Add test events with null values that should be filtered
        durationController.add(null); // Should be filtered out
        durationController.add(expectedDurations[0]);
        durationController.add(null); // Should be filtered out
        durationController.add(expectedDurations[1]);

        // Wait for all durations to be processed
        await completer.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => throw TimeoutException('Stream test timed out'),
        );

        // Clean up
        await subscription.cancel();

        // Assert: Verify expected durations were emitted and nulls filtered
        expect(emittedDurations, expectedDurations);
      },
    );

    test("onPositionChanged should expose player's positionStream", () async {
      // Arrange: Set up position tracking and completion trigger
      final completer = Completer<void>();
      final expectedPositions = [
        const Duration(seconds: 5),
        const Duration(seconds: 10),
      ];
      final emittedPositions = <Duration>[];

      // Act: Subscribe to position changes
      final subscription = audioPlayerAdapter.onPositionChanged.listen((
        position,
      ) {
        emittedPositions.add(position);
        if (emittedPositions.length == expectedPositions.length) {
          completer.complete();
        }
      });

      // Add test position events
      positionController.add(expectedPositions[0]);
      positionController.add(expectedPositions[1]);

      // Wait for all positions to be processed
      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('Stream test timed out'),
      );

      // Clean up
      await subscription.cancel();

      // Assert: Verify expected positions were emitted
      expect(emittedPositions, expectedPositions);
    });

    test(
      'onPlayerComplete should emit when processing state is completed',
      () async {
        // Arrange: Set up completion tracking
        final completer = Completer<void>();
        int completeEvents = 0;

        // Act: Subscribe to completion events
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

        // Wait for completion
        await completer.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => throw TimeoutException('Stream test timed out'),
        );

        // Clean up
        await subscription.cancel();

        // Assert: Verify exactly one completion event was emitted
        expect(
          completeEvents,
          1,
          reason: 'Should emit exactly once when state is completed',
        );
      },
    );
  });

  // ==========================================================================
  // Duration Retrieval Tests
  // ==========================================================================

  group('getDuration', () {
    test(
      'resolves relative path using PathResolver and returns duration',
      () async {
        // Arrange
        final mockTempPlayer = MockAudioPlayer();
        const relativePath = 'audio/test.m4a';
        const absolutePath = '/abs/path/audio/test.m4a';
        const tDuration = Duration(seconds: 42);

        // Stub the path resolver for this test
        when(
          mockPathResolver.resolve(relativePath, mustExist: true),
        ).thenAnswer((_) async => absolutePath);

        // Stub the temp player behavior
        when(
          mockTempPlayer.setFilePath(absolutePath),
        ).thenAnswer((_) async => tDuration);
        when(mockTempPlayer.dispose()).thenAnswer((_) async {});

        // Factory that returns our mock player
        AudioPlayer mockFactory() => mockTempPlayer;

        // Create adapter with the mocks
        final adapter = AudioPlayerAdapterImpl(
          mockAudioPlayer,
          pathResolver: mockPathResolver,
          audioPlayerFactory: mockFactory,
        );

        // Act
        final result = await adapter.getDuration(relativePath);

        // Assert
        expect(result, tDuration);
        verify(
          mockPathResolver.resolve(relativePath, mustExist: true),
        ).called(1);
        verify(mockTempPlayer.setFilePath(absolutePath)).called(1);
        verify(mockTempPlayer.dispose()).called(1);
      },
    );

    test(
      'throws if PathResolver throws and does not call just_audio',
      () async {
        // Arrange
        final mockTempPlayer = MockAudioPlayer();
        const relativePath = 'audio/missing.m4a';
        final exception = PathResolutionException('not found');

        // Stub the path resolver to throw
        when(
          mockPathResolver.resolve(relativePath, mustExist: true),
        ).thenThrow(exception);

        // Factory that returns our mock
        AudioPlayer mockFactory() => mockTempPlayer;

        final adapter = AudioPlayerAdapterImpl(
          mockAudioPlayer,
          pathResolver: mockPathResolver,
          audioPlayerFactory: mockFactory,
        );

        // Act & Assert
        await expectLater(
          adapter.getDuration(relativePath),
          throwsA(isA<PathResolutionException>()),
        );
        verify(
          mockPathResolver.resolve(relativePath, mustExist: true),
        ).called(1);
        verifyNever(mockTempPlayer.setFilePath(any));
      },
    );

    test('returns duration when setFilePath is successful', () async {
      // Arrange: Create a mock temporary player
      final mockTempPlayer = MockAudioPlayer();
      const relativePath = 'audio/test.m4a';
      const absolutePath = '/test/audio.m4a';
      const tDuration = Duration(seconds: 42);

      // First stub the path resolver to return the expected absolute path
      when(
        mockPathResolver.resolve(relativePath, mustExist: true),
      ).thenAnswer((_) async => absolutePath);

      // Configure the mock player behavior
      when(
        mockTempPlayer.setFilePath(absolutePath),
      ).thenAnswer((_) async => tDuration);
      when(mockTempPlayer.dispose()).thenAnswer((_) async {});

      // Create a factory that returns our mock
      AudioPlayer mockFactory() => mockTempPlayer;

      // Create adapter with the mock factory
      final adapter = AudioPlayerAdapterImpl(
        mockAudioPlayer,
        audioPlayerFactory: mockFactory,
        pathResolver: mockPathResolver,
      );

      // Act: Get duration using the adapter
      final result = await adapter.getDuration(relativePath);

      // Assert: Verify correct duration is returned and resources are released
      expect(result, tDuration);
      verify(mockTempPlayer.setFilePath(absolutePath)).called(1);
      verify(mockTempPlayer.dispose()).called(1);
    });

    test('throws when setFilePath returns null', () async {
      // Arrange: Create a mock temporary player returning null
      final mockTempPlayer = MockAudioPlayer();
      const relativePath = 'audio/test.m4a';
      const absolutePath = '/test/audio.m4a';

      // First stub the path resolver to return the expected absolute path
      when(
        mockPathResolver.resolve(relativePath, mustExist: true),
      ).thenAnswer((_) async => absolutePath);

      // Configure the mock player to return null (indicating invalid file)
      when(
        mockTempPlayer.setFilePath(absolutePath),
      ).thenAnswer((_) async => null);
      when(mockTempPlayer.dispose()).thenAnswer((_) async {});

      // Create a factory that returns our mock
      AudioPlayer mockFactory() => mockTempPlayer;

      // Create adapter with the mock factory
      final adapter = AudioPlayerAdapterImpl(
        mockAudioPlayer,
        audioPlayerFactory: mockFactory,
        pathResolver: mockPathResolver,
      );

      // Act & Assert: Verify exception is thrown for null duration
      await expectLater(
        adapter.getDuration(relativePath),
        throwsA(isA<Exception>()),
      );

      // Verify resources are properly released
      verify(mockTempPlayer.setFilePath(absolutePath)).called(1);
      verify(mockTempPlayer.dispose()).called(1);
    });

    test('throws when setFilePath throws PlayerException', () async {
      // Arrange: Create a mock temporary player that throws
      final mockTempPlayer = MockAudioPlayer();
      const relativePath = 'audio/test.m4a';
      const absolutePath = '/test/audio.m4a';
      final playerException = PlayerException(404, 'File not found');

      // First stub the path resolver to return the expected absolute path
      when(
        mockPathResolver.resolve(relativePath, mustExist: true),
      ).thenAnswer((_) async => absolutePath);

      // Configure the mock player to throw an exception
      when(mockTempPlayer.setFilePath(absolutePath)).thenThrow(playerException);
      when(mockTempPlayer.dispose()).thenAnswer((_) async {});

      // Create a factory that returns our mock
      AudioPlayer mockFactory() => mockTempPlayer;

      // Create adapter with the mock factory
      final adapter = AudioPlayerAdapterImpl(
        mockAudioPlayer,
        audioPlayerFactory: mockFactory,
        pathResolver: mockPathResolver,
      );

      // Act & Assert: Verify exception is propagated
      await expectLater(
        adapter.getDuration(relativePath),
        throwsA(isA<PlayerException>()),
      );

      // Verify resources are properly released
      verify(mockTempPlayer.setFilePath(absolutePath)).called(1);
      verify(mockTempPlayer.dispose()).called(1);
    });

    test('always disposes player even on error', () async {
      // Arrange: Create a mock temporary player that throws
      final mockTempPlayer = MockAudioPlayer();
      const relativePath = 'audio/test.m4a';
      const absolutePath = '/test/audio.m4a';

      // First stub the path resolver to return the expected absolute path
      when(
        mockPathResolver.resolve(relativePath, mustExist: true),
      ).thenAnswer((_) async => absolutePath);

      // Configure the mock player to throw a generic exception
      when(
        mockTempPlayer.setFilePath(absolutePath),
      ).thenThrow(Exception('fail'));
      when(mockTempPlayer.dispose()).thenAnswer((_) async {});

      // Create a factory that returns our mock
      AudioPlayer mockFactory() => mockTempPlayer;

      // Create adapter with the mock factory
      final adapter = AudioPlayerAdapterImpl(
        mockAudioPlayer,
        audioPlayerFactory: mockFactory,
        pathResolver: mockPathResolver,
      );

      // Act: Call getDuration and catch the exception
      try {
        await adapter.getDuration(relativePath);
      } catch (_) {}

      // Assert: Verify player is disposed even after error
      verify(mockTempPlayer.dispose()).called(1);
    });
  });
}

// IMPORTANT: After saving this file, run:
// flutter pub run build_runner build --delete-conflicting-outputs
// to regenerate the audio_player_adapter_impl_test.mocks.dart file.
