import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/check_permission.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/delete_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/load_recordings.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/pause_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/request_permission.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/resume_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/start_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/stop_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recorder_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recorder_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for all the use cases
@GenerateMocks([
  CheckPermission,
  RequestPermission,
  StartRecording,
  StopRecording,
  PauseRecording,
  ResumeRecording,
  DeleteRecording,
  LoadRecordings,
])
import 'audio_recorder_cubit_test.mocks.dart'; // Import generated mocks

void main() {
  // Declare late variables for the cubit and mocks
  late AudioRecorderCubit cubit;
  late MockCheckPermission mockCheckPermission;
  late MockRequestPermission mockRequestPermission;
  late MockStartRecording mockStartRecording;
  late MockStopRecording mockStopRecording;
  late MockPauseRecording mockPauseRecording;
  late MockResumeRecording mockResumeRecording;
  late MockDeleteRecording mockDeleteRecording;
  late MockLoadRecordings mockLoadRecordings;

  setUp(() {
    // Initialize mocks
    mockCheckPermission = MockCheckPermission();
    mockRequestPermission = MockRequestPermission();
    mockStartRecording = MockStartRecording();
    mockStopRecording = MockStopRecording();
    mockPauseRecording = MockPauseRecording();
    mockResumeRecording = MockResumeRecording();
    mockDeleteRecording = MockDeleteRecording();
    mockLoadRecordings = MockLoadRecordings();

    // Initialize the cubit with mocks
    cubit = AudioRecorderCubit(
      checkPermissionUseCase: mockCheckPermission,
      requestPermissionUseCase: mockRequestPermission,
      startRecordingUseCase: mockStartRecording,
      stopRecordingUseCase: mockStopRecording,
      pauseRecordingUseCase: mockPauseRecording,
      resumeRecordingUseCase: mockResumeRecording,
      deleteRecordingUseCase: mockDeleteRecording,
      loadRecordingsUseCase: mockLoadRecordings,
    );
  });

  // Test groups will go here
  group('AudioRecorderCubit Tests', () {
    test('initial state is AudioRecorderInitial', () {
      expect(cubit.state, AudioRecorderInitial());
    });

    group('deleteRecording', () {
      const tFilePath = 'test/path/recording.m4a';
      final tDeleteParams = DeleteRecordingParams(filePath: tFilePath);
      final tNoParams = NoParams(); // Added for clarity
      final List<AudioRecord> tPostDeleteRecordings = [];
      final List<AudioRecordState> tPostDeleteStates =
          []; // Map to state entity

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, ListLoaded] and calls use cases when delete succeeds',
        build: () {
          // Arrange: Use specific params
          when(mockDeleteRecording(tDeleteParams)) // Use specific params
          .thenAnswer((_) async => const Right(null));
          when(mockLoadRecordings(tNoParams)) // Use specific params
          .thenAnswer((_) async => Right(tPostDeleteRecordings));
          return cubit;
        },
        act: (cubit) async {
          await cubit.deleteRecording(tFilePath);
        },
        expect:
            () => [
              AudioRecorderLoading(), // From deleteRecording start
              AudioRecorderListLoaded(
                recordings: tPostDeleteStates, // From loadRecordings completion
              ),
            ],
        verify: (_) {
          // Verify delete call count and arguments
          final deleteArgCapture =
              verify(mockDeleteRecording(captureAny)).captured;
          expect(deleteArgCapture.single, isA<DeleteRecordingParams>());
          expect(
            (deleteArgCapture.single as DeleteRecordingParams).filePath,
            tFilePath,
          );
          // verify(mockDeleteRecording(any)).called(1); // Covered by capture

          // Verify load call count ONLY (for now)
          verify(mockLoadRecordings(any)).called(1);
        },
      );

      // Add test for deleteRecording failure
      final tFailure = PermissionFailure(
        'Deletion failed',
      ); // Define failure here
      final List<AudioRecord> tEmptyRecordings =
          []; // Define empty list for load mock
      final List<AudioRecordState> tEmptyStates = []; // Define empty state list

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Error] and calls delete use case when delete fails',
        build: () {
          // Arrange: Mock delete failure
          when(
            mockDeleteRecording(tDeleteParams),
          ).thenAnswer((_) async => Left(tFailure));
          // Arrange: Mock subsequent loadRecordings call (should succeed even if delete failed)
          when(
            mockLoadRecordings(tNoParams),
          ).thenAnswer((_) async => Right(tEmptyRecordings));
          return cubit;
        },
        act: (cubit) => cubit.deleteRecording(tFilePath),
        expect:
            () => [
              AudioRecorderLoading(),
              AudioRecorderError(
                'Failed to delete $tFilePath: ${tFailure.toString()}',
              ),
              AudioRecorderLoading(), // From the subsequent loadRecordings call
              AudioRecorderListLoaded(
                recordings: tEmptyStates,
              ), // From the loadRecordings success
            ],
        verify: (_) {
          // Verify delete was called, load was NOT called
          verify(mockDeleteRecording(tDeleteParams)).called(1);
          // Verify load WAS called after delete failure
          verify(mockLoadRecordings(tNoParams)).called(1);
        },
      );

      // TODO: Add test for deleteRecording failure
    });

    group('loadRecordings', () {
      final tNoParams = NoParams();
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
      // Map domain entities to state entities
      final tRecordingStates =
          tRecordings
              .map(
                (r) => AudioRecordState(
                  filePath: r.filePath,
                  duration: r.duration,
                  createdAt: r.createdAt,
                ),
              )
              .toList();

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, ListLoaded] when loadRecordings succeeds',
        build: () {
          when(
            mockLoadRecordings(tNoParams),
          ).thenAnswer((_) async => Right(tRecordings));
          return cubit;
        },
        act: (cubit) => cubit.loadRecordings(),
        expect:
            () => [
              AudioRecorderLoading(),
              AudioRecorderListLoaded(recordings: tRecordingStates),
            ],
        verify: (_) {
          verify(mockLoadRecordings(tNoParams)).called(1);
        },
      );

      // Add test for loadRecordings failure
      final tLoadFailure = FileSystemFailure('Failed to load files');

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Error] when loadRecordings fails',
        build: () {
          when(
            mockLoadRecordings(tNoParams),
          ).thenAnswer((_) async => Left(tLoadFailure));
          return cubit;
        },
        act: (cubit) => cubit.loadRecordings(),
        expect:
            () => [
              AudioRecorderLoading(),
              AudioRecorderError(
                'Failed to load recordings: ${tLoadFailure.toString()}',
              ),
            ],
        verify: (_) {
          verify(mockLoadRecordings(tNoParams)).called(1);
        },
      );

      // TODO: Add test for loadRecordings failure
    });

    group('startRecording', () {
      final tNoParams = NoParams();
      const tFilePath = 'new/recording/path.m4a';

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Recording] when startRecording succeeds',
        build: () {
          when(
            mockStartRecording(tNoParams),
          ).thenAnswer((_) async => const Right(tFilePath));
          return cubit;
        },
        act: (cubit) => cubit.startRecording(),
        // We expect Loading, then Recording with initial duration zero
        expect:
            () => [
              AudioRecorderLoading(),
              const AudioRecorderRecording(
                filePath: tFilePath,
                duration: Duration.zero,
              ),
            ],
        verify: (_) {
          verify(mockStartRecording(tNoParams)).called(1);
          // Optionally: Verify timer started if mockable/testable
        },
      );

      // Add test for startRecording failure
      final tStartFailure = RecordingFailure('Failed to start');

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Error] when startRecording fails',
        build: () {
          when(
            mockStartRecording(tNoParams),
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
          verify(mockStartRecording(tNoParams)).called(1);
        },
      );

      // TODO: Add test for startRecording failure
    });

    group('stopRecording', () {
      const tFilePath = 'stopped/path.m4a';
      // final tRecordings = [ // REMOVED Unused variable
      //   AudioRecord(
      //     filePath: tFilePath,
      //     duration: const Duration(seconds: 5),
      //     createdAt: DateTime.now(),
      //   ),
      // ]; // Sample list returned by loadRecordings

      // REFACTORING to use blocTest for better lifecycle management
      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Stopped] after stopping successfully',
        build: () {
          // Arrange: Mock stop success
          when(
            mockStopRecording(any),
          ).thenAnswer((_) async => const Right(tFilePath));
          return cubit;
        },
        seed:
            () => const AudioRecorderRecording(
              // Arrange: Initial state
              filePath: 'some/path',
              duration: Duration.zero,
            ),
        act: (cubit) => cubit.stopRecording(),
        expect:
            () => [
              // Assert: Expected states
              AudioRecorderLoading(),
              AudioRecorderStopped(),
            ],
        verify: (_) {
          // Verify
          verify(mockStopRecording(NoParams()));
          verifyNever(mockLoadRecordings(any));
        },
      );

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Error] when stop fails',
        build: () {
          // Arrange: Mock stop failure
          final tFailure = RecordingFailure('Stop failed');
          when(mockStopRecording(any)).thenAnswer((_) async => Left(tFailure));
          return cubit;
        },
        seed:
            () => const AudioRecorderRecording(
              // Arrange: Initial state
              filePath: 'some/path',
              duration: Duration.zero,
            ),
        act: (cubit) => cubit.stopRecording(),
        expect:
            () => [
              // Assert: Expected states
              AudioRecorderLoading(),
              AudioRecorderError(
                'Failed to stop recording: RecordingFailure(Stop failed)', // Ensure full error message
              ),
            ],
        verify: (_) {
          // Verify
          verify(mockStopRecording(NoParams()));
          verifyNever(mockLoadRecordings(any));
        },
      );

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits nothing if stop called when not in Recording/Paused state',
        build: () {
          // No mocks needed as use cases shouldn't be called
          return cubit;
        },
        seed:
            () =>
                AudioRecorderInitial(), // Arrange: Initial state (not Recording/Paused)
        act: (cubit) => cubit.stopRecording(),
        expect: () => [], // Assert: Expect NO state changes
        verify: (_) {
          // Verify
          verifyNever(mockStopRecording(any));
          verifyNever(mockLoadRecordings(any));
        },
      );
    });

    group('pauseRecording', () {
      final tNoParams = NoParams();
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
            mockPauseRecording(tNoParams),
          ).thenAnswer((_) async => const Right(null));
          return cubit;
        },
        seed: () => tInitialState, // Start in Recording state
        act: (cubit) => cubit.pauseRecording(),
        expect:
            () => [
              const AudioRecorderPaused(
                filePath: tFilePath,
                duration: tDuration,
              ),
            ],
        verify: (_) {
          verify(mockPauseRecording(tNoParams)).called(1);
          // Optionally: Verify timer stopped if mockable/testable
        },
      );

      // Add test for pauseRecording failure
      final tPauseFailure = RecordingFailure('Pause failed');

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Error] from [Recording] when pauseRecording fails',
        build: () {
          when(
            mockPauseRecording(tNoParams),
          ).thenAnswer((_) async => Left(tPauseFailure));
          return cubit;
        },
        seed: () => tInitialState, // Start in Recording state
        act: (cubit) => cubit.pauseRecording(),
        expect:
            () => [
              AudioRecorderError(
                'Failed to pause: ${tPauseFailure.toString()}',
              ),
            ],
        verify: (_) {
          verify(mockPauseRecording(tNoParams)).called(1);
          // Note: Cubit logic keeps timer paused on failure, maybe verify?
        },
      );

      // Add test for pauseRecording from invalid state
      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Error] and does not call use case when pausing from non-Recording state',
        build: () => cubit,
        seed: () => AudioRecorderReady(), // Start in Ready state
        act: (cubit) => cubit.pauseRecording(),
        expect:
            () => [
              AudioRecorderError('Cannot pause: Not currently recording.'),
            ],
        verify: (_) {
          verifyNever(mockPauseRecording(any));
        },
      );

      // TODO: Add test for pauseRecording failure
      // TODO: Add test for pauseRecording from invalid state
    });

    group('resumeRecording', () {
      final tNoParams = NoParams();
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
            mockResumeRecording(tNoParams),
          ).thenAnswer((_) async => const Right(null));
          return cubit;
        },
        seed: () => tInitialState, // Start in Paused state
        act: (cubit) => cubit.resumeRecording(),
        expect:
            () => [
              const AudioRecorderRecording(
                filePath: tFilePath,
                duration: tDuration,
              ),
            ],
        verify: (_) {
          verify(mockResumeRecording(tNoParams)).called(1);
          // Optionally: Verify timer started if mockable/testable
        },
      );

      // Add test for resumeRecording failure
      final tResumeFailure = RecordingFailure('Resume failed');

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Error] from [Paused] when resumeRecording fails',
        build: () {
          when(
            mockResumeRecording(tNoParams),
          ).thenAnswer((_) async => Left(tResumeFailure));
          return cubit;
        },
        seed: () => tInitialState, // Start in Paused state
        act: (cubit) => cubit.resumeRecording(),
        expect:
            () => [
              AudioRecorderError(
                'Failed to resume: ${tResumeFailure.toString()}',
              ),
            ],
        verify: (_) {
          verify(mockResumeRecording(tNoParams)).called(1);
        },
      );

      // Add test for resumeRecording from invalid state
      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Error] and does not call use case when resuming from non-Paused state',
        build: () => cubit,
        seed: () => AudioRecorderReady(), // Start in Ready state
        act: (cubit) => cubit.resumeRecording(),
        expect:
            () => [AudioRecorderError('Cannot resume: Not currently paused.')],
        verify: (_) {
          verifyNever(mockResumeRecording(any));
        },
      );

      // TODO: Add test for resumeRecording failure
      // TODO: Add test for resumeRecording from invalid state
    });

    group('checkPermission', () {
      final tNoParams = NoParams();
      // final List<AudioRecord> tEmptyRecordings = []; // REMOVED
      // final List<AudioRecorderState> tEmptyStates = []; // REMOVED

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Ready] when checkPermission returns true',
        build: () {
          when(
            mockCheckPermission(tNoParams),
          ).thenAnswer((_) async => const Right(true));
          return cubit;
        },
        act: (cubit) => cubit.checkPermission(),
        expect: () => [AudioRecorderLoading(), AudioRecorderReady()],
        verify: (_) {
          verify(mockCheckPermission(tNoParams)).called(1);
          verifyNever(mockLoadRecordings(any));
        },
      );

      // Add test for checkPermission returning false
      final tCheckFailure = PermissionFailure('Permission check failed');

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Error] when checkPermission fails',
        build: () {
          when(
            mockCheckPermission(tNoParams),
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
          verify(mockCheckPermission(tNoParams)).called(1);
          verifyNever(
            mockLoadRecordings(any),
          ); // Ensure load not called on failure
        },
      );
    });

    group('requestPermission', () {
      final tNoParams = NoParams();
      final tRequestFailure = PermissionFailure('Request failed');
      // final List<AudioRecord> tEmptyRecordings = []; // REMOVED
      // final List<AudioRecorderState> tEmptyStates = []; // REMOVED

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Ready] when requestPermission succeeds',
        build: () {
          when(
            mockRequestPermission(tNoParams),
          ).thenAnswer((_) async => const Right(true));
          return cubit;
        },
        act: (cubit) => cubit.requestPermission(),
        expect: () => [AudioRecorderLoading(), AudioRecorderReady()],
        verify: (_) {
          verify(mockRequestPermission(tNoParams)).called(1);
          verifyNever(mockLoadRecordings(any));
        },
      );

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, PermissionDenied] when requestPermission returns false',
        build: () {
          when(
            mockRequestPermission(tNoParams),
          ).thenAnswer((_) async => const Right(false));
          return cubit;
        },
        act: (cubit) => cubit.requestPermission(),
        expect: () => [AudioRecorderLoading(), AudioRecorderPermissionDenied()],
        verify: (_) {
          verify(mockRequestPermission(tNoParams)).called(1);
          verifyNever(mockLoadRecordings(any));
        },
      );

      blocTest<AudioRecorderCubit, AudioRecorderState>(
        'emits [Loading, Error] when requestPermission fails',
        build: () {
          when(
            mockRequestPermission(tNoParams),
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
          verify(mockRequestPermission(tNoParams)).called(1);
          verifyNever(mockLoadRecordings(any));
        },
      );
    });
  });
}
