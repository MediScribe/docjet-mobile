// ignore_for_file: unused_import

import 'dart:io'; // Keep for FileSystemEntityType, FileSystemException, Directory

import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart'; // Needed for test setup
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:permission_handler/permission_handler.dart'
    show Permission, PermissionStatus; // Use specific imports if needed
import 'package:record/record.dart'; // For mocking AudioRecorder
import 'package:dartz/dartz.dart'; // For Either if needed in mocks/results
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart'; // For potential exception tests
import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart'; // For verifying saveJob arguments later
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_retriever.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart'; // For status enum

// Import generated mocks (will be created after running build_runner)
import 'audio_local_data_source_impl_test.mocks.dart';

// Define mocks for dependencies
@GenerateMocks([
  AudioRecorder,
  PathProvider,
  PermissionHandler,
  AudioConcatenationService,
  FileSystem,
  LocalJobStore,
  AudioDurationRetriever,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Declare late variables for mocks and the class under test
  late MockAudioRecorder mockRecorder;
  late MockPathProvider mockPathProvider;
  late MockPermissionHandler mockPermissionHandler;
  late MockAudioConcatenationService mockAudioConcatenationService;
  late MockFileSystem mockFileSystem;
  late MockLocalJobStore mockLocalJobStore;
  late MockAudioDurationRetriever mockAudioDurationRetriever;
  late AudioLocalDataSourceImpl dataSource;

  setUpAll(() {
    // Provide dummies if needed by mockito for verification matching
    provideDummy<FileSystemEntityType>(FileSystemEntityType.file);
    provideDummy<PermissionStatus>(PermissionStatus.granted);
    provideDummy<Map<Permission, PermissionStatus>>({});
    provideDummy<AudioRecord>(
      AudioRecord(
        filePath: '',
        duration: Duration.zero,
        createdAt: DateTime(0),
      ),
    );
  });

  setUp(() {
    // Initialize mocks
    mockRecorder = MockAudioRecorder();
    mockPathProvider = MockPathProvider();
    mockPermissionHandler = MockPermissionHandler();
    mockAudioConcatenationService = MockAudioConcatenationService();
    mockFileSystem = MockFileSystem();
    mockLocalJobStore = MockLocalJobStore();
    mockAudioDurationRetriever = MockAudioDurationRetriever();

    // Create the instance of the class under test with mocks
    dataSource = AudioLocalDataSourceImpl(
      recorder: mockRecorder,
      pathProvider: mockPathProvider,
      permissionHandler: mockPermissionHandler,
      audioConcatenationService: mockAudioConcatenationService,
      fileSystem: mockFileSystem,
      localJobStore: mockLocalJobStore,
      audioDurationRetriever: mockAudioDurationRetriever,
    );

    // Common mock setup for path provider - REMOVED mockDirectory references
    // when(mockDirectory.path).thenReturn(tFakeDocPath); // REMOVED
    // when(
    //   mockPathProvider.getApplicationDocumentsDirectory(),
    // ).thenAnswer((_) async => mockDirectory); // REMOVED
  });

  // --- Test groups will go here ---
  group('Permissions', () {
    // TODO: Add tests for checkPermission and requestPermission
  });

  group('Recording Lifecycle', () {
    // TODO: Add tests for startRecording, stopRecording, pauseRecording, resumeRecording
  });

  group('File Operations', () {
    // TODO: Add more tests for listRecordingDetails (e.g., duration error, non-file .m4a)
  });

  group('Concatenation (Dummy)', () {
    // TODO: Add tests for appendRecording (interactions with dummy service)
  });

  group('stopRecording', () {
    const tRecordingPath = 'test/path/recording.m4a';

    test(
      'should call recorder.stop and return the path WHEN recording stops successfully (BEFORE Iteration 2)',
      () async {
        // Arrange
        when(mockRecorder.stop()).thenAnswer((_) async => tRecordingPath);
        when(mockFileSystem.fileExists(any)).thenAnswer((_) async => true);
        // Add stub for getDuration, even though this test doesn't verify it, because the code now calls it.
        when(
          mockAudioDurationRetriever.getDuration(any),
        ).thenAnswer((_) async => Duration.zero);
        // Add stub for saveJob as well, as the code path now reaches it.
        when(mockLocalJobStore.saveJob(any)).thenAnswer((_) async {});

        // Act
        final result = await dataSource.stopRecording(
          recordingPath: tRecordingPath,
        );

        // Assert
        verify(mockRecorder.stop());
        verify(mockFileSystem.fileExists(tRecordingPath));
        // Now verify the new calls were made, even if the test name doesn't imply it
        verify(mockAudioDurationRetriever.getDuration(tRecordingPath));
        verify(mockLocalJobStore.saveJob(any));
        // Check the result
        expect(result, equals(tRecordingPath));
      },
    );

    test(
      'should throw NoActiveRecordingException if recorder.stop returns null',
      () async {
        // Arrange
        when(mockRecorder.stop()).thenAnswer((_) async => null);
        // Add stub even if logically unreachable due to Mockito requirements
        when(mockFileSystem.fileExists(any)).thenAnswer((_) async => true);

        // Act
        final call = dataSource.stopRecording(recordingPath: tRecordingPath);

        // Assert
        await expectLater(call, throwsA(isA<NoActiveRecordingException>()));
        verify(mockRecorder.stop());
        verifyZeroInteractions(
          mockFileSystem,
        ); // Still expect no interaction here
        verifyZeroInteractions(mockAudioDurationRetriever);
        verifyZeroInteractions(mockLocalJobStore);
      },
    );

    test(
      'should throw RecordingFileNotFoundException if file does not exist after stop',
      () async {
        // Arrange
        when(mockRecorder.stop()).thenAnswer((_) async => tRecordingPath);
        when(mockFileSystem.fileExists(any)).thenAnswer((_) async => false);

        // Act
        final call = dataSource.stopRecording(recordingPath: tRecordingPath);

        // Assert
        await expectLater(call, throwsA(isA<RecordingFileNotFoundException>()));
        verify(mockRecorder.stop());
        verify(mockFileSystem.fileExists(tRecordingPath));
        verifyZeroInteractions(mockAudioDurationRetriever);
        verifyZeroInteractions(mockLocalJobStore);
      },
    );

    // --- Tests for Iteration 2 logic will go below this line ---

    test(
      'should get duration and save LocalJob when recording stops successfully and file exists',
      () async {
        // Arrange
        const tFinalPath = 'test/path/final_recording.m4a';
        const tDuration = Duration(seconds: 30);
        when(mockRecorder.stop()).thenAnswer((_) async => tFinalPath);
        when(
          mockFileSystem.fileExists(tFinalPath),
        ).thenAnswer((_) async => true);
        when(
          mockAudioDurationRetriever.getDuration(tFinalPath),
        ).thenAnswer((_) async => tDuration);
        // Use `any` for the job argument initially, can refine later if needed
        when(mockLocalJobStore.saveJob(any)).thenAnswer((_) async {});

        // Act
        final result = await dataSource.stopRecording(
          recordingPath: 'irrelevant/initial/path',
        ); // Initial path doesn't matter much here

        // Assert
        expect(
          result,
          equals(tFinalPath),
        ); // Ensure it still returns the correct path
        // Verify duration retrieval
        verify(mockAudioDurationRetriever.getDuration(tFinalPath));
        // Verify job saving
        final verificationResult = verify(
          mockLocalJobStore.saveJob(captureAny),
        );
        verificationResult.called(1);
        // Check the captured job details
        final capturedJob = verificationResult.captured.single as LocalJob;
        expect(capturedJob.localFilePath, tFinalPath);
        expect(capturedJob.durationMillis, tDuration.inMilliseconds);
        expect(capturedJob.status, TranscriptionStatus.created);
        expect(capturedJob.backendId, isNull);
        // Optional: Check createdAt is recent (within a few seconds)
        expect(
          capturedJob.localCreatedAt.isAfter(
            DateTime.now().subtract(const Duration(seconds: 5)),
          ),
          isTrue,
        );
      },
    );
  });

  // TODO: Add test groups for other methods (startRecording, pauseRecording, etc.)
} // End of main
