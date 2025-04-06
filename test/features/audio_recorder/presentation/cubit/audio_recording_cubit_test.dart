// test/features/audio_recorder/presentation/cubit/audio_recording_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter/services.dart';
// For PermissionStatus

// Use the existing mocks generated for the list cubit test
// The build runner will generate mocks for both Repository and PermissionStatus now
import 'audio_list_cubit_test.mocks.dart';

// Generate mocks for Repository only
@GenerateMocks([AudioRecorderRepository]) // Removed PermissionStatus
void main() {
  // Initialize Flutter binding for tests that use platform channels (like permission_handler)
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the permission_handler platform channel
  const MethodChannel channel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'openAppSettings') {
          // Simulate success, return null as the method expects
          return null;
        }
        // Handle other methods if needed, or return null/throw unimplemented
        return null;
      });

  late MockAudioRecorderRepository mockAudioRecorderRepository;
  late AudioRecordingCubit audioRecordingCubit;
  // Remove declaration of unused mock permission status
  // late MockPermissionStatus mockPermissionStatus;

  // Sample data
  const tFilePath = 'test/path/recording.aac';
  final tServerFailure = ServerFailure(); // No message needed
  final tPermissionFailure = PermissionFailure();

  setUp(() {
    mockAudioRecorderRepository = MockAudioRecorderRepository();
    // Remove instantiation of manual mock - the generated one will be used via the import
    // mockPermissionStatus = MockPermissionStatus();
    audioRecordingCubit = AudioRecordingCubit(
      repository: mockAudioRecorderRepository,
    );
  });

  tearDown(() {
    audioRecordingCubit.close();
  });

  // Add tearDownAll to clear the mock handler
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initial state should be AudioRecordingInitial', () {
    expect(audioRecordingCubit.state, equals(AudioRecordingInitial()));
  });

  // --- Permission Tests ---

  group('checkPermission', () {
    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Loading, Ready] when permission is granted',
      build: () {
        when(
          mockAudioRecorderRepository.checkPermission(),
        ).thenAnswer((_) async => const Right(true));
        return audioRecordingCubit;
      },
      act: (cubit) => cubit.checkPermission(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingLoading(),
            AudioRecordingReady(),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.checkPermission()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );

    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Loading, PermissionDenied] when permission is not granted',
      build: () {
        when(
          mockAudioRecorderRepository.checkPermission(),
        ).thenAnswer((_) async => const Right(false));
        return audioRecordingCubit;
      },
      act: (cubit) => cubit.checkPermission(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingLoading(),
            AudioRecordingPermissionDenied(),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.checkPermission()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );

    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Loading, Error] when checkPermission fails',
      build: () {
        when(
          mockAudioRecorderRepository.checkPermission(),
        ).thenAnswer((_) async => Left(tPermissionFailure));
        return audioRecordingCubit;
      },
      act: (cubit) => cubit.checkPermission(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingLoading(),
            AudioRecordingError(
              'Permission check failed: ${tPermissionFailure.toString()}',
            ),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.checkPermission()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );
  });

  group('requestPermission', () {
    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Loading, Ready] when permission request is granted',
      build: () {
        when(
          mockAudioRecorderRepository.requestPermission(),
        ).thenAnswer((_) async => const Right(true));
        return audioRecordingCubit;
      },
      act: (cubit) => cubit.requestPermission(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingLoading(),
            AudioRecordingReady(),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.requestPermission()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );

    // Test Denied (without permanent check, as it's commented out)
    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Loading, PermissionDenied] when permission request is denied',
      build: () {
        when(
          mockAudioRecorderRepository.requestPermission(),
        ).thenAnswer((_) async => const Right(false));
        // Mock getPermissionStatus for future use if uncommented
        // when(mockAudioRecorderRepository.getPermissionStatus())
        //     .thenAnswer((_) async => Right(mockPermissionStatus));
        // when(mockPermissionStatus.isPermanentlyDenied).thenReturn(false);
        // when(mockPermissionStatus.isRestricted).thenReturn(false);
        return audioRecordingCubit;
      },
      act: (cubit) => cubit.requestPermission(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingLoading(),
            AudioRecordingPermissionDenied(),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.requestPermission()).called(1);
        // verify(mockAudioRecorderRepository.getPermissionStatus()).called(1); // Add if uncommented
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );

    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Loading, Error] when requestPermission fails',
      build: () {
        when(
          mockAudioRecorderRepository.requestPermission(),
        ).thenAnswer((_) async => Left(tPermissionFailure));
        return audioRecordingCubit;
      },
      act: (cubit) => cubit.requestPermission(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingLoading(),
            AudioRecordingError(
              'Permission request failed: ${tPermissionFailure.toString()}',
            ),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.requestPermission()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );
  });

  // prepareRecorder just calls checkPermission, could add a simple verify test
  group('prepareRecorder', () {
    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should call checkPermission and emit its results',
      build: () {
        when(
          mockAudioRecorderRepository.checkPermission(),
        ).thenAnswer((_) async => const Right(true));
        return audioRecordingCubit;
      },
      act: (cubit) => cubit.prepareRecorder(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingLoading(), // from checkPermission
            AudioRecordingReady(), // from checkPermission
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.checkPermission()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );
  });

  // openAppSettings doesn't interact with repo directly (uses permission_handler pkg)
  // and calls checkPermission after. Testing checkPermission interaction is enough.
  group('openAppSettings', () {
    // Mock checkPermission behavior after openAppSettings is hypothetically called
    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should call checkPermission after attempting to open settings',
      build: () {
        when(mockAudioRecorderRepository.checkPermission()).thenAnswer(
          (_) async => const Right(true),
        ); // Assume permission granted after settings
        return audioRecordingCubit;
      },
      act: (cubit) async {
        // We can't truly test openAppSettings easily here,
        // so we just trigger the cubit method and verify checkPermission is called.
        await cubit.openAppSettings();
      },
      expect:
          () => <AudioRecordingState>[
            AudioRecordingLoading(), // from checkPermission
            AudioRecordingReady(), // from checkPermission
          ],
      verify: (_) {
        // Verify checkPermission was called (implicitly after openAppSettings)
        verify(mockAudioRecorderRepository.checkPermission()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );
  });

  // --- Recording Lifecycle Tests ---

  group('startRecording', () {
    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Loading, RecordingInProgress] when successful',
      build: () {
        when(
          mockAudioRecorderRepository.startRecording(),
        ).thenAnswer((_) async => const Right(tFilePath));
        return audioRecordingCubit;
      },
      seed: () => AudioRecordingReady(), // Start from Ready state
      act: (cubit) => cubit.startRecording(),
      // Fix expect to wrap the TypeMatcher
      expect:
          () => <dynamic>[
            AudioRecordingLoading(),
            isA<AudioRecordingInProgress>()
                .having((state) => state.filePath, 'filePath', tFilePath)
                .having((state) => state.duration, 'duration', Duration.zero),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.startRecording()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );

    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Loading, Error] when startRecording fails',
      build: () {
        when(
          mockAudioRecorderRepository.startRecording(),
        ).thenAnswer((_) async => Left(tServerFailure));
        return audioRecordingCubit;
      },
      seed: () => AudioRecordingReady(),
      act: (cubit) => cubit.startRecording(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingLoading(),
            AudioRecordingError(
              'Failed to start recording: ${tServerFailure.toString()}',
            ),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.startRecording()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );
  });

  group('stopRecording', () {
    // ... tests remain the same ...
    final recordingState = AudioRecordingInProgress(
      filePath: tFilePath,
      duration: Duration(seconds: 5),
    );

    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Loading, Stopped] when successful',
      build: () {
        when(
          mockAudioRecorderRepository.stopRecording(),
        ).thenAnswer((_) async => const Right(tFilePath));
        return audioRecordingCubit;
      },
      seed: () => recordingState,
      act: (cubit) => cubit.stopRecording(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingLoading(),
            AudioRecordingStopped(tFilePath),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.stopRecording()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );

    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Loading, Error] when stopRecording fails',
      build: () {
        when(
          mockAudioRecorderRepository.stopRecording(),
        ).thenAnswer((_) async => Left(tServerFailure));
        return audioRecordingCubit;
      },
      seed: () => recordingState,
      act: (cubit) => cubit.stopRecording(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingLoading(),
            AudioRecordingError(
              'Failed to stop recording: ${tServerFailure.toString()}',
            ),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.stopRecording()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );

    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should do nothing if not in Recording or Paused state',
      build: () => audioRecordingCubit,
      seed: () => AudioRecordingReady(), // Start from Ready state
      act: (cubit) => cubit.stopRecording(),
      expect: () => <AudioRecordingState>[], // No state changes expected
      verify: (_) {
        // Verify stopRecording was NOT called
        verifyNever(mockAudioRecorderRepository.stopRecording());
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );
  });

  group('pauseRecording', () {
    final recordingState = AudioRecordingInProgress(
      filePath: tFilePath,
      duration: Duration(seconds: 5),
    );

    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Paused] when successful',
      build: () {
        when(
          mockAudioRecorderRepository.pauseRecording(),
        ).thenAnswer((_) async => const Right(null));
        return audioRecordingCubit;
      },
      seed: () => recordingState,
      act: (cubit) => cubit.pauseRecording(),
      // Fix expect to wrap the TypeMatcher
      expect:
          () => <dynamic>[
            isA<AudioRecordingPaused>()
                .having((state) => state.filePath, 'filePath', tFilePath)
                .having(
                  (state) => state.duration,
                  'duration',
                  recordingState.duration,
                ),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.pauseRecording()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );

    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Error] when pauseRecording fails',
      build: () {
        when(
          mockAudioRecorderRepository.pauseRecording(),
        ).thenAnswer((_) async => Left(tServerFailure));
        return audioRecordingCubit;
      },
      seed: () => recordingState,
      act: (cubit) => cubit.pauseRecording(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingError(
              'Failed to pause: ${tServerFailure.toString()}',
            ),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.pauseRecording()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );

    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Error] if not in Recording state',
      build: () => audioRecordingCubit,
      seed: () => AudioRecordingReady(), // Start from Ready state
      act: (cubit) => cubit.pauseRecording(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingError('Cannot pause: Not currently recording.'),
          ],
      verify: (_) {
        verifyNever(mockAudioRecorderRepository.pauseRecording());
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );
  });

  group('resumeRecording', () {
    final pausedState = AudioRecordingPaused(
      filePath: tFilePath,
      duration: Duration(seconds: 5),
    );

    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [RecordingInProgress] when successful',
      build: () {
        when(
          mockAudioRecorderRepository.resumeRecording(),
        ).thenAnswer((_) async => const Right(null));
        return audioRecordingCubit;
      },
      seed: () => pausedState,
      act: (cubit) => cubit.resumeRecording(),
      // Fix expect to wrap the TypeMatcher
      expect:
          () => <dynamic>[
            isA<AudioRecordingInProgress>()
                .having((state) => state.filePath, 'filePath', tFilePath)
                .having(
                  (state) => state.duration,
                  'duration',
                  pausedState.duration,
                ),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.resumeRecording()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );

    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Error] when resumeRecording fails',
      build: () {
        when(
          mockAudioRecorderRepository.resumeRecording(),
        ).thenAnswer((_) async => Left(tServerFailure));
        return audioRecordingCubit;
      },
      seed: () => pausedState,
      act: (cubit) => cubit.resumeRecording(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingError(
              'Failed to resume: ${tServerFailure.toString()}',
            ),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.resumeRecording()).called(1);
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );

    blocTest<AudioRecordingCubit, AudioRecordingState>(
      'should emit [Error] if not in Paused state',
      build: () => audioRecordingCubit,
      seed: () => AudioRecordingReady(), // Start from Ready state
      act: (cubit) => cubit.resumeRecording(),
      expect:
          () => <AudioRecordingState>[
            AudioRecordingError('Cannot resume: Not currently paused.'),
          ],
      verify: (_) {
        verifyNever(mockAudioRecorderRepository.resumeRecording());
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );
  });
}

// Remove manual mock class definition
// class MockPermissionStatus extends Mock implements PermissionStatus {}
