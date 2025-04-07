import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:record/record.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';

import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
import 'package:docjet_mobile/features/audio_recorder/data/repositories/audio_recorder_repository_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_file_manager.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/transcription_remote_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/transcription_merge_service.dart';

// Entities might be needed if test data uses them, but not directly by these recording actions
// import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
// import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
// import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';

@GenerateNiceMocks([
  MockSpec<AudioLocalDataSource>(),
  MockSpec<AudioFileManager>(),
  MockSpec<LocalJobStore>(),
  MockSpec<TranscriptionRemoteDataSource>(),
  MockSpec<TranscriptionMergeService>(),
  MockSpec<AudioRecorder>(),
  MockSpec<FileSystem>(),
  MockSpec<PathProvider>(),
  MockSpec<PermissionHandler>(),
  MockSpec<AudioConcatenationService>(),
  MockSpec<Directory>(),
  MockSpec<FileStat>(),
  MockSpec<FileSystemEntity>(),
])
import 'audio_recorder_repository_impl_recording_test.mocks.dart'; // Adjusted mock import name

void main() {
  late AudioRecorderRepositoryImpl repository;
  late MockAudioLocalDataSource mockAudioLocalDataSource;
  late MockAudioFileManager mockFileManager;
  late MockLocalJobStore mockLocalJobStore;
  late MockTranscriptionRemoteDataSource mockRemoteDataSource;
  late MockTranscriptionMergeService mockTranscriptionMergeService;

  setUp(() {
    mockAudioLocalDataSource = MockAudioLocalDataSource();
    mockFileManager = MockAudioFileManager();
    mockLocalJobStore = MockLocalJobStore();
    mockRemoteDataSource = MockTranscriptionRemoteDataSource();
    mockTranscriptionMergeService = MockTranscriptionMergeService();

    repository = AudioRecorderRepositoryImpl(
      localDataSource: mockAudioLocalDataSource,
      fileManager: mockFileManager,
      localJobStore: mockLocalJobStore,
      remoteDataSource: mockRemoteDataSource,
      transcriptionMergeService: mockTranscriptionMergeService,
    );
  });

  // --- Test Groups for Recording Lifecycle ---
  group('startRecording', () {
    const tRecordingPath = '/path/to/recording.m4a';

    test('should call localDataSource.startRecording and store path', () async {
      // Arrange
      when(
        mockAudioLocalDataSource.startRecording(),
      ).thenAnswer((_) async => tRecordingPath);
      // Act
      final result = await repository.startRecording();
      // Assert
      expect(
        result,
        equals(const Right(tRecordingPath)),
      ); // Repository now returns path
      verify(mockAudioLocalDataSource.startRecording());
      verifyNoMoreInteractions(mockAudioLocalDataSource);
      verifyZeroInteractions(mockFileManager);
      verifyZeroInteractions(mockLocalJobStore);
      verifyZeroInteractions(mockRemoteDataSource);
    });

    test(
      'should return Failure when localDataSource.startRecording throws',
      () async {
        // Arrange
        const tException = AudioRecordingException('Start failed');
        when(mockAudioLocalDataSource.startRecording()).thenThrow(tException);
        // Act
        final result = await repository.startRecording();
        // Assert
        expect(result, equals(Left(RecordingFailure(tException.message))));
        verify(mockAudioLocalDataSource.startRecording());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
        verifyZeroInteractions(mockFileManager);
        verifyZeroInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockRemoteDataSource);
      },
    );
  });

  group('stopRecording', () {
    const tRecordingPath = '/path/to/stop/recording.m4a';
    const tFinalPath = '$tRecordingPath-final';

    setUp(() {
      // Ensure the repository's internal state is clean before each test in this group
      // This is implicitly handled by creating a new repository in the main setUp,
      // but being explicit can help if tests manipulate state unexpectedly.
      // repository = AudioRecorderRepositoryImpl(...); // Re-init if needed
    });

    test(
      'should call localDataSource.stopRecording with stored path and return Right(finalPath)',
      () async {
        // Arrange: Simulate startRecording first to set the path
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => tRecordingPath);
        final startResult =
            await repository
                .startRecording(); // Set internal state and capture result

        // Verify startRecording actually succeeded and returned the expected path
        expect(
          startResult.isRight(),
          isTrue,
          reason: 'startRecording should have succeeded to set the path',
        );
        expect(startResult.getOrElse(() => 'FAILURE'), equals(tRecordingPath));

        when(
          mockAudioLocalDataSource.stopRecording(recordingPath: tRecordingPath),
        ).thenAnswer((_) async => tFinalPath);

        // Act
        final result = await repository.stopRecording();

        // Assert
        expect(result, equals(const Right(tFinalPath)));
        // Verify start was called once, stop was called once with correct path
        verify(mockAudioLocalDataSource.startRecording()).called(1);
        verify(
          mockAudioLocalDataSource.stopRecording(recordingPath: tRecordingPath),
        ).called(1);
        verifyNoMoreInteractions(
          mockAudioLocalDataSource,
        ); // Ensure only expected calls happened

        // Verify internal state reset: Subsequent calls fail correctly
        final result2 = await repository.stopRecording();
        expect(
          result2,
          equals(
            const Left(
              RecordingFailure('No recording path stored in repository.'),
            ),
          ),
        );
        // Verify stopRecording wasn't called again
        verifyNever(
          mockAudioLocalDataSource.stopRecording(
            recordingPath: anyNamed('recordingPath'),
          ),
        );
      },
    );

    test(
      'should return Left(RecordingFailure) when stopRecording throws',
      () async {
        // Arrange: Simulate startRecording first
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => tRecordingPath);
        await repository.startRecording(); // Set internal state

        const tException = AudioRecordingException('Stop failed');
        when(
          mockAudioLocalDataSource.stopRecording(recordingPath: tRecordingPath),
        ).thenThrow(tException);

        // Act
        final result = await repository.stopRecording();

        // Assert
        expect(result, equals(Left(RecordingFailure(tException.message))));
        verify(mockAudioLocalDataSource.startRecording()).called(1);
        verify(
          mockAudioLocalDataSource.stopRecording(recordingPath: tRecordingPath),
        ).called(1);
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return Left(RecordingFailure) if startRecording was not called first',
      () async {
        // Arrange: No call to startRecording, repository state is null

        // Act
        final result = await repository.stopRecording();

        // Assert
        expect(
          result,
          equals(
            const Left(
              RecordingFailure('No recording path stored in repository.'),
            ),
          ),
        );
        verifyNever(
          mockAudioLocalDataSource.stopRecording(
            recordingPath: anyNamed('recordingPath'),
          ),
        );
        // Important: Verify zero interactions overall if start wasn't called
        verifyZeroInteractions(mockAudioLocalDataSource);
      },
    );
  });

  group('pauseRecording', () {
    const tRecordingPath = '/path/to/pause/recording.m4a';

    setUp(() {
      // Reset repository state if necessary
    });

    test(
      'should call localDataSource.pauseRecording with stored path',
      () async {
        // Arrange: Simulate startRecording first
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => tRecordingPath);
        await repository.startRecording(); // Set internal state

        when(
          mockAudioLocalDataSource.pauseRecording(
            recordingPath: tRecordingPath,
          ),
          // Ensure the mock returns a Future<void> which resolves to null
        ).thenAnswer((_) async => Future<void>.value());

        // Act
        final result = await repository.pauseRecording();

        // Assert
        expect(result, equals(const Right(null))); // Right(void) is Right(null)
        verify(mockAudioLocalDataSource.startRecording()).called(1);
        verify(
          mockAudioLocalDataSource.pauseRecording(
            recordingPath: tRecordingPath,
          ),
        ).called(1);
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return Left(RecordingFailure) when pauseRecording throws',
      () async {
        // Arrange: Simulate startRecording first
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => tRecordingPath);
        await repository.startRecording(); // Set internal state

        const tException = AudioRecordingException('Pause failed');
        when(
          mockAudioLocalDataSource.pauseRecording(
            recordingPath: tRecordingPath,
          ),
        ).thenThrow(tException);

        // Act
        final result = await repository.pauseRecording();

        // Assert
        expect(result, equals(Left(RecordingFailure(tException.message))));
        verify(mockAudioLocalDataSource.startRecording()).called(1);
        verify(
          mockAudioLocalDataSource.pauseRecording(
            recordingPath: tRecordingPath,
          ),
        ).called(1);
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return Left(RecordingFailure) if startRecording was not called first',
      () async {
        // Arrange: No call to startRecording, repository state is null

        // Act
        final result = await repository.pauseRecording();

        // Assert
        expect(
          result,
          equals(
            const Left(
              RecordingFailure('No recording path stored in repository.'),
            ),
          ),
        );
        verifyNever(
          mockAudioLocalDataSource.pauseRecording(
            recordingPath: anyNamed('recordingPath'),
          ),
        );
        verifyZeroInteractions(mockAudioLocalDataSource);
      },
    );
  });

  group('resumeRecording', () {
    const tRecordingPath = '/path/to/resume/recording.m4a';

    setUp(() {
      // Reset repository state if necessary
    });

    test(
      'should call localDataSource.resumeRecording with stored path',
      () async {
        // Arrange: Simulate startRecording first
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => tRecordingPath);
        await repository.startRecording(); // Set internal state

        when(
          mockAudioLocalDataSource.resumeRecording(
            recordingPath: tRecordingPath,
          ),
          // Ensure the mock returns a Future<void> which resolves to null
        ).thenAnswer((_) async => Future<void>.value());

        // Act
        final result = await repository.resumeRecording();

        // Assert
        expect(result, equals(const Right(null)));
        verify(mockAudioLocalDataSource.startRecording()).called(1);
        verify(
          mockAudioLocalDataSource.resumeRecording(
            recordingPath: tRecordingPath,
          ),
        ).called(1);
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return Left(RecordingFailure) when resumeRecording throws',
      () async {
        // Arrange: Simulate startRecording first
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => tRecordingPath);
        await repository.startRecording(); // Set internal state

        const tException = AudioRecordingException('Resume failed');
        when(
          mockAudioLocalDataSource.resumeRecording(
            recordingPath: tRecordingPath,
          ),
        ).thenThrow(tException);

        // Act
        final result = await repository.resumeRecording();

        // Assert
        expect(result, equals(Left(RecordingFailure(tException.message))));
        verify(mockAudioLocalDataSource.startRecording()).called(1);
        verify(
          mockAudioLocalDataSource.resumeRecording(
            recordingPath: tRecordingPath,
          ),
        ).called(1);
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return Left(RecordingFailure) if startRecording was not called first',
      () async {
        // Arrange: No call to startRecording, repository state is null

        // Act
        final result = await repository.resumeRecording();

        // Assert
        expect(
          result,
          equals(
            const Left(
              RecordingFailure('No recording path stored in repository.'),
            ),
          ),
        );
        verifyNever(
          mockAudioLocalDataSource.resumeRecording(
            recordingPath: anyNamed('recordingPath'),
          ),
        );
        verifyZeroInteractions(mockAudioLocalDataSource);
      },
    );
  });

  group('deleteRecording', () {
    const tFilePath = '/path/to/delete.m4a';

    test(
      'should call fileManager.deleteRecording AND localJobStore.deleteJob and return Right(null) on success',
      () async {
        // Arrange
        when(
          mockFileManager.deleteRecording(any),
        ).thenAnswer((_) async {}); // Ensure void
        when(
          mockLocalJobStore.deleteJob(any),
        ).thenAnswer((_) async {}); // Ensure void

        // Act
        final result = await repository.deleteRecording(tFilePath);

        // Assert
        expect(result, equals(const Right(null)));
        // Verify in order
        verifyInOrder([
          mockFileManager.deleteRecording(tFilePath),
          mockLocalJobStore.deleteJob(tFilePath),
        ]);
        verifyNoMoreInteractions(mockFileManager);
        verifyNoMoreInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockAudioLocalDataSource);
        verifyZeroInteractions(
          mockRemoteDataSource,
        ); // Ensure remote DS not involved
      },
    );

    test(
      'should NOT call localJobStore.deleteJob if fileManager.deleteRecording throws',
      () async {
        // Arrange
        const exception = AudioFileSystemException('Cannot delete file');
        when(mockFileManager.deleteRecording(any)).thenThrow(exception);

        // Act
        final result = await repository.deleteRecording(tFilePath);

        // Assert
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<FileSystemFailure>()),
          (_) => fail('Expected Left, got Right'),
        );

        // Verify file manager was called, but job store was NOT
        verify(mockFileManager.deleteRecording(tFilePath));
        verifyNever(mockLocalJobStore.deleteJob(any));

        verifyNoMoreInteractions(mockFileManager);
        verifyZeroInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockAudioLocalDataSource);
        verifyZeroInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return FileSystemFailure when fileManager throws RecordingFileNotFoundException',
      () async {
        // Arrange
        const exception = RecordingFileNotFoundException('File not found');
        when(mockFileManager.deleteRecording(any)).thenThrow(exception);
        // Act
        final result = await repository.deleteRecording(tFilePath);
        // Assert
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<FileSystemFailure>()),
          (_) => fail('Expected Left, got Right'),
        );
        verify(mockFileManager.deleteRecording(tFilePath));
        verifyNoMoreInteractions(mockFileManager);
        verifyZeroInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return FileSystemFailure when fileManager throws AudioFileSystemException',
      () async {
        // Arrange
        const exception = AudioFileSystemException('Cannot delete file');
        when(mockFileManager.deleteRecording(any)).thenThrow(exception);
        // Act
        final result = await repository.deleteRecording(tFilePath);
        // Assert
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<FileSystemFailure>()),
          (_) => fail('Expected Left, got Right'),
        );
        verify(mockFileManager.deleteRecording(tFilePath));
        verifyNoMoreInteractions(mockFileManager);
        verifyZeroInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return PlatformFailure for unexpected exceptions from fileManager',
      () async {
        // Arrange
        final exception = Exception('Unexpected error');
        when(mockFileManager.deleteRecording(any)).thenThrow(exception);
        // Act
        final result = await repository.deleteRecording(tFilePath);
        // Assert
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<PlatformFailure>()),
          (_) => fail('Expected Left, got Right'),
        );
        verify(mockFileManager.deleteRecording(tFilePath));
        verifyNoMoreInteractions(mockFileManager);
        verifyZeroInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return PlatformFailure for unexpected exceptions from localJobStore',
      () async {
        // Arrange
        final exception = Exception('Unexpected job store error');
        // Arrange file manager to succeed
        when(mockFileManager.deleteRecording(any)).thenAnswer((_) async {
          return;
        });
        // Arrange job store to fail
        when(mockLocalJobStore.deleteJob(any)).thenThrow(exception);

        // Act
        final result = await repository.deleteRecording(tFilePath);

        // Assert
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<PlatformFailure>()),
          (_) => fail('Expected Left, got Right'),
        );

        // Verify both were called
        verify(mockFileManager.deleteRecording(tFilePath)).called(1);
        verify(mockLocalJobStore.deleteJob(tFilePath)).called(1);

        verifyNoMoreInteractions(mockFileManager);
        verifyNoMoreInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockAudioLocalDataSource);
      },
    );
  });
}
