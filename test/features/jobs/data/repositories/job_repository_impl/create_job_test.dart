import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
// Import the now-existing implementation
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart'; // Import the enum
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart'; // Import SyncStatus
// CORRECTED: Import JobHiveModel
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
// Import the actual FileSystem class
import 'package:docjet_mobile/core/platform/file_system.dart';
// Import Uuid
import 'package:uuid/uuid.dart';

// Generate mocks for the dependencies
@GenerateMocks([
  JobRemoteDataSource,
  JobLocalDataSource,
  FileSystem,
  Uuid, // Add Uuid here
]) // Add FileSystem here
import 'create_job_test.mocks.dart'; // Adjusted mock file name

void main() {
  late JobRepositoryImpl repository;
  late MockJobRemoteDataSource mockRemoteDataSource;
  late MockJobLocalDataSource mockLocalDataSource;
  late MockFileSystem mockFileSystem; // Declare mock file system
  late MockUuid mockUuid; // Declare mock Uuid

  setUp(() {
    mockRemoteDataSource = MockJobRemoteDataSource();
    mockLocalDataSource = MockJobLocalDataSource();
    mockFileSystem = MockFileSystem(); // Instantiate mock file system
    mockUuid = MockUuid(); // Instantiate mock Uuid
    // Instantiate the repository
    repository = JobRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
      fileSystemService: mockFileSystem, // Provide the mock file system
      uuid: mockUuid, // Provide the mock Uuid
    );
  });

  // Sample data for testing (less relevant for createJob, but keep for consistency)
  // final tExistingJobHiveModel = JobHiveModel( // Removed unused variable
  //   localId: 'job1-local-id',
  //   serverId: 'job1-server-id', // Assume it has been synced before
  //   userId: 'user123',
  //   status: JobStatus.completed.index, // Store enum index
  //   syncStatus: SyncStatus.synced.index, // Store enum index
  //   displayTitle: 'Original Title',
  //   audioFilePath: '/path/to/test.mp3',
  //   createdAt:
  //       DateTime.parse(
  //         '2023-01-01T10:00:00Z',
  //       ).toIso8601String(), // Store as String
  //   updatedAt:
  //       DateTime.parse(
  //         '2023-01-01T11:00:00Z',
  //       ).toIso8601String(), // Store as String
  //   displayText: 'Original display text', // Use existing field
  //   text: 'Original text',
  // );

  // Map the Hive model to a Job entity for use in tests expecting Job
  // final tJob = JobMapper.fromHiveModel(tExistingJobHiveModel); // Removed unused variable

  // --- NEW GROUP for createJob ---
  group('createJob', () {
    const tAudioPath = '/path/to/new_audio.mp3';
    const tText = 'This is the transcript text.';
    const tLocalId = 'generated-uuid-123';
    // final tNow = // Removed unused variable
    //     DateTime.now(); // Use a fixed time for predictable creation/update times

    // Expected Job entity to be created and returned
    // final tNewJobEntity = Job( // Removed unused variable
    //   localId: tLocalId,
    //   serverId: null, // Server ID is null initially
    //   userId: '', // Assuming userId might be added later or defaulted
    //   status: JobStatus.created, // Initial status
    //   syncStatus: SyncStatus.pending, // Must be pending
    //   displayTitle: '', // Assuming title generation happens elsewhere or later
    //   audioFilePath: tAudioPath,
    //   text: tText,
    //   createdAt: tNow,
    //   updatedAt: tNow,
    // );

    test(
      'should generate a localId, create a pending job entity, save it locally, and return the entity',
      () async {
        // Arrange
        // 1. Stub UUID generation
        when(mockUuid.v4()).thenReturn(tLocalId);
        // 2. Stub local save to succeed
        // Match using argThat to verify the structure and key fields
        when(
          mockLocalDataSource.saveJobHiveModel(
            argThat(
              predicate<JobHiveModel>((model) {
                return model.localId == tLocalId &&
                    model.serverId == null &&
                    model.syncStatus ==
                        SyncStatus.pending.index && // Compare index for enum
                    model.audioFilePath == tAudioPath &&
                    model.text == tText;
              }),
            ),
          ),
        ).thenAnswer((_) async => true);

        // Act
        // Use the real DateTime.now() for creation time, but fix it for the expected entity
        final result = await repository.createJob(
          audioFilePath: tAudioPath,
          text: tText,
        );

        // Assert
        // 1. Check the result
        result.fold(
          (failure) => fail('Expected Right(Job), got Left: $failure'),
          (job) {
            // Compare field by field, ignoring exact DateTime instance
            expect(job.localId, tLocalId);
            expect(job.serverId, isNull);
            expect(job.syncStatus, SyncStatus.pending);
            expect(job.audioFilePath, tAudioPath);
            expect(job.text, tText);
            expect(job.status, JobStatus.created); // Check initial status
            // We don't compare createdAt/updatedAt directly due to milliseconds variance
          },
        );
        // 2. Verify UUID generation was called
        verify(mockUuid.v4()).called(1);
        // 3. Verify local save was called with the correct model structure
        verify(
          mockLocalDataSource.saveJobHiveModel(
            argThat(
              predicate<JobHiveModel>((model) {
                return model.localId == tLocalId &&
                    model.serverId == null &&
                    model.syncStatus == SyncStatus.pending.index;
              }),
            ),
          ),
        ).called(1);
        // 4. Verify no other significant interactions
        verifyNoMoreInteractions(mockUuid);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockFileSystem);
      },
    );

    test(
      'should return CacheFailure when local data source fails to save',
      () async {
        // Arrange
        // 1. Stub UUID generation
        when(mockUuid.v4()).thenReturn(tLocalId);
        // 2. Stub local save to throw CacheException
        when(
          mockLocalDataSource.saveJobHiveModel(any),
        ).thenThrow(CacheException('Failed to write to Hive'));

        // Act
        final result = await repository.createJob(
          audioFilePath: tAudioPath,
          text: tText,
        );

        // Assert
        // 1. Check the result is Left(CacheFailure)
        expect(result, isA<Left<Failure, Job>>());
        result.fold(
          (failure) => expect(failure, isA<CacheFailure>()),
          (_) => fail('Expected Left(CacheFailure), got Right'),
        );
        // 2. Verify UUID generation was called
        verify(mockUuid.v4()).called(1);
        // 3. Verify local save attempt was made
        verify(mockLocalDataSource.saveJobHiveModel(any)).called(1);
        // 4. Verify no other significant interactions
        verifyNoMoreInteractions(mockUuid);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockFileSystem);
      },
    );
  }); // End of createJob group
} // End of main
