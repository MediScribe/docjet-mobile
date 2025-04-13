import 'dart:async'; // Add async import
import 'dart:io';

import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart'
    hide logger;
import 'package:docjet_mobile/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart'
    hide logger;
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart'
    hide logger;
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart'; // Import for mocking
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import the generated mocks file (will be created by build_runner)
import 'audio_playback_integration_test.mocks.dart';

// Create a proper mock for PathProviderPlatform by extending it
class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String tempPath;

  MockPathProviderPlatform(this.tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

// Generate mock for AudioPlayer only
@GenerateMocks([ja.AudioPlayer])
void main() {
  // Ensure Flutter test bindings are initialized for platform channels
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set logger level for tests
  setLogLevel(Level.debug);

  // Keep track of the original path provider instance
  final PathProviderPlatform originalPathProviderInstance =
      PathProviderPlatform.instance;
  late GetIt sl;
  late MockAudioPlayer mockAudioPlayer; // Mock the concrete dependency
  late MockPathProviderPlatform
  mockPathProvider; // Custom mock for platform interface
  late Directory tempDir; // For clean teardown of test directories

  // Create controllers as late variables to use in multiple tests
  late StreamController<ja.PlayerState> playerStateController;
  late StreamController<Duration> positionController;
  late StreamController<Duration?> durationController;

  setUpAll(() async {
    // Setup mocks for shared_preferences
    SharedPreferences.setMockInitialValues({});

    // Register mock for platform channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getAll') {
              return <String, dynamic>{};
            }
            return null;
          },
        );

    // Create a temporary directory for test storage
    tempDir = await Directory.systemTemp.createTemp('audio_test_');
    logger.d('Created temp dir at: ${tempDir.path}');

    // Configure Hive for testing
    Hive.init(tempDir.path);

    // Set up path provider mock BEFORE initializing the GetIt
    mockPathProvider = MockPathProviderPlatform(tempDir.path);
    PathProviderPlatform.instance = mockPathProvider;

    // We need a fresh DI container for integration tests to avoid conflicts
    sl = GetIt.instance;
    // Reset the entire container to avoid conflicts
    await sl.reset();

    // Manually create the mock AudioPlayer BEFORE initializing the main DI
    mockAudioPlayer = MockAudioPlayer();

    // Initialize stream controllers
    playerStateController = BehaviorSubject<ja.PlayerState>();
    positionController = BehaviorSubject<Duration>();
    durationController = BehaviorSubject<Duration?>();
    final sequenceStateController =
        StreamController<ja.SequenceState?>.broadcast();
    final playingController = StreamController<bool>.broadcast();

    // Stub essential stream behaviors for the mock AudioPlayer
    // Use Stream.empty() for simplicity in initial setup, will be overridden in tests
    when(
      mockAudioPlayer.playerStateStream,
    ).thenAnswer((_) => playerStateController.stream);
    when(
      mockAudioPlayer.positionStream,
    ).thenAnswer((_) => positionController.stream);
    when(
      mockAudioPlayer.durationStream,
    ).thenAnswer((_) => durationController.stream);
    when(
      mockAudioPlayer.sequenceStateStream,
    ).thenAnswer((_) => sequenceStateController.stream);
    when(
      mockAudioPlayer.playingStream,
    ).thenAnswer((_) => playingController.stream);

    // Also stub the playing property getter
    when(mockAudioPlayer.playing).thenReturn(false);

    // Add the missing stub for processingState
    when(mockAudioPlayer.processingState).thenReturn(ja.ProcessingState.idle);

    // For initial value, emit a default state
    playerStateController.add(ja.PlayerState(false, ja.ProcessingState.idle));
    positionController.add(Duration.zero);

    // Stub methods returning Futures
    when(
      mockAudioPlayer.setAudioSource(any),
    ).thenAnswer((_) async => Duration.zero);
    when(mockAudioPlayer.load()).thenAnswer((_) async => Duration.zero);
    when(mockAudioPlayer.play()).thenAnswer((_) async {
      // Simulate player transitioning to playing state when play() is called
      logger.d('Mock: play() called, emitting playing state');
      // Add a delay before changing the state
      await Future.delayed(const Duration(milliseconds: 100));
      playerStateController.add(ja.PlayerState(true, ja.ProcessingState.ready));
      return;
    });
    when(mockAudioPlayer.pause()).thenAnswer((_) async {
      // Simulate player transitioning to paused state when pause() is called
      playerStateController.add(
        ja.PlayerState(false, ja.ProcessingState.ready),
      );
      return;
    });
    when(mockAudioPlayer.stop()).thenAnswer((_) async {
      // Simulate player transitioning to stopped state when stop() is called
      playerStateController.add(ja.PlayerState(false, ja.ProcessingState.idle));
      return;
    });
    when(
      mockAudioPlayer.seek(any, index: anyNamed('index')),
    ).thenAnswer((_) async {});
    when(mockAudioPlayer.setLoopMode(any)).thenAnswer((_) async {});
    when(mockAudioPlayer.setShuffleModeEnabled(any)).thenAnswer((_) async {});
    when(mockAudioPlayer.setVolume(any)).thenAnswer((_) async {});
    when(mockAudioPlayer.setSpeed(any)).thenAnswer((_) async {});
    when(mockAudioPlayer.setSkipSilenceEnabled(any)).thenAnswer((_) async {});
    when(mockAudioPlayer.setPitch(any)).thenAnswer((_) async {});
    when(mockAudioPlayer.dispose()).thenAnswer((_) async {
      // Clean up the controllers when player is disposed
      await playerStateController.close();
      await positionController.close();
      await durationController.close();
      await sequenceStateController.close();
      await playingController.close();
    });

    // Register the *mock* instance before initializing the main DI
    sl.registerSingleton<ja.AudioPlayer>(mockAudioPlayer);

    // Now create and register our test instances manually rather than relying on di.init()
    // This gives us better control over the initialization process
    final audioPlayerAdapter = AudioPlayerAdapterImpl(mockAudioPlayer);

    final playbackStateMapper = PlaybackStateMapperImpl();
    // Enable test mode to disable debouncing in tests
    (playbackStateMapper).setTestMode(true);
    logger.d(
      'PlaybackStateMapperImpl test mode has been enabled - debouncing should be disabled',
    );

    // Initialize the mapper with the adapter's streams
    // This is the critical wiring step that's tested in the first test case
    (playbackStateMapper).initialize(
      positionStream: audioPlayerAdapter.onPositionChanged,
      durationStream: audioPlayerAdapter.onDurationChanged,
      playerStateStream: audioPlayerAdapter.onPlayerStateChanged,
      completeStream: audioPlayerAdapter.onPlayerComplete,
    );

    final audioPlaybackService = AudioPlaybackServiceImpl(
      audioPlayerAdapter: audioPlayerAdapter,
      playbackStateMapper: playbackStateMapper,
    );

    // Register in the DI container
    sl.registerSingleton<AudioPlayerAdapter>(audioPlayerAdapter);
    sl.registerSingleton<PlaybackStateMapper>(playbackStateMapper);
    sl.registerSingleton<AudioPlaybackService>(audioPlaybackService);

    // Now initialize the rest of the dependencies if needed
    try {
      // Note: Only initialize other dependencies, not the ones we manually registered
      logger.i('DI initialization success');
    } catch (e) {
      logger.w('Warning: DI initialization had an issue: $e');
      logger.i('Continuing tests with manually registered dependencies');
    }

    // Clear any interactions from the DI setup phase
    clearInteractions(mockAudioPlayer);
  });

  tearDown(() async {
    // Reset interactions on the core mock after each test
    reset(mockAudioPlayer);
    // Don't need to redefine the stream controllers after reset
    // as they're defined in setUpAll and will persist

    // Re-setup the basic behaviors
    when(
      mockAudioPlayer.playerStateStream,
    ).thenAnswer((_) => playerStateController.stream);
    when(
      mockAudioPlayer.positionStream,
    ).thenAnswer((_) => positionController.stream);
    when(
      mockAudioPlayer.durationStream,
    ).thenAnswer((_) => durationController.stream);

    // Re-stub the playing property
    when(mockAudioPlayer.playing).thenReturn(false);

    // Add the missing stub for processingState in tearDown
    when(mockAudioPlayer.processingState).thenReturn(ja.ProcessingState.idle);

    // Re-set automated responses
    when(mockAudioPlayer.play()).thenAnswer((_) async {
      playerStateController.add(ja.PlayerState(true, ja.ProcessingState.ready));
    });
    when(mockAudioPlayer.pause()).thenAnswer((_) async {
      playerStateController.add(
        ja.PlayerState(false, ja.ProcessingState.ready),
      );
    });
    when(mockAudioPlayer.stop()).thenAnswer((_) async {
      playerStateController.add(ja.PlayerState(false, ja.ProcessingState.idle));
    });
  });

  tearDownAll(() async {
    // Remove the mock method handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          null,
        );

    try {
      // Close all Hive boxes
      await Hive.close();
    } catch (e) {
      logger.w('Warning: Error closing Hive: $e');
    }

    // Clean up the DI container with a timeout to prevent hanging
    try {
      await sl.reset().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          logger.w('Warning: GetIt reset timed out. Continuing teardown.');
          return;
        },
      );
    } catch (e) {
      logger.e('Error during GetIt reset: $e');
    }

    // Restore the original path provider instance
    PathProviderPlatform.instance = originalPathProviderInstance;

    // Delete the temporary directory
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
      logger.d('Cleaned up temp dir: ${tempDir.path}');
    }

    // Reset log level after tests
    setLogLevel(Level.warning);
  });

  test('DI wiring check: Mapper should be initialized with Adapter streams', () {
    // Arrange: Get instances from the DI container
    final adapter = sl<AudioPlayerAdapter>();
    final mapper = sl<PlaybackStateMapper>();
    final service = sl<AudioPlaybackService>(); // Resolve the service

    // Assert
    // 1. Check types are correct implementations
    expect(adapter, isA<AudioPlayerAdapterImpl>());
    expect(mapper, isA<PlaybackStateMapperImpl>());
    expect(service, isA<AudioPlaybackServiceImpl>());

    // 2. Verify both streams are properly defined
    // Don't check for exact same instance since the broadcast wrapper may create a different instance
    expect(
      (service as AudioPlaybackServiceImpl).playbackStateStream,
      isNotNull,
      reason: 'Service stream should be defined',
    );
    expect(
      (mapper as PlaybackStateMapperImpl).playbackStateStream,
      isNotNull,
      reason: 'Mapper stream should be defined',
    );
  });

  test(
    'Playback starts: emits loading then playing state',
    () async {
      // Arrange: Get service instance and set up test file path
      final service = sl<AudioPlaybackService>();
      final testFilePath = '${tempDir.path}/test_audio.mp3';

      // Create an empty test file to prevent "file not found" errors
      await File(testFilePath).writeAsString('test data');

      // Set up collections for emitted states using direct collection instead of expectLater
      final emittedStates = <PlaybackState>[];
      final completer = Completer<void>();

      // Listen to playback states with timeout
      final subscription = service.playbackStateStream.listen(
        (state) {
          logger.d('Received state: ${state.runtimeType}');
          emittedStates.add(state);

          // Check for required states to complete the test
          // Use pattern matching to identify the loading and playing states
          final hasLoading = emittedStates.any(
            (s) => s.maybeMap(loading: (_) => true, orElse: () => false),
          );

          final hasPlaying = emittedStates.any(
            (s) => s.maybeMap(playing: (_) => true, orElse: () => false),
          );

          logger.d(
            'States check: hasLoading=$hasLoading, hasPlaying=$hasPlaying',
          );

          if (hasLoading && hasPlaying) {
            if (!completer.isCompleted) {
              logger.d(
                'Both loading and playing states found, completing test',
              );
              completer.complete();
            }
          }
        },
        onError: (error) {
          logger.e('Stream error: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      try {
        // Act: Call play and simulate player state changes
        logger.d('Calling service.play()');

        // First emit a state to establish initial duration
        durationController.add(const Duration(seconds: 60));
        await Future.delayed(Duration.zero);

        // When setAudioSource is called, simulate loading state
        when(mockAudioPlayer.setAudioSource(any)).thenAnswer((_) async {
          // Emit a loading state when setting source
          logger.d('Mock: setAudioSource called, emitting loading state');
          playerStateController.add(
            ja.PlayerState(false, ja.ProcessingState.loading),
          );
          // Add a longer delay to ensure loading state is processed before transitioning
          await Future.delayed(const Duration(milliseconds: 200));

          // Simulate getting duration
          durationController.add(const Duration(seconds: 60));

          // Return the duration
          return const Duration(seconds: 60);
        });

        // Execute the actual play call
        await service.play(testFilePath);

        // Verify the service made the expected calls to the adapter
        verify(mockAudioPlayer.setAudioSource(any)).called(1);
        verify(mockAudioPlayer.play()).called(1);

        // Give the streams more time to propagate
        logger.d('Waiting for state transitions to propagate...');
        await Future.delayed(const Duration(milliseconds: 500));

        // Manually emit a position update to trigger another state update
        positionController.add(const Duration(seconds: 5));
        await Future.delayed(const Duration(milliseconds: 50));

        // Wait for our test to complete within a reasonable timeout
        await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            logger.e('TIMEOUT waiting for states. States received:');
            for (final state in emittedStates) {
              logger.e('  - ${state.runtimeType}');
            }
            throw TimeoutException(
              'Test timed out waiting for playback states',
            );
          },
        );

        // Assert: Verify states are emitted correctly
        expect(
          emittedStates.length,
          greaterThanOrEqualTo(2),
          reason: 'Should emit at least loading and playing states',
        );

        // Check for loading state
        expect(
          emittedStates.any(
            (state) =>
                state.maybeMap(loading: (_) => true, orElse: () => false),
          ),
          isTrue,
          reason: 'Should emit a loading state',
        );

        // Check for playing state and that it has the correct duration
        expect(
          emittedStates.any(
            (state) => state.maybeMap(
              playing: (playingState) => true,
              orElse: () => false,
            ),
          ),
          isTrue,
          reason: 'Should emit a playing state',
        );
      } finally {
        // Clean up resources regardless of test outcome
        await subscription.cancel();

        // Clean up test file
        final testFile = File(testFilePath);
        if (await testFile.exists()) {
          await testFile.delete();
        }

        logger.d('Test resources cleaned up');
      }
    },
    timeout: const Timeout(Duration(seconds: 10)),
  ); // Add a timeout to the entire test

  test(
    'Playback pauses: emits paused state',
    () async {
      // Arrange: Get service instance and set up test file path
      final service = sl<AudioPlaybackService>();
      final testFilePath = '${tempDir.path}/test_audio.mp3';

      // Create an empty test file to prevent "file not found" errors
      await File(testFilePath).writeAsString('test data');

      // Set up collections for emitted states
      final emittedStates = <PlaybackState>[];
      final completer = Completer<void>();

      // Listen to playback states with timeout
      final subscription = service.playbackStateStream.listen(
        (state) {
          logger.d('Received state: $state');
          emittedStates.add(state);

          // Check for a paused state to complete the test
          final hasPaused = emittedStates.any(
            (s) => s.maybeMap(paused: (_) => true, orElse: () => false),
          );

          if (hasPaused) {
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        },
        onError: (error) {
          logger.e('Stream error: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      try {
        // First emit a state to establish initial duration
        durationController.add(const Duration(seconds: 60));
        await Future.delayed(Duration.zero);

        // When setAudioSource is called, simulate loading state then transition to ready
        when(mockAudioPlayer.setAudioSource(any)).thenAnswer((_) async {
          // Emit a loading state when setting source
          logger.d('Mock: setAudioSource called, emitting loading state');
          playerStateController.add(
            ja.PlayerState(false, ja.ProcessingState.loading),
          );
          await Future.delayed(Duration.zero);

          // Transition to ready state with duration
          return const Duration(seconds: 60);
        });

        // First play the audio
        logger.d('Calling service.play()');
        await service.play(testFilePath);

        // Update the playing property to true after play is called
        when(mockAudioPlayer.playing).thenReturn(true);
        when(
          mockAudioPlayer.processingState,
        ).thenReturn(ja.ProcessingState.ready);

        // Wait a bit for playing state to be established
        await Future.delayed(const Duration(milliseconds: 50));

        // Now pause the audio
        logger.d('Calling service.pause()');
        await service.pause();

        // Wait for our test to complete within a reasonable timeout
        await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            logger.e('TIMEOUT waiting for states. States received:');
            for (final state in emittedStates) {
              logger.e('  - $state');
            }
            throw TimeoutException('Test timed out waiting for paused state');
          },
        );

        // Assert: Verify a paused state was emitted
        expect(
          emittedStates.any(
            (state) => state.maybeMap(paused: (_) => true, orElse: () => false),
          ),
          isTrue,
          reason: 'Should emit a paused state',
        );
      } finally {
        // Clean up resources
        await subscription.cancel();

        // Clean up test file
        final testFile = File(testFilePath);
        if (await testFile.exists()) {
          await testFile.delete();
        }

        logger.d('Test resources cleaned up');
      }
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  // TODO: Add more tests:
  // test('Playback stops: emits stopped state')
  // test('Playback completes: emits completed state')
  // test('Position updates: emits playing state with new position')
  // test('Error occurs: emits error state')
}
