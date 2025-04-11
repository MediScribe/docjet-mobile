import 'dart:async'; // Needed for StreamController

import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:docjet_mobile/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart'; // <-- Import the new Domain State
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Import the generated mocks file
import 'audio_player_adapter_impl_test.mocks.dart';

// Generate mocks for the AudioPlayer class
@GenerateMocks([audioplayers.AudioPlayer]) // Use aliased import
void main() {
  late MockAudioPlayer mockAudioPlayer;
  late AudioPlayerAdapter audioPlayerAdapter;
  late StreamController<audioplayers.PlayerState> playerStateController;

  setUp(() {
    mockAudioPlayer = MockAudioPlayer();
    audioPlayerAdapter = AudioPlayerAdapterImpl(mockAudioPlayer);

    // Setup stream controller for player state
    playerStateController =
        StreamController<audioplayers.PlayerState>.broadcast();
    // Stub the mock player's stream getter
    when(
      mockAudioPlayer.onPlayerStateChanged,
    ).thenAnswer((_) => playerStateController.stream);

    // Stub other streams for completeness, though not focus of this change
    when(
      mockAudioPlayer.onDurationChanged,
    ).thenAnswer((_) => StreamController<Duration>.broadcast().stream);
    when(
      mockAudioPlayer.onPositionChanged,
    ).thenAnswer((_) => StreamController<Duration>.broadcast().stream);
    when(
      mockAudioPlayer.onPlayerComplete,
    ).thenAnswer((_) => StreamController<void>.broadcast().stream);
  });

  tearDown(() {
    playerStateController.close();
  });

  group('pause', () {
    test('should call pause on AudioPlayer', () async {
      // Arrange
      // Define mock behavior: when pause is called, return success
      when(mockAudioPlayer.pause()).thenAnswer((_) async {});

      // Act
      await audioPlayerAdapter.pause();

      // Assert
      verify(mockAudioPlayer.pause()).called(1);
    });
  });

  group('resume', () {
    test('should call resume on AudioPlayer', () async {
      // Arrange
      // Define mock behavior: when resume is called, return success
      when(mockAudioPlayer.resume()).thenAnswer((_) async {});

      // Act
      await audioPlayerAdapter.resume();

      // Assert
      verify(mockAudioPlayer.resume()).called(1);
    });
  });

  group('seek', () {
    test('should call seek on AudioPlayer with correct position', () async {
      // Arrange
      const position = Duration(seconds: 10);
      // Define mock behavior: when seek is called, return success
      when(mockAudioPlayer.seek(any)).thenAnswer((_) async {});

      // Act
      await audioPlayerAdapter.seek(position);

      // Assert
      verify(mockAudioPlayer.seek(position)).called(1);
    });
  });

  group('stop', () {
    test('should call stop on AudioPlayer', () async {
      // Arrange
      // Define mock behavior: when stop is called, return success
      when(mockAudioPlayer.stop()).thenAnswer((_) async {});

      // Act
      await audioPlayerAdapter.stop();

      // Assert
      verify(mockAudioPlayer.stop()).called(1);
    });
  });

  group('setSourceUrl', () {
    // Test Red 1: Local File Path
    test(
      'should call setSource on AudioPlayer with DeviceFileSource for local paths',
      () async {
        // Arrange
        const localPath =
            '/var/mobile/Containers/Data/Application/some-uuid/tmp/my_audio.m4a';
        // Expect setSource to be called, not setSourceUrl
        when(mockAudioPlayer.setSource(any)).thenAnswer((_) async => {});

        // Act
        await audioPlayerAdapter.setSourceUrl(localPath);

        // Assert
        // Verify setSource was called exactly once and capture the Source argument
        final verification = verify(mockAudioPlayer.setSource(captureAny));
        verification.called(1);

        // Assert: Check the captured argument is DeviceFileSource with the correct path
        final capturedSource =
            verification.captured.single as audioplayers.Source;
        expect(capturedSource, isA<audioplayers.DeviceFileSource>());
        expect(
          (capturedSource as audioplayers.DeviceFileSource).path,
          localPath,
        );
      },
    );

    // Test Red 2: Remote URL
    test(
      'should call setSource on AudioPlayer with UrlSource for remote URLs',
      () async {
        // Arrange
        const remoteUrl = 'https://example.com/audio.mp3';
        // Expect setSource to be called
        when(mockAudioPlayer.setSource(any)).thenAnswer((_) async => {});

        // Act
        await audioPlayerAdapter.setSourceUrl(remoteUrl);

        // Assert
        // Verify setSource was called exactly once and capture the Source argument
        final verification = verify(mockAudioPlayer.setSource(captureAny));
        verification.called(1);

        // Assert: Check the captured argument is UrlSource with the correct URL
        final capturedSource =
            verification.captured.single as audioplayers.Source;
        expect(capturedSource, isA<audioplayers.UrlSource>());
        expect((capturedSource as audioplayers.UrlSource).url, remoteUrl);
      },
    );
  });

  group('dispose', () {
    test('should call release and dispose on AudioPlayer', () async {
      // Arrange
      // Define mock behavior
      when(mockAudioPlayer.release()).thenAnswer((_) async {});
      when(mockAudioPlayer.dispose()).thenAnswer((_) async {});

      // Act
      await audioPlayerAdapter.dispose();

      // Assert
      // Use verifyInOrder to ensure release is called before dispose
      verifyInOrder([mockAudioPlayer.release(), mockAudioPlayer.dispose()]);
    });
  });

  group('streams', () {
    test(
      'onPlayerStateChanged should map audioplayers states to DomainPlayerState',
      () {
        // Arrange: Mock player is already set up in setUp to return playerStateController.stream
        final stream = audioPlayerAdapter.onPlayerStateChanged;

        // Assert: Expect the adapter's stream to emit correctly mapped DomainPlayerState values
        // when the underlying mock stream emits audioplayers states.
        expectLater(
          stream,
          emitsInOrder([
            DomainPlayerState.playing,
            DomainPlayerState.paused,
            DomainPlayerState.stopped,
            DomainPlayerState.completed,
            DomainPlayerState
                .initial, // Map unknown/other states if needed, or define error
          ]),
        );

        // Act: Push states into the mock controller
        playerStateController.add(audioplayers.PlayerState.playing);
        playerStateController.add(audioplayers.PlayerState.paused);
        playerStateController.add(audioplayers.PlayerState.stopped);
        playerStateController.add(audioplayers.PlayerState.completed);
        playerStateController.add(
          audioplayers.PlayerState.disposed,
        ); // Example of a state not directly mapped
      },
    );

    test("onDurationChanged should expose player's stream", () {
      // Arrange
      final testStream = StreamController<Duration>.broadcast().stream;
      when(mockAudioPlayer.onDurationChanged).thenAnswer((_) => testStream);

      // Act
      final stream = audioPlayerAdapter.onDurationChanged;

      // Assert
      expect(stream, same(testStream));
    });

    test("onPositionChanged should expose player's stream", () {
      // Arrange
      final testStream = StreamController<Duration>.broadcast().stream;
      when(mockAudioPlayer.onPositionChanged).thenAnswer((_) => testStream);

      // Act
      final stream = audioPlayerAdapter.onPositionChanged;

      // Assert
      expect(stream, same(testStream));
    });

    test("onPlayerComplete should expose player's stream", () {
      // Arrange
      final testStream = StreamController<void>.broadcast().stream;
      when(mockAudioPlayer.onPlayerComplete).thenAnswer((_) => testStream);

      // Act
      final stream = audioPlayerAdapter.onPlayerComplete;

      // Assert
      expect(stream, same(testStream));
    });
  });

  // More tests will go here
}
