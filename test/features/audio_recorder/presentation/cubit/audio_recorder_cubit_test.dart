import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recorder_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recorder_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mock for the repository
@GenerateMocks([AudioRecorderRepository])
import 'audio_recorder_cubit_test.mocks.dart'; // Import generated mocks

void main() {
  // Declare late variables for the cubit and mock repository
  late AudioRecorderCubit cubit;
  late MockAudioRecorderRepository mockRepository; // Renamed

  setUp(() {
    // Initialize mock repository
    mockRepository = MockAudioRecorderRepository();

    // Initialize the cubit with mock repository
    cubit = AudioRecorderCubit(repository: mockRepository);
  });

  // Test groups will go here
  group('AudioRecorderCubit Tests', () {
    test('initial state is AudioRecorderInitial', () {
      expect(cubit.state, AudioRecorderInitial());
    });

    group('deleteRecording', () {
      const tFilePath = 'test/path/recording.m4a';
      final List<AudioRecord> tPostDeleteRecordings = [];

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Loaded] and calls repository methods when delete succeeds',
        build: () {
          when(
            mockRepository.deleteRecording(tFilePath),
          ).thenAnswer((_) async => const Right(null));
          when(
            mockRepository.loadRecordings(),
          ).thenAnswer((_) async => Right(tPostDeleteRecordings));
          return cubit;
        },
        act: (cubit) async {
          await cubit.deleteRecording(tFilePath);
        },
        expect: () => [AudioRecorderLoaded(tPostDeleteRecordings)],
        verify: (_) {
          verify(mockRepository.deleteRecording(tFilePath)).called(1);
          verify(mockRepository.loadRecordings()).called(1);
        },
      );

      final tFailure = PermissionFailure('Deletion failed');

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Error] and calls delete repository method when delete fails',
        build: () {
          when(
            mockRepository.deleteRecording(tFilePath),
          ).thenAnswer((_) async => Left(tFailure));
          return cubit;
        },
        act: (cubit) => cubit.deleteRecording(tFilePath),
        expect:
            () => [
              AudioRecorderError(
                'Failed to delete recording: ${tFailure.toString()}',
              ),
            ],
        verify: (_) {
          verify(mockRepository.deleteRecording(tFilePath)).called(1);
          verifyNever(mockRepository.loadRecordings());
        },
      );
    });

    group('loadRecordings', () {
      final tRecordings = [
        AudioRecord(
          filePath: 'path1.m4a',
          duration: const Duration(seconds: 10),
          createdAt: DateTime.now(),
        ),
        AudioRecord(
          filePath: 'path2.m4a',
          duration: const Duration(seconds: 20),
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loaded] when loadRecordings succeeds',
        build: () {
          when(
            mockRepository.loadRecordings(),
          ).thenAnswer((_) async => Right(tRecordings));
          return cubit;
        },
        act: (cubit) => cubit.loadRecordings(),
        expect: () => [AudioRecorderLoaded(tRecordings)],
        verify: (_) {
          verify(mockRepository.loadRecordings()).called(1);
        },
      );

      final tLoadFailure = FileSystemFailure('Failed to load files');

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Error] when loadRecordings fails',
        build: () {
          when(
            mockRepository.loadRecordings(),
          ).thenAnswer((_) async => Left(tLoadFailure));
          return cubit;
        },
        act: (cubit) => cubit.loadRecordings(),
        expect:
            () => [
              AudioRecorderError(
                'Failed to load recordings: ${tLoadFailure.toString()}',
              ),
            ],
        verify: (_) {
          verify(mockRepository.loadRecordings()).called(1);
        },
      );
    });

    group('startRecording', () {
      const tFilePath = 'new/recording/path.m4a';

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Recording] when startRecording succeeds',
        build: () {
          when(
            mockRepository.startRecording(),
          ).thenAnswer((_) async => const Right(tFilePath));
          return cubit;
        },
        act: (cubit) => cubit.startRecording(),
        expect:
            () => [
              AudioRecorderLoading(),
              isA<AudioRecorderRecording>()
                  .having((state) => state.filePath, 'filePath', tFilePath)
                  .having((state) => state.duration, 'duration', Duration.zero),
            ],
        verify: (_) {
          verify(mockRepository.startRecording()).called(1);
        },
      );

      final tStartFailure = RecordingFailure('Recorder failed to start');

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Error] when startRecording fails',
        build: () {
          when(
            mockRepository.startRecording(),
          ).thenAnswer((_) async => Left(tStartFailure));
          return cubit;
        },
        act: (cubit) => cubit.startRecording(),
        expect:
            () => [
              AudioRecorderLoading(),
              AudioRecorderError(
                'Failed to start recording: ${tStartFailure.toString()}',
              ),
            ],
        verify: (_) {
          verify(mockRepository.startRecording()).called(1);
        },
      );
    });

    group('stopRecording', () {
      const tFilePath = 'stopped/path.m4a';

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Stopped, Loaded] after stopping successfully',
        build: () {
          when(
            mockRepository.stopRecording(),
          ).thenAnswer((_) async => const Right(tFilePath));
          when(
            mockRepository.loadRecordings(),
          ).thenAnswer((_) async => const Right([]));
          return cubit;
        },
        seed:
            () => const AudioRecorderRecording(
              filePath: 'some/path',
              duration: Duration.zero,
            ),
        act: (cubit) => cubit.stopRecording(),
        expect:
            () => [
              AudioRecorderLoading(),
              AudioRecorderStopped(),
              AudioRecorderLoaded(const []),
            ],
        verify: (_) {
          verify(mockRepository.stopRecording()).called(1);
          verify(mockRepository.loadRecordings()).called(1);
        },
      );

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Error] when stop fails',
        build: () {
          final tFailure = RecordingFailure('Stop failed');
          when(
            mockRepository.stopRecording(),
          ).thenAnswer((_) async => Left(tFailure));
          return cubit;
        },
        seed:
            () => const AudioRecorderRecording(
              filePath: 'some/path',
              duration: Duration.zero,
            ),
        act: (cubit) => cubit.stopRecording(),
        expect:
            () => [
              AudioRecorderLoading(),
              AudioRecorderError(
                'Failed to stop recording: ${RecordingFailure('Stop failed').toString()}',
              ),
            ],
        verify: (_) {
          verify(mockRepository.stopRecording()).called(1);
          verifyNever(mockRepository.loadRecordings());
        },
      );

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits nothing if stop called when not in Recording/Paused state',
        build: () {
          return cubit;
        },
        seed: () => AudioRecorderInitial(),
        act: (cubit) => cubit.stopRecording(),
        expect: () => [],
        verify: (_) {
          verifyNever(mockRepository.stopRecording());
          verifyNever(mockRepository.loadRecordings());
        },
      );
    });

    group('pauseRecording', () {
      const tFilePath = 'recording/to/pause.m4a';
      const tDuration = Duration(seconds: 30);
      const tInitialState = AudioRecorderRecording(
        filePath: tFilePath,
        duration: tDuration,
      );

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Paused] from [Recording] when pauseRecording succeeds',
        build: () {
          when(
            mockRepository.pauseRecording(),
          ).thenAnswer((_) async => const Right(null));
          return cubit;
        },
        seed: () => tInitialState,
        act: (cubit) => cubit.pauseRecording(),
        expect:
            () => [
              const AudioRecorderPaused(
                filePath: tFilePath,
                duration: tDuration,
              ),
            ],
        verify: (_) {
          verify(mockRepository.pauseRecording()).called(1);
        },
      );

      final tPauseFailure = RecordingFailure('Pause failed');

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Error] from [Recording] when pauseRecording fails',
        build: () {
          when(
            mockRepository.pauseRecording(),
          ).thenAnswer((_) async => Left(tPauseFailure));
          return cubit;
        },
        seed: () => tInitialState,
        act: (cubit) => cubit.pauseRecording(),
        expect:
            () => [
              AudioRecorderError(
                'Failed to pause: ${tPauseFailure.toString()}',
              ),
            ],
        verify: (_) {
          verify(mockRepository.pauseRecording()).called(1);
        },
      );

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Error] and does not call use case when pausing from non-Recording state',
        build: () => cubit,
        seed: () => AudioRecorderReady(),
        act: (cubit) => cubit.pauseRecording(),
        expect:
            () => [
              AudioRecorderError('Cannot pause: Not currently recording.'),
            ],
        verify: (_) {
          verifyNever(mockRepository.pauseRecording());
        },
      );
    });

    group('resumeRecording', () {
      const tFilePath = 'recording/to/resume.m4a';
      const tDuration = Duration(minutes: 1);
      const tInitialState = AudioRecorderPaused(
        filePath: tFilePath,
        duration: tDuration,
      );

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Recording] from [Paused] when resumeRecording succeeds',
        build: () {
          when(
            mockRepository.resumeRecording(),
          ).thenAnswer((_) async => const Right(null));
          return cubit;
        },
        seed: () => tInitialState,
        act: (cubit) => cubit.resumeRecording(),
        expect:
            () => [
              const AudioRecorderRecording(
                filePath: tFilePath,
                duration: tDuration,
              ),
            ],
        verify: (_) {
          verify(mockRepository.resumeRecording()).called(1);
        },
      );

      final tResumeFailure = RecordingFailure('Resume failed');

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Error] from [Paused] when resumeRecording fails',
        build: () {
          when(
            mockRepository.resumeRecording(),
          ).thenAnswer((_) async => Left(tResumeFailure));
          return cubit;
        },
        seed: () => tInitialState,
        act: (cubit) => cubit.resumeRecording(),
        expect:
            () => [
              AudioRecorderError(
                'Failed to resume: ${tResumeFailure.toString()}',
              ),
            ],
        verify: (_) {
          verify(mockRepository.resumeRecording()).called(1);
        },
      );

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Error] and does not call use case when resuming from non-Paused state',
        build: () => cubit,
        seed: () => AudioRecorderReady(),
        act: (cubit) => cubit.resumeRecording(),
        expect:
            () => [AudioRecorderError('Cannot resume: Not currently paused.')],
        verify: (_) {
          verifyNever(mockRepository.resumeRecording());
        },
      );
    });

    group('checkPermission', () {
      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Ready] when checkPermission returns true',
        build: () {
          when(
            mockRepository.checkPermission(),
          ).thenAnswer((_) async => const Right(true));
          return cubit;
        },
        act: (cubit) => cubit.checkPermission(),
        expect: () => [AudioRecorderLoading(), AudioRecorderReady()],
        verify: (_) {
          verify(mockRepository.checkPermission()).called(1);
          verifyNever(mockRepository.loadRecordings());
        },
      );

      final tCheckFailure = PermissionFailure('Permission check failed');

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Error] when checkPermission fails',
        build: () {
          when(
            mockRepository.checkPermission(),
          ).thenAnswer((_) async => Left(tCheckFailure));
          return cubit;
        },
        act: (cubit) => cubit.checkPermission(),
        expect:
            () => [
              AudioRecorderLoading(),
              AudioRecorderError(
                'Permission check failed: ${tCheckFailure.toString()}',
              ),
            ],
        verify: (_) {
          verify(mockRepository.checkPermission()).called(1);
          verifyNever(mockRepository.loadRecordings());
        },
      );

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, PermissionDenied] when checkPermission returns false',
        build: () {
          when(
            mockRepository.checkPermission(),
          ).thenAnswer((_) async => const Right(false));
          return cubit;
        },
        act: (cubit) => cubit.checkPermission(),
        expect: () => [AudioRecorderLoading(), AudioRecorderPermissionDenied()],
        verify: (_) {
          verify(mockRepository.checkPermission()).called(1);
        },
      );
    });

    group('requestPermission', () {
      final tRequestFailure = PermissionFailure('Request failed');

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Ready] when requestPermission succeeds',
        build: () {
          when(
            mockRepository.requestPermission(),
          ).thenAnswer((_) async => const Right(true));
          return cubit;
        },
        act: (cubit) => cubit.requestPermission(),
        expect: () => [AudioRecorderLoading(), AudioRecorderReady()],
        verify: (_) {
          verify(mockRepository.requestPermission()).called(1);
          verifyNever(mockRepository.loadRecordings());
        },
      );

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, PermissionDenied] when requestPermission returns false',
        build: () {
          when(
            mockRepository.requestPermission(),
          ).thenAnswer((_) async => const Right(false));
          return cubit;
        },
        act: (cubit) => cubit.requestPermission(),
        expect: () => [AudioRecorderLoading(), AudioRecorderPermissionDenied()],
        verify: (_) {
          verify(mockRepository.requestPermission()).called(1);
          verifyNever(mockRepository.loadRecordings());
        },
      );

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Error] when requestPermission fails',
        build: () {
          when(
            mockRepository.requestPermission(),
          ).thenAnswer((_) async => Left(tRequestFailure));
          return cubit;
        },
        act: (cubit) => cubit.requestPermission(),
        expect:
            () => [
              AudioRecorderLoading(),
              AudioRecorderError(
                'Permission request failed: ${tRequestFailure.toString()}',
              ),
            ],
        verify: (_) {
          verify(mockRepository.requestPermission()).called(1);
          verifyNever(mockRepository.loadRecordings());
        },
      );
    });
  });
}
