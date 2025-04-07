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
import 'package:docjet_mobile/features/audio_recorder/data/repositories/audio_recorder_repository_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_file_manager.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/transcription_remote_data_source.dart';

// Import entities needed for tests
import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/transcription_merge_service.dart';

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
  // Add ApiFailure if it needs mocking for tests, though using concrete types is often better
  MockSpec<ApiFailure>(),
])
import 'audio_recorder_repository_impl_merge_upload_test.mocks.dart'; // Adjusted mock import name

void main() {
  late AudioRecorderRepositoryImpl repository;
  late MockAudioLocalDataSource mockAudioLocalDataSource;
  late MockAudioFileManager mockFileManager;
  late MockLocalJobStore mockLocalJobStore;
  late MockTranscriptionRemoteDataSource mockRemoteDataSource;
  late MockTranscriptionMergeService mockTranscriptionMergeService;
  // late MockApiFailure mockApiFailure; // If needed

  setUp(() {
    mockAudioLocalDataSource = MockAudioLocalDataSource();
    mockFileManager = MockAudioFileManager();
    mockLocalJobStore = MockLocalJobStore();
    mockRemoteDataSource = MockTranscriptionRemoteDataSource();
    mockTranscriptionMergeService = MockTranscriptionMergeService();
    // mockApiFailure = MockApiFailure(); // If needed
    repository = AudioRecorderRepositoryImpl(
      localDataSource: mockAudioLocalDataSource,
      fileManager: mockFileManager,
      localJobStore: mockLocalJobStore,
      remoteDataSource: mockRemoteDataSource,
      transcriptionMergeService: mockTranscriptionMergeService,
    );
  });

  // --- Test Groups for Merge & Upload Logic ---

  // +++ Group for loadTranscriptions +++
  group('loadTranscriptions', () {
    // --- Test Data Helpers (Simplified - only needed as input for mocks) ---
    final tNow = DateTime.now();
    final tLocalJob1 = LocalJob(
      localFilePath: '/local/created.m4a',
      durationMillis: 10000,
      status: TranscriptionStatus.created,
      localCreatedAt: tNow.subtract(const Duration(days: 1)),
    );
    final tRemoteJob1 = Transcription(
      id: 'backend-id-synced',
      localFilePath:
          'placeholder', // Add placeholder, repository test doesn't care
      status: TranscriptionStatus.processing,
      backendCreatedAt: tNow.subtract(const Duration(hours: 11)),
      backendUpdatedAt: tNow.subtract(const Duration(minutes: 30)),
    );
    // Expected result FROM the merge service (used for mocking)
    final tMergedTranscription = Transcription(
      id: 'merged-id',
      localFilePath: '/local/merged.m4a', // Added missing field
      status: TranscriptionStatus.completed,
      localCreatedAt: tNow,
      localDurationMillis: 12345,
    );
    const tApiFailure = ApiFailure(message: 'Remote Failed');
    final tCacheFailure = CacheFailure(); // Removed invalid 'message' parameter

    // --- Test Cases Refactored ---
    test(
      'should return list from merge service when local and remote succeed',
      () async {
        // Arrange
        final remoteJobs = [tRemoteJob1];
        final localJobs = [tLocalJob1];
        final expectedMergedList = [
          tMergedTranscription,
        ]; // The list the mock service will return

        when(
          mockRemoteDataSource.getUserJobs(),
        ).thenAnswer((_) async => Right(remoteJobs));
        when(
          mockLocalJobStore.getAllLocalJobs(),
        ).thenAnswer((_) async => localJobs);
        // Mock the merge service to return the expected list
        when(
          mockTranscriptionMergeService.mergeJobs(remoteJobs, localJobs),
        ).thenReturn(expectedMergedList);

        // Act
        final result = await repository.loadTranscriptions();

        // Assert
        // Check that the repository returned the exact list from the merge service
        expect(result, equals(Right(expectedMergedList)));

        // Verify dependencies were called
        verify(mockRemoteDataSource.getUserJobs());
        verify(mockLocalJobStore.getAllLocalJobs());
        verify(mockTranscriptionMergeService.mergeJobs(remoteJobs, localJobs));
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalJobStore);
        verifyNoMoreInteractions(mockTranscriptionMergeService);
      },
    );

    test(
      'should return list from merge service when remote fails but local succeeds',
      () async {
        // Arrange
        final remoteJobs =
            <
              Transcription
            >[]; // Remote failed, so effectively empty list passed to merge
        final localJobs = [tLocalJob1];
        final expectedMergedList = [tMergedTranscription]; // Mocked result

        when(
          mockRemoteDataSource.getUserJobs(),
        ).thenAnswer((_) async => const Left(tApiFailure)); // Remote fails
        when(
          mockLocalJobStore.getAllLocalJobs(),
        ).thenAnswer((_) async => localJobs);
        // Merge service should still be called with empty remote list
        when(
          mockTranscriptionMergeService.mergeJobs(remoteJobs, localJobs),
        ).thenReturn(expectedMergedList);

        // Act
        final result = await repository.loadTranscriptions();

        // Assert
        expect(result, equals(Right(expectedMergedList)));

        // Verify dependencies were called
        verify(mockRemoteDataSource.getUserJobs());
        verify(mockLocalJobStore.getAllLocalJobs());
        verify(mockTranscriptionMergeService.mergeJobs(remoteJobs, localJobs));
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalJobStore);
        verifyNoMoreInteractions(mockTranscriptionMergeService);
      },
    );

    test(
      'should return ApiFailure when remote fails AND local store is empty',
      () async {
        // Arrange
        final localJobs = <LocalJob>[]; // Empty local store
        when(
          mockRemoteDataSource.getUserJobs(),
        ).thenAnswer((_) async => const Left(tApiFailure));
        when(
          mockLocalJobStore.getAllLocalJobs(),
        ).thenAnswer((_) async => localJobs);

        // Act
        final result = await repository.loadTranscriptions();

        // Assert
        // Expect the specific ApiFailure propagated from the remote source
        expect(result, equals(const Left(tApiFailure)));

        // Verify dependencies
        verify(mockRemoteDataSource.getUserJobs());
        verify(mockLocalJobStore.getAllLocalJobs());
        // Merge service should NOT be called in this failure case
        verifyNever(mockTranscriptionMergeService.mergeJobs(any, any));
      },
    );

    test('should return CacheFailure when local store fails', () async {
      // Arrange
      when(mockRemoteDataSource.getUserJobs()).thenAnswer(
        (_) async => const Right([]),
      ); // Remote succeeds (or doesn't matter)
      when(
        mockLocalJobStore.getAllLocalJobs(),
      ).thenThrow(tCacheFailure); // Local store throws

      // Act
      final result = await repository.loadTranscriptions();

      // Assert
      expect(result, equals(Left(tCacheFailure)));

      // Verify dependencies
      verify(mockRemoteDataSource.getUserJobs());
      verify(mockLocalJobStore.getAllLocalJobs());
      verifyNever(mockTranscriptionMergeService.mergeJobs(any, any));
    });

    // NOTE: Tests specifically about the *content* of the merged list
    // (like handling backend-only jobs, anomalous jobs, sorting) now belong
    // in the tests for TranscriptionMergeServiceImpl, not here.
    // Remove or comment out the old, detailed merge logic tests.

    /* // Example of commenting out old detailed tests
    test(
      'should return merged list including backend-only jobs when local is partial',
      () async {
         // ... OLD ARRANGE ...
         // ... OLD ACT ...
         // ... OLD ASSERT (verifying specific merged fields) ...
      }, skip: 'Logic moved to TranscriptionMergeService tests',
    );
    */
  });
  // --- End loadTranscriptions Group ---

  // +++ Group for uploadRecording (Keep as is, unrelated to merge service) +++
  group('uploadRecording', () {
    const tLocalFilePath = '/local/upload_me.m4a';
    const tUserId = 'user-123';
    final tLocalJob = LocalJob(
      localFilePath: tLocalFilePath,
      durationMillis: 15000,
      status: TranscriptionStatus.created,
      localCreatedAt: DateTime.now(),
      backendId: null,
    );
    const tTranscriptionResult = Transcription(
      id: 'new-backend-id',
      localFilePath: tLocalFilePath,
      status: TranscriptionStatus.submitted,
      localDurationMillis: 15000,
      // Other fields might be populated by the backend
    );
    const tApiFailure = ApiFailure(message: 'Upload failed', statusCode: 500);

    test(
      'should call remoteDataSource.uploadForTranscription and update localJobStore on success',
      () async {
        // Arrange
        when(
          mockLocalJobStore.getJob(tLocalFilePath),
        ).thenAnswer((_) async => tLocalJob);
        when(
          mockRemoteDataSource.uploadForTranscription(
            localFilePath: tLocalFilePath,
            userId: tUserId,
            text: null, // Assuming no text provided for this test
            additionalText: null, // Assuming no additional text
          ),
        ).thenAnswer((_) async => const Right(tTranscriptionResult));
        // *** Correction: Use saveJob instead of updateJobStatus ***
        when(
          mockLocalJobStore.saveJob(any), // Check if ANY LocalJob is saved
        ).thenAnswer((_) async => Future.value());

        // Act
        final result = await repository.uploadRecording(
          localFilePath: tLocalFilePath,
          userId: tUserId,
        );

        // Assert
        expect(result, equals(const Right(tTranscriptionResult)));
        verify(mockLocalJobStore.getJob(tLocalFilePath));
        verify(
          mockRemoteDataSource.uploadForTranscription(
            localFilePath: tLocalFilePath,
            userId: tUserId,
            text: null,
            additionalText: null,
          ),
        );
        // Verify saveJob was called with the correct details
        verify(
          mockLocalJobStore.saveJob(
            argThat(
              predicate<LocalJob>((job) {
                return job.localFilePath == tLocalFilePath &&
                    job.status == TranscriptionStatus.submitted &&
                    job.backendId == 'new-backend-id';
              }),
            ),
          ),
        ).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
        // getJob and saveJob were called
        verifyNoMoreInteractions(mockLocalJobStore);
      },
    );

    test('should return ApiFailure when remoteDataSource fails', () async {
      // Arrange
      when(
        mockLocalJobStore.getJob(tLocalFilePath),
      ).thenAnswer((_) async => tLocalJob);
      when(
        mockRemoteDataSource.uploadForTranscription(
          localFilePath: tLocalFilePath,
          userId: tUserId,
          text: null,
          additionalText: null,
        ),
      ).thenAnswer((_) async => const Left(tApiFailure));

      // Act
      final result = await repository.uploadRecording(
        localFilePath: tLocalFilePath,
        userId: tUserId,
      );

      // Assert
      expect(result, equals(const Left(tApiFailure)));
      verify(mockLocalJobStore.getJob(tLocalFilePath));
      verify(
        mockRemoteDataSource.uploadForTranscription(
          localFilePath: tLocalFilePath,
          userId: tUserId,
          text: null,
          additionalText: null,
        ),
      );
      // *** Correction: Verify saveJob was never called ***
      verifyNever(mockLocalJobStore.saveJob(any));
      verifyNoMoreInteractions(mockRemoteDataSource);
      // getJob was called
      // verifyNoMoreInteractions(mockLocalJobStore);
    });

    test(
      'should return ValidationFailure when local job is not found',
      () async {
        // Arrange
        when(mockLocalJobStore.getJob(any)).thenAnswer((_) async => null);

        // Act
        final result = await repository.uploadRecording(
          localFilePath: 'non_existent_path.m4a',
          userId: tUserId,
        );

        // Assert
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('Should have returned a Failure'),
        );
        verify(mockLocalJobStore.getJob('non_existent_path.m4a'));
        verifyZeroInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalJobStore);
      },
    );

    test(
      'should return ValidationFailure when local job status is not "created"',
      () async {
        // Arrange
        final alreadyUploadedJob = LocalJob(
          localFilePath: tLocalFilePath,
          durationMillis: 15000,
          status: TranscriptionStatus.submitted, // Status is not 'created'
          localCreatedAt: DateTime.now(),
          backendId: 'existing-id',
        );
        when(
          mockLocalJobStore.getJob(tLocalFilePath),
        ).thenAnswer((_) async => alreadyUploadedJob);

        // Act
        final result = await repository.uploadRecording(
          localFilePath: tLocalFilePath,
          userId: tUserId,
        );

        // Assert
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('Should have returned a Failure'),
        );
        verify(mockLocalJobStore.getJob(tLocalFilePath));
        verifyZeroInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalJobStore);
      },
    );

    // Test with optional text parameters
    test(
      'should call uploadForTranscription with text parameters when provided',
      () async {
        // Arrange
        const tText = 'Initial notes';
        const tAdditionalText = 'More context';
        when(
          mockLocalJobStore.getJob(tLocalFilePath),
        ).thenAnswer((_) async => tLocalJob);
        when(
          mockRemoteDataSource.uploadForTranscription(
            localFilePath: tLocalFilePath,
            userId: tUserId,
            text: tText,
            additionalText: tAdditionalText,
          ),
        ).thenAnswer((_) async => const Right(tTranscriptionResult));
        // *** Correction: Use saveJob instead of updateJobStatus ***
        when(
          mockLocalJobStore.saveJob(any), // Check if ANY LocalJob is saved
        ).thenAnswer((_) async => Future.value());

        // Act
        final result = await repository.uploadRecording(
          localFilePath: tLocalFilePath,
          userId: tUserId,
          text: tText,
          additionalText: tAdditionalText,
        );

        // Assert
        expect(result, equals(const Right(tTranscriptionResult)));
        verify(mockLocalJobStore.getJob(tLocalFilePath));
        verify(
          mockRemoteDataSource.uploadForTranscription(
            localFilePath: tLocalFilePath,
            userId: tUserId,
            text: tText,
            additionalText: tAdditionalText,
          ),
        );
        // Verify saveJob was called with the correct details
        verify(
          mockLocalJobStore.saveJob(
            argThat(
              predicate<LocalJob>((job) {
                return job.localFilePath == tLocalFilePath &&
                    job.status == TranscriptionStatus.submitted &&
                    job.backendId == 'new-backend-id';
              }),
            ),
          ),
        ).called(1);
      },
    );
  });
  // --- End uploadRecording Group ---

  // +++ Group for deleteRecording (Keep as is, unrelated) +++
  group('deleteRecording', () {
    const tLocalPathToDelete = '/local/delete_me.m4a';
    // NOTE: backendId is irrelevant for the current deleteRecording implementation
    // const tBackendIdToDelete = 'backend-id-to-delete';

    test(
      'should call fileManager.deleteRecording and localJobStore.deleteJob',
      () async {
        // Arrange
        // Getting the job first isn't strictly necessary for the delete call itself,
        // but useful to ensure we are testing a valid scenario conceptually.
        final localJob = LocalJob(
          localFilePath: tLocalPathToDelete,
          durationMillis: 5000,
          status: TranscriptionStatus.created, // Could be any status
          localCreatedAt: DateTime.now(),
          backendId: null, // Or some ID, doesn't matter for delete
        );
        when(mockLocalJobStore.getJob(tLocalPathToDelete)) // Keep for context
        .thenAnswer((_) async => localJob);
        when(mockFileManager.deleteRecording(tLocalPathToDelete)).thenAnswer(
          (_) async => const Right(true),
        ); // Simulate successful file deletion
        when(mockLocalJobStore.deleteJob(tLocalPathToDelete)).thenAnswer(
          (_) async => Future.value(),
        ); // Simulate successful job deletion

        // Act
        final result = await repository.deleteRecording(
          tLocalPathToDelete,
        ); // Correct call

        // Assert
        // Expect Right(null) because the return type is Future<Either<Failure, void>>
        expect(result, equals(const Right(null)));
        // Verify fileManager and localJobStore were called in order
        verifyInOrder([
          mockFileManager.deleteRecording(tLocalPathToDelete),
          mockLocalJobStore.deleteJob(tLocalPathToDelete),
        ]);
        verifyNoMoreInteractions(mockFileManager);
        verifyNoMoreInteractions(mockLocalJobStore);
        // Verify remote source was NOT called
        verifyZeroInteractions(mockRemoteDataSource);
        // Verify getJob was not called by deleteRecording itself
        verifyNever(mockLocalJobStore.getJob(any));
      },
    );

    test(
      'should return Failure if fileManager.deleteRecording fails',
      () async {
        // Arrange
        const tFileSystemException = AudioFileSystemException('Disk full');
        // Configure mockFileManager to throw the specific exception
        when(mockFileManager.deleteRecording(tLocalPathToDelete))
        // Use Future.error to be explicit about the async error
        .thenAnswer((_) => Future.error(tFileSystemException));
        // Do NOT stub mockLocalJobStore.deleteJob - it shouldn't be called

        // Act
        final result = await repository.deleteRecording(tLocalPathToDelete);

        // Assert
        expect(result, isA<Left<Failure, void>>());
        result.fold((failure) {
          expect(failure, isA<FileSystemFailure>());
          // Explicitly cast to FileSystemFailure to access message safely
          expect(
            (failure as FileSystemFailure).message,
            tFileSystemException.message,
          );
        }, (_) => fail('Expected Failure but got Success'));
        // Verify fileManager was called
        verify(mockFileManager.deleteRecording(tLocalPathToDelete));
        // Verify localJobStore.deleteJob was NOT called
        verifyNever(mockLocalJobStore.deleteJob(any));
        verifyNoMoreInteractions(mockFileManager);
        verifyNoMoreInteractions(mockLocalJobStore);
      },
    );

    test('should return Failure if localJobStore.deleteJob fails', () async {
      // Arrange
      final tCacheFailure = CacheFailure(); // Or another relevant failure
      // Simulate file deletion succeeding
      when(
        mockFileManager.deleteRecording(tLocalPathToDelete),
      ).thenAnswer((_) async => const Right(true));
      // Simulate job store deletion failing
      when(
        mockLocalJobStore.deleteJob(tLocalPathToDelete),
      ).thenThrow(tCacheFailure);

      // Act
      final result = await repository.deleteRecording(
        tLocalPathToDelete,
      ); // Correct call

      // Assert
      // The _tryCatch should catch the exception and turn it into a Left
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(
          failure,
          isA<CacheFailure>(),
        ), // Match the thrown failure type
        (_) => fail('Should have returned Failure'),
      );

      // Verify both fileManager and localJobStore were called
      verifyInOrder([
        mockFileManager.deleteRecording(tLocalPathToDelete),
        mockLocalJobStore.deleteJob(tLocalPathToDelete),
      ]);
      verifyNoMoreInteractions(mockFileManager);
      verifyNoMoreInteractions(mockLocalJobStore);
      verifyZeroInteractions(mockRemoteDataSource);
    });

    // Removed tests related to backendId and ValidationFailure for non-existent job,
    // as the current implementation doesn't check job existence before attempting deletion.
    // It directly calls fileManager.deleteRecording and localJobStore.deleteJob.
    // The fileManager might return Right(false) if file doesn't exist,
    // and localJobStore.deleteJob might do nothing if the key doesn't exist,
    // but the repository method itself doesn't perform pre-checks.
  });
}
