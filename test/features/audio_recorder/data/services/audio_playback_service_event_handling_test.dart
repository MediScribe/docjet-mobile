// Imports
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
// Use fake_async

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

  group('Event Handling', () {
    // Test cases will be rewritten here to match the new implementation.
  });
}
