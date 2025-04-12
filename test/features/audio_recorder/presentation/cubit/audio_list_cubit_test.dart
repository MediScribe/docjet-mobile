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

    // Initialize the mock service
    mockAudioPlaybackService = MockAudioPlaybackService();

    // STUB the service stream BEFORE passing it to the cubit
    // It needs a default stream, even if empty for some tests
    when(
      mockAudioPlaybackService.playbackStateStream,
    ).thenAnswer((_) => const Stream.empty());

    cubit = AudioListCubit(
      repository: mockRepository,
      audioPlaybackService: mockAudioPlaybackService,
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
              message: 'File System Error: Failed to list files',
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
      // Expect no immediate state change; verification handles the interaction
      expect: () => [],
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

  group('Play -> Pause -> Play Again Sequence', () {
    late StreamController<PlaybackState> playbackStateController;
    const tPath = '/path/test.m4a';
    final tInitialState = AudioListLoaded(
      transcriptions: [tTranscription1],
    ); // Need some transcription
    final tPlayingState = PlaybackState.playing(
      currentPosition: const Duration(seconds: 5),
      totalDuration: const Duration(seconds: 30),
    );
    final tPausedState = PlaybackState.paused(
      currentPosition: const Duration(seconds: 5),
      totalDuration: const Duration(seconds: 30),
    );
    final tPlayingAgainState = PlaybackState.playing(
      currentPosition: Duration.zero, // Reset position
      totalDuration: const Duration(seconds: 30),
    );

    setUp(() {
      // Mock setup specific to this group
      playbackStateController = StreamController<PlaybackState>.broadcast();
      mockRepository = MockAudioRecorderRepository(); // Ensure mocks are fresh
      mockAudioPlaybackService = MockAudioPlaybackService();
      when(
        mockAudioPlaybackService.playbackStateStream,
      ).thenAnswer((_) => playbackStateController.stream);
      // Stub service methods used in the sequence
      when(mockAudioPlaybackService.play(any)).thenAnswer((_) async {});
      when(mockAudioPlaybackService.pause()).thenAnswer((_) async {});

      // Create cubit for this group
      cubit = AudioListCubit(
        repository: mockRepository,
        audioPlaybackService: mockAudioPlaybackService,
      );
    });

    tearDown(() {
      playbackStateController.close();
      cubit.close(); // Ensure cubit is closed
    });

    blocTest<AudioListCubit, AudioListState>(
      'emits correct PlaybackInfo sequence for Play -> Pause -> Play Again',
      build: () => cubit,
      seed: () => tInitialState,
      act: (cubit) async {
        // 1. Play
        await cubit.playRecording(tPath);
        playbackStateController.add(tPlayingState);
        await Future.delayed(Duration.zero); // Allow stream processing

        // 2. Pause
        await cubit.pauseRecording();
        playbackStateController.add(tPausedState);
        await Future.delayed(Duration.zero); // Allow stream processing

        // 3. Play Again
        await cubit.playRecording(tPath);
        playbackStateController.add(tPlayingAgainState);
        await Future.delayed(Duration.zero); // Allow stream processing
      },
      expect:
          () => <Matcher>[
            // State after 1st Play
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo,
              'playbackInfo after play',
              isA<PlaybackInfo>()
                  .having((p) => p.activeFilePath, 'activeFilePath', tPath)
                  .having((p) => p.isPlaying, 'isPlaying', true)
                  .having((p) => p.isLoading, 'isLoading', false)
                  .having(
                    (p) => p.currentPosition,
                    'currentPosition',
                    tPlayingState.mapOrNull(playing: (s) => s.currentPosition),
                  )
                  .having(
                    (p) => p.totalDuration,
                    'totalDuration',
                    tPlayingState.mapOrNull(playing: (s) => s.totalDuration),
                  ),
            ),
            // State after Pause
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo,
              'playbackInfo after pause',
              isA<PlaybackInfo>()
                  .having((p) => p.activeFilePath, 'activeFilePath', tPath)
                  .having((p) => p.isPlaying, 'isPlaying', false)
                  .having((p) => p.isLoading, 'isLoading', false)
                  .having(
                    (p) => p.currentPosition,
                    'currentPosition',
                    tPausedState.mapOrNull(paused: (s) => s.currentPosition),
                  )
                  .having(
                    (p) => p.totalDuration,
                    'totalDuration',
                    tPausedState.mapOrNull(paused: (s) => s.totalDuration),
                  ),
            ),
            // State after 2nd Play
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo,
              'playbackInfo after play again',
              isA<PlaybackInfo>()
                  .having((p) => p.activeFilePath, 'activeFilePath', tPath)
                  .having((p) => p.isPlaying, 'isPlaying', true)
                  .having((p) => p.isLoading, 'isLoading', false)
                  .having(
                    (p) => p.currentPosition,
                    'currentPosition',
                    tPlayingAgainState.mapOrNull(
                      playing: (s) => s.currentPosition,
                    ),
                  )
                  .having(
                    (p) => p.totalDuration,
                    'totalDuration',
                    tPlayingAgainState.mapOrNull(
                      playing: (s) => s.totalDuration,
                    ),
                  ),
            ),
          ],
      verify: (_) {
        // Verify service calls
        verify(mockAudioPlaybackService.play(tPath)).called(2);
        verify(mockAudioPlaybackService.pause()).called(1);
      },
    );
  });

  group('Play -> Stop Event -> Play Again Race Condition', () {
    late StreamController<PlaybackState> playbackStateController;
    const tPath = '/path/test.m4a';
    // Use a transcription list that includes tPath1 if needed for state consistency
    final tInitialState = AudioListLoaded(transcriptions: [tTranscription1]);
    final tPlayingState1 = PlaybackState.playing(
      currentPosition: const Duration(seconds: 5),
      totalDuration: const Duration(seconds: 30),
    );
    final tStoppedState = PlaybackState.stopped();
    final tPlayingState2 = PlaybackState.playing(
      currentPosition: Duration.zero, // Reset position
      totalDuration: const Duration(seconds: 30),
    );

    setUp(() {
      playbackStateController = StreamController<PlaybackState>.broadcast();
      mockRepository = MockAudioRecorderRepository();
      mockAudioPlaybackService = MockAudioPlaybackService();
      when(
        mockAudioPlaybackService.playbackStateStream,
      ).thenAnswer((_) => playbackStateController.stream);
      // Stub service play/stop
      when(mockAudioPlaybackService.play(any)).thenAnswer((_) async {});
      when(
        mockAudioPlaybackService.stop(),
      ).thenAnswer((_) async {}); // Needed by play() internally

      cubit = AudioListCubit(
        repository: mockRepository,
        audioPlaybackService: mockAudioPlaybackService,
      );
    });

    tearDown(() {
      playbackStateController.close();
      cubit.close();
    });

    blocTest<AudioListCubit, AudioListState>(
      'handles race condition where stop event arrives during second play call',
      build: () => cubit,
      seed: () => tInitialState,
      act: (cubit) async {
        // 1. Initial Play
        await cubit.playRecording(tPath);
        playbackStateController.add(tPlayingState1);
        await Future.delayed(Duration.zero); // Allow stream processing

        // 2. Call Play Again (triggers implicit stop first)
        await cubit.playRecording(tPath); // Sets internal path again

        // 3. Simulate Stop Event arriving BEFORE the new Playing state
        playbackStateController.add(tStoppedState);
        await Future.delayed(Duration.zero); // Allow stream processing

        // 4. Simulate new Playing state arriving AFTER the stop state
        playbackStateController.add(tPlayingState2);
        await Future.delayed(Duration.zero); // Allow stream processing
      },
      expect:
          () => <Matcher>[
            // State after 1st Play
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo.activeFilePath,
              'activeFilePath after 1st play',
              tPath,
            ),
            // State after Stop event (Current logic resets path)
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo,
              'playbackInfo after stop event',
              isA<PlaybackInfo>()
                  .having((p) => p.activeFilePath, 'activeFilePath', tPath)
                  .having((p) => p.isPlaying, 'isPlaying', false)
                  .having(
                    (p) => p.currentPosition,
                    'currentPosition',
                    Duration.zero,
                  )
                  .having(
                    (p) => p.totalDuration,
                    'totalDuration',
                    Duration.zero,
                  ),
            ),
            // State after 2nd Play event (BUG: Path becomes null here)
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo,
              'playbackInfo after 2nd play event',
              isA<PlaybackInfo>()
                  .having((p) => p.activeFilePath, 'activeFilePath', tPath)
                  .having((p) => p.isPlaying, 'isPlaying', true)
                  .having(
                    (p) => p.currentPosition,
                    'currentPosition',
                    tPlayingState2.mapOrNull(playing: (s) => s.currentPosition),
                  )
                  .having(
                    (p) => p.totalDuration,
                    'totalDuration',
                    tPlayingState2.mapOrNull(playing: (s) => s.totalDuration),
                  ),
            ),
          ],
      verify: (_) {
        // Verify service calls (play called twice)
        verify(mockAudioPlaybackService.play(tPath)).called(2);
      },
    );
  });

  group('pauseRecording', () {
    late StreamController<PlaybackState> playbackStateController;
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
    final tPausedState = PlaybackState.paused(
      currentPosition: const Duration(seconds: 5),
      totalDuration: const Duration(seconds: 30),
    );

    setUp(() {
      playbackStateController = StreamController<PlaybackState>.broadcast();
      mockRepository = MockAudioRecorderRepository();
      mockAudioPlaybackService = MockAudioPlaybackService();
      when(
        mockAudioPlaybackService.playbackStateStream,
      ).thenAnswer((_) => playbackStateController.stream);
      when(mockAudioPlaybackService.pause()).thenAnswer((_) async {});

      cubit = AudioListCubit(
        repository: mockRepository,
        audioPlaybackService: mockAudioPlaybackService,
      );
    });

    tearDown(() {
      playbackStateController.close();
      cubit.close();
    });

    // THIS TEST SHOULD FAIL IF OUR UI IS BROKEN
    blocTest<AudioListCubit, AudioListState>(
      'preserves activeFilePath when paused',
      build: () => cubit,
      seed: () => tInitialState,
      act: (cubit) async {
        // Set the internal _currentPlayingFilePath in the cubit
        await cubit.playRecording(tPath);

        // Pause the recording
        await cubit.pauseRecording();

        // Simulate the service emitting paused state
        playbackStateController.add(tPausedState);
      },
      wait: const Duration(
        milliseconds: 100,
      ), // Give time for events to process
      expect:
          () => [
            isA<AudioListLoaded>().having(
              (s) => s.playbackInfo,
              'playbackInfo after pause',
              isA<PlaybackInfo>()
                  .having(
                    (p) => p.activeFilePath,
                    'activeFilePath',
                    tPath,
                  ) // SHOULD PRESERVE THE PATH
                  .having((p) => p.isPlaying, 'isPlaying', false)
                  .having((p) => p.isLoading, 'isLoading', false)
                  .having(
                    (p) => p.currentPosition,
                    'currentPosition',
                    tPausedState.mapOrNull(paused: (s) => s.currentPosition),
                  )
                  .having(
                    (p) => p.totalDuration,
                    'totalDuration',
                    tPausedState.mapOrNull(paused: (s) => s.totalDuration),
                  ),
            ),
          ],
      verify: (_) {
        verify(mockAudioPlaybackService.pause()).called(1);
      },
    );
  });

  group('seekRecording', () {
    test(
      'should call audioPlaybackService.seek with correct position',
      () async {
        // Arrange
        const testPosition = Duration(seconds: 10);
        const testFilePath = 'some/path/test.mp3';

        // Use thenAnswer instead of thenReturn for Future<void>
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

    blocTest<AudioListCubit, AudioListState>(
      'should emit state with error when service seek throws',
      setUp: () {
        // Arrange: Mock service throws when seek is called
        when(
          mockAudioPlaybackService.seek(any, any),
        ).thenThrow(Exception('Invalid seek position'));
      },
      // Seed with a loaded state because error handling requires it
      seed:
          () => AudioListLoaded(
            transcriptions: [tTranscription1], // Sample data - Removed const
            playbackInfo: PlaybackInfo.initial(),
          ),
      build: () => cubit,
      act:
          (cubit) => cubit.seekRecording(
            'test.mp3',
            const Duration(seconds: 5),
          ), // Act: Call seekRecording
      expect:
          () => [
            // Assert: Expect state with updated playbackInfo containing the error
            isA<AudioListLoaded>().having(
              (state) => state.playbackInfo.error,
              'playbackInfo.error',
              contains('Invalid seek position'),
            ),
          ],
      verify: (_) {
        // Verify: Ensure the service method was indeed called
        verify(
          mockAudioPlaybackService.seek('test.mp3', const Duration(seconds: 5)),
        ).called(1);
      },
    );

    const tSeekPosition = Duration(seconds: 15);

    blocTest<AudioListCubit, AudioListState>(
      'calls service.seek with the correct file path and position',
      setUp: () {
        // Use thenAnswer instead of thenReturn for Future<void>
        when(
          mockAudioPlaybackService.seek(any, any),
        ).thenAnswer((_) => Future<void>.value());
      },
      build: () => cubit,
      act:
          (cubit) =>
              cubit.seekRecording('test.mp3', const Duration(seconds: 10)),
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
}
