import 'dart:async'; // Needed for StreamController

import 'package:audioplayers/audioplayers.dart';
import 'package:docjet_mobile/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart'; // Implementation (will be created)
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart'; // Interface
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Import the generated mocks file
import 'audio_player_adapter_impl_test.mocks.dart';

// Generate mocks for the AudioPlayer class
@GenerateMocks([AudioPlayer])
void main() {
  late MockAudioPlayer mockAudioPlayer;
  late AudioPlayerAdapter audioPlayerAdapter;

  setUp(() {
    // Arrange: Create a fresh mock for each test
    mockAudioPlayer = MockAudioPlayer();
    // Arrange: Instantiate the adapter implementation with the mock player
    // Note: This requires AudioPlayerAdapterImpl to be created first!
    // For now, we write the test assuming it exists.
    audioPlayerAdapter = AudioPlayerAdapterImpl(mockAudioPlayer);
  });

  group('play', () {
    test('should call play on AudioPlayer with correct source', () async {
      // Arrange
      const filePath = '/path/to/audio.mp3';
      final expectedSource = DeviceFileSource(filePath);

      // Define the mock behavior: when play is called with any source, return success
      // We use 'any' here because DeviceFileSource doesn't implement == correctly for mockito matching
      // We'll verify the source type and path separately.
      when(mockAudioPlayer.play(any)).thenAnswer((_) async {});

      // Act
      await audioPlayerAdapter.play(filePath);

      // Assert
      // Verify that play was called exactly once
      // and capture the argument passed to it.
      final verification = verify(mockAudioPlayer.play(captureAny));
      verification.called(1);

      // Assert: Check the captured argument
      final capturedSource = verification.captured.single as Source;
      expect(capturedSource, isA<DeviceFileSource>());
      expect((capturedSource as DeviceFileSource).path, filePath);
    });
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
    test(
      'should call setSourceUrl on AudioPlayer with correct source',
      () async {
        // Arrange
        const url = 'http://example.com/audio.mp3';
        final expectedSource = UrlSource(url);
        // Define mock behavior
        when(mockAudioPlayer.setSourceUrl(any)).thenAnswer((_) async {});

        // Act
        await audioPlayerAdapter.setSourceUrl(url);

        // Assert
        // Verify setSourceUrl was called exactly once and capture the argument
        final verification = verify(mockAudioPlayer.setSourceUrl(captureAny));
        verification.called(1);

        // Assert: Check the captured argument
        final capturedUrl = verification.captured.single as String;
        expect(capturedUrl, url);

        // Note: We originally used UrlSource, but setSourceUrl takes a String.
        // Let's verify the String argument directly.
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
    test("onPlayerStateChanged should expose player's stream", () {
      // Arrange
      final testStream = StreamController<PlayerState>.broadcast().stream;
      when(mockAudioPlayer.onPlayerStateChanged).thenAnswer((_) => testStream);

      // Act
      final stream = audioPlayerAdapter.onPlayerStateChanged;

      // Assert
      expect(
        stream,
        same(testStream),
      ); // Use 'same' to check for identical stream instance
    });

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
