import 'dart:async';

// import 'package:audioplayers/audioplayers.dart' as audioplayers; // REMOVED
// import 'package:just_audio/just_audio.dart'; // REMOVED
import 'package:just_audio/just_audio.dart'; // REMOVED ALIAS
import 'package:docjet_mobile/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Import the generated mocks file
import 'audio_player_adapter_impl_test.mocks.dart';

// Generate mocks for the AudioPlayer class from just_audio
@GenerateMocks([AudioPlayer]) // REMOVED ALIAS from annotation
void main() {
  late MockAudioPlayer
  mockAudioPlayer; // Mock type comes from generated file, leave as is
  late AudioPlayerAdapter audioPlayerAdapter;
  // Stream controller for just_audio's PlayerState objects
  late StreamController<PlayerState> playerStateController; // REMOVED ALIAS
  late StreamController<Duration?>
  durationController; // ADDED (just_audio duration is nullable)
  late StreamController<Duration> positionController; // ADDED

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

    // 4. Stub basic methods needed by implementation (or other tests)
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

    // 5. NOW instantiate the adapter implementation with the fully stubbed mock
    audioPlayerAdapter = AudioPlayerAdapterImpl(mockAudioPlayer);
  });

  tearDown(() {
    playerStateController.close();
    durationController.close(); // ADDED
    positionController.close(); // ADDED
  });

  // --- Keep existing test groups for pause, seek, stop, dispose, setSourceUrl ---
  // --- They will fail initially, which is expected in TDD ---
  // --- We will adapt them after running the build runner and fixing the implementation ---

  group('pause', () {
    test('should call pause on AudioPlayer', () async {
      // Arrange
      when(mockAudioPlayer.pause()).thenAnswer((_) async {});
      // Act
      await audioPlayerAdapter.pause();
      // Assert
      verify(mockAudioPlayer.pause()).called(1);
    });
  });

  // UPDATED: just_audio uses play(), not resume()
  group('resume (play)', () {
    test('should call play on AudioPlayer', () async {
      // Arrange
      when(mockAudioPlayer.play()).thenAnswer((_) async {});
      // Act
      await audioPlayerAdapter.resume(); // Adapter interface still uses resume
      // Assert
      verify(
        mockAudioPlayer.play(),
      ).called(1); // Expect play() on the underlying player
    });
  });

  group('seek', () {
    test('should call seek on AudioPlayer with correct position', () async {
      // Arrange
      const position = Duration(seconds: 10);
      when(
        mockAudioPlayer.seek(any, index: anyNamed('index')),
      ).thenAnswer((_) async {});
      // Act
      await audioPlayerAdapter.seek(position);
      // Assert
      // Verify seek was called with the correct position. index can be null/default.
      verify(mockAudioPlayer.seek(position, index: null)).called(1);
    });
  });

  group('stop', () {
    test('should call stop on AudioPlayer', () async {
      // Arrange
      when(mockAudioPlayer.stop()).thenAnswer((_) async {});
      // Act
      await audioPlayerAdapter.stop();
      // Assert
      verify(mockAudioPlayer.stop()).called(1);
    });
  });

  group('setSourceUrl', () {
    // UPDATED: Test just_audio's setAudioSource with AudioSource.file
    test(
      'should call setAudioSource on AudioPlayer with AudioSource.file for local paths',
      () async {
        // Arrange
        const localPath = '/path/to/local/audio.mp3';
        // Expect setAudioSource to be called
        when(mockAudioPlayer.setAudioSource(any)).thenAnswer(
          (_) async => const Duration(seconds: 60),
        ); // Return dummy duration

        // Act
        await audioPlayerAdapter.setSourceUrl(localPath);

        // Assert
        final verification = verify(mockAudioPlayer.setAudioSource(captureAny));
        verification.called(1);

        final capturedSource = verification.captured.single as AudioSource;
        expect(
          capturedSource,
          isA<UriAudioSource>(),
        ); // just_audio uses UriAudioSource for files too
        expect((capturedSource as UriAudioSource).uri.path, localPath);
        expect((capturedSource).uri.scheme, 'file'); // Check scheme
      },
    );

    // UPDATED: Test just_audio's setAudioSource with AudioSource.uri for remote URLs
    test(
      'should call setAudioSource on AudioPlayer with AudioSource.uri for remote URLs',
      () async {
        // Arrange
        const remoteUrl = 'https://example.com/audio.mp3';
        // Expect setAudioSource to be called
        when(mockAudioPlayer.setAudioSource(any)).thenAnswer(
          (_) async => const Duration(seconds: 60),
        ); // Return dummy duration

        // Act
        await audioPlayerAdapter.setSourceUrl(remoteUrl);

        // Assert
        final verification = verify(mockAudioPlayer.setAudioSource(captureAny));
        verification.called(1);

        final capturedSource = verification.captured.single as AudioSource;
        expect(capturedSource, isA<UriAudioSource>());
        expect((capturedSource as UriAudioSource).uri.toString(), remoteUrl);
      },
    );
  });

  group('dispose', () {
    test('should call dispose on AudioPlayer', () async {
      // Arrange
      when(mockAudioPlayer.dispose()).thenAnswer((_) async {});
      // Act
      await audioPlayerAdapter.dispose();
      // Assert
      // No release() in just_audio, just dispose
      verify(mockAudioPlayer.dispose()).called(1);
    });
  });

  // --- Completely rewrite stream tests for just_audio ---
  group('streams', () {
    test(
      'onPlayerStateChanged should map just_audio PlayerState to DomainPlayerState',
      () {
        // Arrange: Mock player is set up in setUp to return playerStateController.stream
        final stream = audioPlayerAdapter.onPlayerStateChanged;

        // Assert: Expect the adapter's stream to emit correctly mapped DomainPlayerState values
        // when the underlying mock stream emits just_audio PlayerState objects.
        expectLater(
          stream,
          emitsInOrder([
            DomainPlayerState.loading, // Initial state often implies loading
            DomainPlayerState.playing,
            DomainPlayerState.paused,
            DomainPlayerState.loading, // Buffering state maps to loading
            DomainPlayerState.playing, // Resumed after buffering
            DomainPlayerState.completed,
            DomainPlayerState.stopped, // Idle state maps to stopped/initial
          ]),
        );

        // Act: Push just_audio PlayerState objects into the mock controller
        playerStateController.add(PlayerState(false, ProcessingState.loading));
        playerStateController.add(
          PlayerState(true, ProcessingState.ready),
        ); // Playing
        playerStateController.add(
          PlayerState(false, ProcessingState.ready),
        ); // Paused
        playerStateController.add(
          PlayerState(true, ProcessingState.buffering),
        ); // Buffering (still playing technically)
        playerStateController.add(
          PlayerState(true, ProcessingState.ready),
        ); // Ready again, playing
        playerStateController.add(
          PlayerState(false, ProcessingState.completed),
        ); // Completed
        playerStateController.add(
          PlayerState(false, ProcessingState.idle),
        ); // Idle (stopped)
      },
    );

    test(
      "onDurationChanged should expose player's durationStream, filtering nulls",
      () {
        // Arrange
        final stream = audioPlayerAdapter.onDurationChanged;
        const duration1 = Duration(seconds: 60);
        const duration2 = Duration(seconds: 120);

        // Assert
        // Expect non-null durations to be passed through.
        expectLater(stream, emitsInOrder([duration1, duration2]));

        // Act
        durationController.add(null); // Should be filtered out
        durationController.add(duration1);
        durationController.add(null); // Should be filtered out
        durationController.add(duration2);
      },
    );

    test("onPositionChanged should expose player's positionStream", () {
      // Arrange
      final stream = audioPlayerAdapter.onPositionChanged;
      const position1 = Duration(seconds: 5);
      const position2 = Duration(seconds: 10);

      // Assert
      // Expect positions to be passed through directly.
      expectLater(stream, emitsInOrder([position1, position2]));

      // Act
      positionController.add(position1);
      positionController.add(position2);
    });

    test('onPlayerComplete should emit when processing state is completed', () {
      // Arrange
      final stream = audioPlayerAdapter.onPlayerComplete;

      // Assert
      expectLater(stream, emits(null)); // Emits void (represented as null)

      // Act
      playerStateController.add(PlayerState(false, ProcessingState.loading));
      playerStateController.add(PlayerState(true, ProcessingState.ready));
      playerStateController.add(
        PlayerState(false, ProcessingState.completed),
      ); // Should trigger emit
      playerStateController.add(PlayerState(false, ProcessingState.idle));
    });
  });

  // More tests will go here
}

// IMPORTANT: After saving this file, run:
// flutter pub run build_runner build --delete-conflicting-outputs
// to regenerate the audio_player_adapter_impl_test.mocks.dart file.
