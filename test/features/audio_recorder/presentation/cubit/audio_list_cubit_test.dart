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
import 'dart:async'; // For StreamController
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart'; // For PlaybackState
import 'package:docjet_mobile/core/utils/log_helpers.dart';

import 'audio_list_cubit_test.mocks.dart';

// Logger for test file
final logger = LoggerFactory.getLogger(
  'AudioListCubitTest',
  level: Level.debug,
);

@GenerateMocks([AudioRecorderRepository, AudioPlaybackService])
void main() {
  // Enable debug logs for the SUT component
  LoggerFactory.setLogLevel(AudioListCubit, Level.debug);

  late MockAudioRecorderRepository mockRepository;
  late MockAudioPlaybackService mockAudioPlaybackService;
  late AudioListCubit cubit;
  // Define StreamController at a higher scope to be accessible by multiple groups
  late StreamController<PlaybackState> playbackStateController;

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

  // Use setUpAll for things that don't change between tests within main()
  setUpAll(() {
    // Setup that doesn't need resetting per test
  });

  // Use setUp for things that need to be reset for each test or group
  setUp(() {
    mockRepository = MockAudioRecorderRepository();
    mockAudioPlaybackService = MockAudioPlaybackService();
    playbackStateController = StreamController<PlaybackState>.broadcast();

    // Default stub for the stream
    when(
      mockAudioPlaybackService.playbackStateStream,
    ).thenAnswer((_) => playbackStateController.stream);

    // Default stubs for service methods to avoid MissingStubError
    when(mockAudioPlaybackService.play(any)).thenAnswer((_) async {});
    when(mockAudioPlaybackService.pause()).thenAnswer((_) async {});
    when(mockAudioPlaybackService.resume()).thenAnswer((_) async {});
    when(mockAudioPlaybackService.stop()).thenAnswer((_) async {});
    when(mockAudioPlaybackService.seek(any, any)).thenAnswer((_) async {});

    cubit = AudioListCubit(
      repository: mockRepository,
      audioPlaybackService: mockAudioPlaybackService,
    );
  });

  tearDown(() {
    cubit.close();
    playbackStateController.close();
  });

  test('initial state should be AudioListInitial', () {
    expect(cubit.state, AudioListInitial());
  });

  group('loadAudioRecordings', () {
    blocTest<AudioListCubit, AudioListState>(
      'emits [AudioListLoading, AudioListLoaded] when loadTranscriptions is successful',
      setUp: () {
        // Specific setup if needed, overrides the main setUp
        when(mockRepository.loadTranscriptions()) // Mock loadTranscriptions
        .thenAnswer((_) async => Right(tTranscriptionList));
      },
      build: () => cubit,
      act: (cubit) => cubit.loadAudioRecordings(),
      expect:
          () => [
            AudioListLoading(),
            AudioListLoaded(
              transcriptions: tTranscriptionList,
            ), // Expect Transcription list
          ],
      verify: (_) {
        verify(mockRepository.loadTranscriptions());
      },
    );

    blocTest<AudioListCubit, AudioListState>(
      'emits [AudioListLoading, AudioListLoaded with empty list] when loadTranscriptions returns empty list',
      setUp: () {
        when(
          mockRepository.loadTranscriptions(),
        ).thenAnswer((_) async => const Right([]));
      },
      build: () => cubit,
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
      },
    );

    blocTest<AudioListCubit, AudioListState>(
      'emits [AudioListLoading, AudioListError] when loadTranscriptions fails',
      setUp: () {
        when(mockRepository.loadTranscriptions()).thenAnswer(
          (_) async => const Left(FileSystemFailure('Failed to list files')),
        );
      },
      build: () => cubit,
      act: (cubit) => cubit.loadAudioRecordings(),
      expect:
          () => [
            AudioListLoading(),
            const AudioListError(
              message: 'File System Error: Failed to list files',
            ),
          ],
      verify: (_) {
        verify(mockRepository.loadTranscriptions());
      },
    );

    // TODO: Add test for deleteRecording and its effect on the list
  });

  group('playRecording', () {
    blocTest<AudioListCubit, AudioListState>(
      'calls service.play',
      // No need for setUp, handled globally
      build: () => cubit,
      seed: () => AudioListLoaded(transcriptions: tTranscriptionList),
      act: (cubit) => cubit.playRecording(tPath1),
      expect: () => [], // Expect no direct state change from call
      verify: (_) {
        verify(mockAudioPlaybackService.play(tPath1)).called(1);
      },
    );
  });

  // Updated stopRecording test
  group('stopRecording', () {
    blocTest<AudioListCubit, AudioListState>(
      'calls service.stop and emits updated state when stopped event is received',
      // No specific setUp needed, default is fine
      build: () => cubit,
      seed:
          () => AudioListLoaded(
            transcriptions: tTranscriptionList,
            playbackInfo: const PlaybackInfo(
              activeFilePath: tPath1, // Start with a playing file
              isPlaying: true,
              isLoading: false,
              currentPosition: Duration(seconds: 5),
              totalDuration: Duration(seconds: 10),
            ),
          ),
      act: (cubit) async {
        // Call stop recording first
        await cubit.stopRecording();
        // THEN simulate the service stream emitting stopped
        playbackStateController.add(const PlaybackState.stopped());
      },
      expect:
          () => [
            // Expect the state to update reflecting the stopped status
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo,
              'playbackInfo',
              const PlaybackInfo.initial(), // Should reset to initial state
            ),
          ],
      verify: (_) {
        // Still verify the service method was called
        verify(mockAudioPlaybackService.stop()).called(1);
      },
    );
  });

  // This group uses the controller defined in the main scope
  group('Playback State Updates', () {
    // No need for setUp/tearDown here, handled globally

    blocTest<AudioListCubit, AudioListState>(
      'emits state with activeFilePath and isPlaying=true when PlaybackState.playing received',
      build: () => cubit,
      seed: () => AudioListLoaded(transcriptions: tTranscriptionList),
      act: (cubit) async {
        await cubit.playRecording(tPath1);
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
        playbackStateController.add(const PlaybackState.stopped());
      },
      expect:
          () => [
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo,
              'playbackInfo',
              const PlaybackInfo.initial(),
            ),
          ],
    );

    blocTest<AudioListCubit, AudioListState>(
      'emits state with null activeFilePath and isPlaying=false when PlaybackState.completed received',
      build: () => cubit,
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
        playbackStateController.add(const PlaybackState.completed());
      },
      expect:
          () => [
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo,
              'playbackInfo',
              const PlaybackInfo.initial(),
            ),
          ],
    );
  });

  // Group for seekRecording tests
  group('seekRecording', () {
    // Test: should call audioPlaybackService.seek with correct position
    test(
      'should call audioPlaybackService.seek with correct position',
      () async {
        // Arrange
        const testPosition = Duration(seconds: 10);
        const testFilePath = 'some/path/test.mp3';
        when(
          mockAudioPlaybackService.seek(testFilePath, testPosition),
        ).thenAnswer((_) => Future<void>.value());

        // Act
        await cubit.seekRecording(testFilePath, testPosition);

        // Assert
        verify(
          mockAudioPlaybackService.seek(testFilePath, testPosition),
        ).called(1);
      },
    );

    // Test: should emit state with error when service seek throws
    blocTest<AudioListCubit, AudioListState>(
      'should emit state with error when service seek throws',
      setUp: () {
        when(
          mockAudioPlaybackService.seek(any, any),
        ).thenThrow(Exception('Invalid seek position'));
      },
      seed: () => AudioListLoaded(transcriptions: [tTranscription1]),
      build: () => cubit,
      act:
          (cubit) =>
              cubit.seekRecording('test.mp3', const Duration(seconds: 5)),
      expect:
          () => [
            isA<AudioListLoaded>().having(
              (state) => state.playbackInfo.error,
              'playbackInfo.error',
              contains('Invalid seek position'),
            ),
          ],
      verify: (_) {
        verify(
          mockAudioPlaybackService.seek('test.mp3', const Duration(seconds: 5)),
        ).called(1);
      },
    );

    // Test: calls service.seek with the correct file path and position
    blocTest<AudioListCubit, AudioListState>(
      'calls service.seek with the correct file path and position',
      // No specific setUp needed, default is fine
      build: () => cubit,
      act:
          (cubit) =>
              cubit.seekRecording('test.mp3', const Duration(seconds: 10)),
      expect: () => [], // Expect no direct state change from call
      verify: (_) {
        verify(
          mockAudioPlaybackService.seek(
            'test.mp3',
            const Duration(seconds: 10),
          ),
        ).called(1);
      },
    );
  });

  // Other groups like Play -> Pause -> Play Again Sequence should also be reviewed
  // to ensure they use the globally scoped controller or have appropriate local setup.
  // Ensure remaining groups use the global controller or adjust as needed.
  // For example, Play -> Pause -> Play Again Sequence:
  group('Play -> Pause -> Play Again Sequence', () {
    // No need for local controller or setUp/tearDown if using global one
    const tPath = '/path/test.m4a';
    final tInitialState = AudioListLoaded(transcriptions: [tTranscription1]);
    const tPlayingState = PlaybackState.playing(
      currentPosition: Duration(seconds: 5),
      totalDuration: Duration(seconds: 30),
    );
    const tPausedState = PlaybackState.paused(
      currentPosition: Duration(seconds: 5),
      totalDuration: Duration(seconds: 30),
    );
    const tPlayingAgainState = PlaybackState.playing(
      currentPosition: Duration.zero,
      totalDuration: Duration(seconds: 30),
    );

    blocTest<AudioListCubit, AudioListState>(
      'emits correct PlaybackInfo sequence for Play -> Pause -> Play Again',
      build: () => cubit,
      seed: () => tInitialState,
      act: (cubit) async {
        await cubit.playRecording(tPath);
        playbackStateController.add(tPlayingState);
        await Future.delayed(Duration.zero);

        await cubit.pauseRecording();
        playbackStateController.add(tPausedState);
        await Future.delayed(Duration.zero);

        await cubit.playRecording(tPath);
        playbackStateController.add(tPlayingAgainState);
        await Future.delayed(Duration.zero);
      },
      expect:
          () => <Matcher>[
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo.activeFilePath,
              'activeFilePath after play',
              tPath,
            ),
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo.activeFilePath,
              'activeFilePath after pause',
              tPath,
            ),
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo.activeFilePath,
              'activeFilePath after play again',
              tPath,
            ),
          ],
      verify: (_) {
        verify(mockAudioPlaybackService.play(tPath)).called(2);
        verify(mockAudioPlaybackService.pause()).called(1);
      },
    );
  });

  group('Play -> Stop Event -> Play Again Race Condition', () {
    // No need for local controller or setUp/tearDown if using global one
    const tPath = '/path/test.m4a';
    final tInitialState = AudioListLoaded(transcriptions: [tTranscription1]);
    const tPlayingState1 = PlaybackState.playing(
      currentPosition: Duration(seconds: 5),
      totalDuration: Duration(seconds: 30),
    );
    const tStoppedState = PlaybackState.stopped();
    const tPlayingState2 = PlaybackState.playing(
      currentPosition: Duration.zero,
      totalDuration: Duration(seconds: 30),
    );

    blocTest<AudioListCubit, AudioListState>(
      'handles race condition where stop event arrives during second play call',
      build: () => cubit,
      seed: () => tInitialState,
      act: (cubit) async {
        await cubit.playRecording(tPath);
        playbackStateController.add(tPlayingState1);
        await Future.delayed(Duration.zero);

        await cubit.playRecording(tPath);

        playbackStateController.add(tStoppedState);
        await Future.delayed(Duration.zero);

        playbackStateController.add(tPlayingState2);
        await Future.delayed(Duration.zero);
      },
      expect:
          () => <Matcher>[
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo.activeFilePath,
              'activeFilePath after 1st play',
              tPath,
            ),
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo.activeFilePath,
              'activeFilePath after stop event',
              isNull,
            ),
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo.activeFilePath,
              'activeFilePath after 2nd play event',
              tPath,
            ),
          ],
      verify: (_) {
        verify(mockAudioPlaybackService.play(tPath)).called(2);
      },
    );
  });

  group('pauseRecording preserves activeFilePath', () {
    // Use global controller, no need for local setup
    const tPath = '/path/test.m4a';
    final tInitialState = AudioListLoaded(
      transcriptions: [tTranscription1],
      playbackInfo: const PlaybackInfo(
        activeFilePath: tPath,
        isPlaying: true,
        isLoading: false,
        currentPosition: Duration(seconds: 5),
        totalDuration: Duration(seconds: 30),
      ),
    );
    const tPausedState = PlaybackState.paused(
      currentPosition: Duration(seconds: 5),
      totalDuration: Duration(seconds: 30),
    );

    blocTest<AudioListCubit, AudioListState>(
      'preserves activeFilePath when paused',
      build: () => cubit,
      seed: () => tInitialState,
      act: (cubit) async {
        // Pause the recording
        await cubit.pauseRecording();
        // Simulate the service emitting paused state
        playbackStateController.add(tPausedState);
      },
      wait: const Duration(milliseconds: 100),
      expect:
          () => [
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo.activeFilePath,
              'activeFilePath after pause',
              tPath, // Should preserve the path
            ),
          ],
      verify: (_) {
        verify(mockAudioPlaybackService.pause()).called(1);
      },
    );
  });
}
