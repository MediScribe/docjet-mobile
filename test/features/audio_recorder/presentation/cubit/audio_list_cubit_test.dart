import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart'; // Use Transcription
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart'; // Import status
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart'; // Import service
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'dart:async'; // <<< ADD for StreamController
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart'; // <<< ADD for PlaybackState

import 'audio_list_cubit_test.mocks.dart';

@GenerateMocks([AudioRecorderRepository, AudioPlaybackService])
void main() {
  late MockAudioRecorderRepository mockRepository;
  late MockAudioPlaybackService
  mockAudioPlaybackService; // Declare mock service
  late AudioListCubit cubit;

  // Sample Transcription data for testing
  final tNow = DateTime.now();
  const tPath1 = '/path/rec1.m4a';
  const tPath2 = '/path/rec2.m4a';

  final tTranscription1 = Transcription(
    id: 'uuid-1',
    localFilePath: tPath1,
    status: TranscriptionStatus.completed,
    localCreatedAt: tNow.subtract(const Duration(minutes: 10)),
    backendUpdatedAt: tNow.subtract(const Duration(minutes: 5)),
    localDurationMillis: 10000,
    displayTitle: 'Meeting Notes',
    displayText: 'Discussed project milestones...',
  );

  final tTranscription2 = Transcription(
    id: 'uuid-2',
    localFilePath: tPath2,
    status: TranscriptionStatus.processing,
    localCreatedAt: tNow,
    backendUpdatedAt: tNow,
    localDurationMillis: 20000,
  );

  final tTranscriptionList = [
    tTranscription2,
    tTranscription1,
  ]; // Sorted newest first

  setUp(() {
    mockRepository = MockAudioRecorderRepository();
    mockAudioPlaybackService =
        MockAudioPlaybackService(); // Instantiate mock service

    // STUB the service stream BEFORE passing it to the cubit
    // It needs a default stream, even if empty for some tests
    when(
      mockAudioPlaybackService.playbackStateStream,
    ).thenAnswer((_) => const Stream.empty());

    cubit = AudioListCubit(
      repository: mockRepository,
      audioPlaybackService: mockAudioPlaybackService, // Provide mock service
    );
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state should be AudioListInitial', () {
    expect(cubit.state, AudioListInitial());
  });

  group('loadAudioRecordings', () {
    blocTest<AudioListCubit, AudioListState>(
      'emits [AudioListLoading, AudioListLoaded] when loadTranscriptions is successful',
      build: () {
        when(mockRepository.loadTranscriptions()) // Mock loadTranscriptions
        .thenAnswer((_) async => Right(tTranscriptionList));
        return cubit;
      },
      act: (cubit) => cubit.loadAudioRecordings(),
      expect:
          () => [
            AudioListLoading(),
            AudioListLoaded(
              transcriptions: tTranscriptionList,
            ), // Expect Transcription list
          ],
      verify: (_) {
        verify(
          mockRepository.loadTranscriptions(),
        ); // Verify loadTranscriptions called
        verifyNoMoreInteractions(mockRepository);
      },
    );

    blocTest<AudioListCubit, AudioListState>(
      'emits [AudioListLoading, AudioListLoaded with empty list] when loadTranscriptions returns empty list',
      build: () {
        when(
          mockRepository.loadTranscriptions(),
        ).thenAnswer((_) async => const Right([]));
        return cubit;
      },
      act: (cubit) => cubit.loadAudioRecordings(),
      expect:
          () => [
            AudioListLoading(),
            const AudioListLoaded(
              transcriptions: [],
            ), // Expect empty Transcription list
          ],
      verify: (_) {
        verify(mockRepository.loadTranscriptions());
        verifyNoMoreInteractions(mockRepository);
      },
    );

    blocTest<AudioListCubit, AudioListState>(
      'emits [AudioListLoading, AudioListError] when loadTranscriptions fails',
      build: () {
        when(mockRepository.loadTranscriptions()).thenAnswer(
          (_) async => const Left(FileSystemFailure('Failed to list files')),
        );
        return cubit;
      },
      act: (cubit) => cubit.loadAudioRecordings(),
      expect:
          () => [
            AudioListLoading(),
            const AudioListError(
              message: 'FileSystemFailure(Failed to list files)',
            ),
          ],
      verify: (_) {
        verify(mockRepository.loadTranscriptions());
        verifyNoMoreInteractions(mockRepository);
      },
    );

    // TODO: Add test for deleteRecording and its effect on the list
  });

  group('playRecording', () {
    blocTest<AudioListCubit, AudioListState>(
      'calls service.play',
      setUp: () {
        // Ensure the service call doesn't throw
        when(mockAudioPlaybackService.play(any)).thenAnswer((_) async {});
      },
      build: () => cubit,
      seed: () => AudioListLoaded(transcriptions: tTranscriptionList),
      act: (cubit) => cubit.playRecording(tPath1),
      // Don't expect state change just from the call, only verify interaction
      expect: () => [],
      verify: (_) {
        verify(mockAudioPlaybackService.play(tPath1)).called(1);
      },
    );
  });

  group('stopRecording', () {
    blocTest<AudioListCubit, AudioListState>(
      'calls service.stop and emits state with null activeFilePath and isPlaying false',
      setUp: () {
        when(mockAudioPlaybackService.stop()).thenAnswer((_) async {});
      },
      build: () => cubit,
      seed:
          () => AudioListLoaded(
            transcriptions: tTranscriptionList,
            playbackInfo: PlaybackInfo(
              activeFilePath: tPath1, // Start with a playing file
              isPlaying: true,
              isLoading: false,
              currentPosition: const Duration(seconds: 5),
              totalDuration: const Duration(seconds: 10),
            ),
          ),
      act: (cubit) => cubit.stopRecording(),
      expect:
          () => [
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo,
              'playbackInfo',
              // Expect the state to reset, matching initial playback info
              const PlaybackInfo.initial(),
            ),
          ],
      verify: (_) {
        verify(mockAudioPlaybackService.stop()).called(1);
      },
    );
  });

  group('Playback State Updates', () {
    // Setup a stream controller to simulate the service's stream
    late StreamController<PlaybackState> playbackStateController;

    setUp(() {
      playbackStateController = StreamController<PlaybackState>.broadcast();
      // Tell the mock service to use our controller's stream
      when(
        mockAudioPlaybackService.playbackStateStream,
      ).thenAnswer((_) => playbackStateController.stream);

      // Re-initialize cubit with the mock service that now uses the controller
      // This is needed because the subscription happens in the constructor
      // Ensure other mocks are passed if needed, or re-read from context
      cubit = AudioListCubit(
        repository: mockRepository, // Make sure mockRepository is available
        audioPlaybackService: mockAudioPlaybackService,
      );
    });

    tearDown(() {
      playbackStateController.close();
    });

    blocTest<AudioListCubit, AudioListState>(
      'emits state with activeFilePath and isPlaying=true when PlaybackState.playing received',
      build: () => cubit,
      seed: () => AudioListLoaded(transcriptions: tTranscriptionList),
      act: (cubit) async {
        // Need to call playRecording first to set the internal file path
        when(mockAudioPlaybackService.play(tPath1)).thenAnswer((_) async {});
        await cubit.playRecording(tPath1);

        // Simulate the service emitting playing state
        playbackStateController.add(
          const PlaybackState.playing(
            currentPosition: Duration.zero,
            totalDuration: Duration(seconds: 10),
          ),
        );
      },
      expect:
          () => [
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo,
              'playbackInfo',
              const PlaybackInfo(
                activeFilePath: tPath1,
                isPlaying: true,
                isLoading: false,
                currentPosition: Duration.zero,
                totalDuration: Duration(seconds: 10),
              ),
            ),
          ],
    );

    blocTest<AudioListCubit, AudioListState>(
      'emits state with null activeFilePath and isPlaying=false when PlaybackState.stopped received',
      build: () => cubit,
      // Seed with a playing state first
      seed:
          () => AudioListLoaded(
            transcriptions: tTranscriptionList,
            playbackInfo: const PlaybackInfo(
              activeFilePath: tPath1,
              isPlaying: true,
              isLoading: false,
              currentPosition: Duration(seconds: 5),
              totalDuration: Duration(seconds: 10),
            ),
          ),
      act: (cubit) async {
        // Simulate the service emitting stopped state
        playbackStateController.add(const PlaybackState.stopped());
      },
      expect:
          () => [
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo,
              'playbackInfo',
              // Expect state reset (initial has null path, false playing)
              const PlaybackInfo.initial().copyWith(
                // Keep duration if needed? Check requirements. Let's assume reset.
                // totalDuration: Duration(seconds: 10),
              ),
            ),
          ],
    );

    blocTest<AudioListCubit, AudioListState>(
      'emits state with null activeFilePath and isPlaying=false when PlaybackState.completed received',
      build: () => cubit,
      // Seed with a playing state first
      seed:
          () => AudioListLoaded(
            transcriptions: tTranscriptionList,
            playbackInfo: const PlaybackInfo(
              activeFilePath: tPath1,
              isPlaying: true,
              isLoading: false,
              currentPosition: Duration(seconds: 9),
              totalDuration: Duration(seconds: 10),
            ),
          ),
      act: (cubit) async {
        // Simulate the service emitting completed state
        playbackStateController.add(const PlaybackState.completed());
      },
      expect:
          () => [
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo,
              'playbackInfo',
              // Expect state reset (initial has null path, false playing)
              const PlaybackInfo.initial().copyWith(
                // Keep duration? Let's assume reset for simplicity.
                // totalDuration: Duration(seconds: 10),
              ),
            ),
          ],
    );
  });
}
