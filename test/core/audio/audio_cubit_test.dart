import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:docjet_mobile/core/audio/audio_player_service.dart';
import 'package:docjet_mobile/core/audio/audio_recorder_service.dart';
import 'package:docjet_mobile/core/audio/audio_state.dart';
import 'package:docjet_mobile/core/audio/audio_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'audio_cubit_test.mocks.dart';

@GenerateMocks([AudioRecorderService, AudioPlayerService])
void main() {
  group('AudioCubit', () {
    late MockAudioRecorderService mockRecorder;
    late MockAudioPlayerService mockPlayer;
    late AudioCubit audioCubit;

    late StreamController<Duration> recorderElapsedController;
    late StreamController<Duration> playerPositionController;
    late StreamController<Duration> playerDurationController;
    late StreamController<ProcessingState> processingStateController;

    const testFilePath = '/test/file/path.m4a';

    setUp(() {
      mockRecorder = MockAudioRecorderService();
      mockPlayer = MockAudioPlayerService();

      // Set up stream controllers
      recorderElapsedController = StreamController<Duration>.broadcast();
      playerPositionController = StreamController<Duration>.broadcast();
      playerDurationController = StreamController<Duration>.broadcast();
      processingStateController = StreamController<ProcessingState>.broadcast();

      // Mock stream getters
      when(
        mockRecorder.elapsed$,
      ).thenAnswer((_) => recorderElapsedController.stream.asBroadcastStream());
      when(
        mockPlayer.position$,
      ).thenAnswer((_) => playerPositionController.stream.asBroadcastStream());
      when(
        mockPlayer.duration$,
      ).thenAnswer((_) => playerDurationController.stream.asBroadcastStream());
      when(
        mockPlayer.processingState$,
      ).thenAnswer((_) => processingStateController.stream.asBroadcastStream());

      // Default method implementations
      when(mockRecorder.start()).thenAnswer((_) async {});
      when(mockRecorder.pause()).thenAnswer((_) async {});
      when(mockRecorder.resume()).thenAnswer((_) async {});
      when(mockRecorder.stop()).thenAnswer((_) async => testFilePath);

      when(mockPlayer.load(any)).thenAnswer((_) async {});
      when(mockPlayer.play()).thenAnswer((_) async {});
      when(mockPlayer.pause()).thenAnswer((_) async {});
      when(mockPlayer.seek(any)).thenAnswer((_) async {});
      when(mockPlayer.reset()).thenAnswer((_) async {});

      audioCubit = AudioCubit(
        recorderService: mockRecorder,
        playerService: mockPlayer,
      );
    });

    tearDown(() {
      recorderElapsedController.close();
      playerPositionController.close();
      playerDurationController.close();
      processingStateController.close();
      audioCubit.close();
    });

    test('initial state is correct', () {
      expect(audioCubit.state, equals(const AudioState.initial()));
    });

    group('recording flow', () {
      blocTest<AudioCubit, AudioState>(
        'emits recording states when recording is started and elapsed time changes',
        build: () => audioCubit,
        act: (cubit) async {
          await cubit.startRecording();
          // Simulate elapsed time updates (250ms interval)
          recorderElapsedController.add(const Duration(milliseconds: 250));
          await Future.delayed(const Duration(milliseconds: 80));
          recorderElapsedController.add(const Duration(milliseconds: 500));
        },
        wait: const Duration(milliseconds: 120),
        expect:
            () => [
              const AudioState(
                phase: AudioPhase.recording,
                position: Duration.zero,
                duration: Duration.zero,
              ),
              const AudioState(
                phase: AudioPhase.recording,
                position: Duration(milliseconds: 250),
                duration: Duration.zero,
              ),
              const AudioState(
                phase: AudioPhase.recording,
                position: Duration(milliseconds: 500),
                duration: Duration.zero,
              ),
            ],
        verify: (_) {
          verify(mockRecorder.start()).called(1);
        },
      );

      blocTest<AudioCubit, AudioState>(
        'pauses recording and emits paused state',
        build: () => audioCubit,
        seed:
            () => const AudioState(
              phase: AudioPhase.recording,
              position: Duration(milliseconds: 750),
              duration: Duration.zero,
            ),
        act: (cubit) async {
          await cubit.pauseRecording();
        },
        expect:
            () => [
              const AudioState(
                phase: AudioPhase.recordingPaused,
                position: Duration(milliseconds: 750),
                duration: Duration.zero,
              ),
            ],
        verify: (_) {
          verify(mockRecorder.pause()).called(1);
        },
      );

      blocTest<AudioCubit, AudioState>(
        'resumes recording from paused state',
        build: () => audioCubit,
        seed:
            () => const AudioState(
              phase: AudioPhase.recordingPaused,
              position: Duration(milliseconds: 750),
              duration: Duration.zero,
            ),
        act: (cubit) async {
          await cubit.resumeRecording();
          // Simulate elapsed time continuing
          recorderElapsedController.add(const Duration(milliseconds: 1000));
        },
        wait: const Duration(milliseconds: 120),
        expect:
            () => [
              const AudioState(
                phase: AudioPhase.recording,
                position: Duration(milliseconds: 750),
                duration: Duration.zero,
              ),
              const AudioState(
                phase: AudioPhase.recording,
                position: Duration(milliseconds: 1000),
                duration: Duration.zero,
              ),
            ],
        verify: (_) {
          verify(mockRecorder.resume()).called(1);
        },
      );

      blocTest<AudioCubit, AudioState>(
        'stops recording, loads player, and transitions to idle with file path',
        build: () => audioCubit,
        seed:
            () => const AudioState(
              phase: AudioPhase.recording,
              position: Duration(milliseconds: 1500),
              duration: Duration.zero,
            ),
        act: (cubit) async {
          await cubit.stopRecording();
        },
        expect:
            () => [
              const AudioState(
                phase: AudioPhase.idle,
                position: Duration.zero,
                duration: Duration.zero,
                filePath: testFilePath,
              ),
            ],
        verify: (_) {
          verify(mockRecorder.stop()).called(1);
          verify(mockPlayer.load(testFilePath)).called(1);
        },
      );
    });

    group('playback flow', () {
      blocTest<AudioCubit, AudioState>(
        'starts playback and updates position',
        build: () => audioCubit,
        seed:
            () => const AudioState(
              phase: AudioPhase.idle,
              position: Duration.zero,
              duration: Duration(seconds: 10),
              filePath: testFilePath,
            ),
        act: (cubit) async {
          await cubit.play();
          // Simulate playback position updates (200ms interval)
          playerPositionController.add(const Duration(seconds: 1));
          await Future.delayed(const Duration(milliseconds: 80));
          playerPositionController.add(const Duration(seconds: 2));
        },
        wait: const Duration(milliseconds: 120),
        expect:
            () => [
              const AudioState(
                phase: AudioPhase.playing,
                position: Duration.zero,
                duration: Duration(seconds: 10),
                filePath: testFilePath,
              ),
              const AudioState(
                phase: AudioPhase.playing,
                position: Duration(seconds: 1),
                duration: Duration(seconds: 10),
                filePath: testFilePath,
              ),
              const AudioState(
                phase: AudioPhase.playing,
                position: Duration(seconds: 2),
                duration: Duration(seconds: 10),
                filePath: testFilePath,
              ),
            ],
        verify: (_) {
          verify(mockPlayer.play()).called(1);
        },
      );

      blocTest<AudioCubit, AudioState>(
        'pauses playback and emits paused state',
        build: () => audioCubit,
        seed:
            () => const AudioState(
              phase: AudioPhase.playing,
              position: Duration(seconds: 3),
              duration: Duration(seconds: 10),
              filePath: testFilePath,
            ),
        act: (cubit) async {
          await cubit.pause();
        },
        wait: const Duration(milliseconds: 10),
        expect:
            () => [
              const AudioState(
                phase: AudioPhase.playingPaused,
                position: Duration(seconds: 3),
                duration: Duration(seconds: 10),
                filePath: testFilePath,
              ),
            ],
        verify: (_) {
          verify(mockPlayer.pause()).called(1);
        },
      );

      blocTest<AudioCubit, AudioState>(
        'seeks to position during playback',
        build: () => audioCubit,
        seed:
            () => const AudioState(
              phase: AudioPhase.playing,
              position: Duration(seconds: 3),
              duration: Duration(seconds: 10),
              filePath: testFilePath,
            ),
        act: (cubit) async {
          await cubit.seek(const Duration(seconds: 5));
          playerPositionController.add(const Duration(seconds: 5));
        },
        wait: const Duration(milliseconds: 90),
        expect:
            () => [
              const AudioState(
                phase: AudioPhase.playing,
                position: Duration(seconds: 5),
                duration: Duration(seconds: 10),
                filePath: testFilePath,
              ),
            ],
        verify: (_) {
          verify(mockPlayer.seek(const Duration(seconds: 5))).called(1);
        },
      );

      blocTest<AudioCubit, AudioState>(
        'handles duration change from player',
        build: () => audioCubit,
        seed:
            () => const AudioState(
              phase: AudioPhase.playing,
              position: Duration(seconds: 3),
              duration: Duration.zero,
              filePath: testFilePath,
            ),
        act: (cubit) async {
          playerDurationController.add(const Duration(seconds: 10));
        },
        wait: const Duration(milliseconds: 100),
        expect:
            () => [
              const AudioState(
                phase: AudioPhase.playing,
                position: Duration(seconds: 3),
                duration: Duration(seconds: 10),
                filePath: testFilePath,
              ),
            ],
      );

      blocTest<AudioCubit, AudioState>(
        'loads audio file and updates duration',
        build: () => audioCubit,
        seed: () => const AudioState.initial(),
        act: (cubit) async {
          await cubit.loadAudio(testFilePath);
          playerDurationController.add(const Duration(seconds: 10));
        },
        wait: const Duration(milliseconds: 100),
        expect:
            () => [
              const AudioState(
                phase: AudioPhase.idle,
                position: Duration.zero,
                duration: Duration.zero,
                filePath: testFilePath,
              ),
              const AudioState(
                phase: AudioPhase.idle,
                position: Duration.zero,
                duration: Duration(seconds: 10),
                filePath: testFilePath,
              ),
            ],
        verify: (_) {
          verify(mockPlayer.load(testFilePath)).called(1);
        },
      );
    });

    test('disposes resources properly', () async {
      // Setup subscriptions to verify they're properly closed
      await audioCubit.close();

      // Verify both services are disposed
      verify(mockRecorder.dispose()).called(1);
      verify(mockPlayer.dispose()).called(1);
    });
  });
}
