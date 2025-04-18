import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart';
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
import 'get_jobs_test.mocks.dart'; // Adjusted mock file name

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

  // Sample data for testing
  // Use the same JobHiveModel for consistency in tests needing it
  final tExistingJobHiveModel = JobHiveModel(
    localId: 'job1-local-id',
    serverId: 'job1-server-id', // Assume it has been synced before
    userId: 'user123',
    status: JobStatus.completed.index, // Store enum index
    syncStatus: SyncStatus.synced.index, // Store enum index
    displayTitle: 'Original Title',
    audioFilePath: '/path/to/test.mp3',
    createdAt:
        DateTime.parse(
          '2023-01-01T10:00:00Z',
        ).toIso8601String(), // Store as String
    updatedAt:
        DateTime.parse(
          '2023-01-01T11:00:00Z',
        ).toIso8601String(), // Store as String
    displayText: 'Original display text', // Use existing field
    text: 'Original text',
  );

  // Map the Hive model to a Job entity for use in tests expecting Job
  final tJob = JobMapper.fromHiveModel(tExistingJobHiveModel);
  final tJobs = [tJob];

  group('getJobs', () {
    test(
      'should fetch jobs from remote source, map them (statically), save locally, and return entities',
      () async {
        // Arrange
        // *** ADDED: Simulate cache miss ***
        when(
          mockLocalDataSource.getAllJobHiveModels(),
        ).thenAnswer((_) async => []);
        // *** ADDED: Stub getLastFetchTime for initial cache check ***
        when(
          mockLocalDataSource.getLastFetchTime(),
        ).thenAnswer((_) async => null); // Assume no previous fetch
        // 1. Stub remote fetch
        when(
          mockRemoteDataSource.fetchJobs(),
        ).thenAnswer((_) async => tJobs); // Remote returns List<Job>
        // *** ADDED: Stub getSyncedJobHiveModels for deletion check (return empty for this case) ***
        when(
          mockLocalDataSource.getSyncedJobHiveModels(),
        ).thenAnswer((_) async => []); // No synced jobs to delete
        // 2. Stub mapping - REMOVED (uses static mapper)
        // when(mockMapper.toHiveModelList(tJobs)).thenReturn(tJobHiveModels);
        // 3. Stub local save (accepts Hive Models) - Use the statically generated tJobHiveModels
        when(mockLocalDataSource.saveJobHiveModels(any)).thenAnswer(
          (_) async => true,
        ); // More flexible matching of JobHiveModel
        // *** ADDED: Stub saveLastFetchTime ***
        when(
          mockLocalDataSource.saveLastFetchTime(any),
        ).thenAnswer((_) async => Future.value());

        // Act
        final result = await repository.getJobs(); // Call the repository method

        // Assert
        // 1. Check the result by folding and comparing the success value (List<Job>)
        result.fold(
          (failure) => fail('Expected Right, got Left: $failure'),
          (jobs) => expect(jobs, equals(tJobs)), // Compare lists directly
        );
        // 2. Verify remote fetch was called
        verify(mockRemoteDataSource.fetchJobs()).called(1);
        // 3. Verify local save was called with the mapped Hive models
        // Use `any` matcher because the list/model instances created by the mapper
        // won't be identical to tJobHiveModels instance.
        verify(mockLocalDataSource.saveJobHiveModels(any)).called(1);
        // 4. Verify local get WAS called
        verify(mockLocalDataSource.getAllJobHiveModels()).called(1);
        // 5. Verify saveLastFetchTime was called
        verify(mockLocalDataSource.saveLastFetchTime(any)).called(1);
        // 6. Verify no other interactions occurred with the mocks (mapper interaction removed)
        verifyNoMoreInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return ServerFailure when remote source throws ServerException',
      () async {
        // Arrange
        // 1. Stub local fetch to return empty (cache miss)
        when(
          mockLocalDataSource.getAllJobHiveModels(),
        ).thenAnswer((_) async => []);
        // *** ADDED: Stub getLastFetchTime for cache check ***
        when(
          mockLocalDataSource.getLastFetchTime(),
        ).thenAnswer((_) async => null);
        // 2. Stub remote fetch to throw ServerException
        when(
          mockRemoteDataSource.fetchJobs(),
        ).thenThrow(ServerException('API Error'));

        // Act
        final result = await repository.getJobs();

        // Assert
        // 1. Check the result (should be Left(ServerFailure))
        expect(result, isA<Left<Failure, List<Job>>>());
        result.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (success) => fail('Expected Failure, got Success'),
        );
        // 2. Verify remote fetch was called
        verify(mockRemoteDataSource.fetchJobs()).called(1);
        // 4. Verify local save was NOT called
        verifyNever(mockLocalDataSource.saveJobHiveModels(any));
        // 5. Verify no other interactions occurred
        verifyNoMoreInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return ServerFailure with details when remote source throws ApiException',
      () async {
        // Arrange
        // *** ADDED: Simulate cache miss ***
        when(
          mockLocalDataSource.getAllJobHiveModels(),
        ).thenAnswer((_) async => []);
        // *** ADDED: Stub getLastFetchTime for cache check ***
        when(
          mockLocalDataSource.getLastFetchTime(),
        ).thenAnswer((_) async => null);
        final tApiException = ApiException(
          message: 'Not Found',
          statusCode: 404,
        );
        when(mockRemoteDataSource.fetchJobs()).thenThrow(tApiException);

        // Act
        final result = await repository.getJobs();

        // Assert
        expect(result, isA<Left<Failure, List<Job>>>());
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
          // Check that the failure carries the details from the exception
          // Cast failure to ServerFailure to access specific properties
          final serverFailure = failure as ServerFailure;
          expect(serverFailure.message, tApiException.message);
          expect(serverFailure.statusCode, tApiException.statusCode);
        }, (success) => fail('Expected Failure, got Success'));
        verify(mockRemoteDataSource.fetchJobs()).called(1);
        verifyNever(mockLocalDataSource.saveJobHiveModels(any));
        verifyNoMoreInteractions(mockRemoteDataSource);
      },
    );

    test('should return locally cached jobs when cache is not empty', () async {
      // Arrange
      // 1. Stub local fetch to return some cached data (Create a model for this case)
      final cachedHiveModel = JobHiveModel(
        localId: 'cached-job-local',
        serverId: 'cached-job-server',
        userId: 'user456',
        status: JobStatus.transcribing.index,
        syncStatus: SyncStatus.synced.index,
        displayTitle: 'Cached Job',
        createdAt:
            DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        updatedAt:
            DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      );
      final cachedJob = JobMapper.fromHiveModel(cachedHiveModel);

      when(mockLocalDataSource.getAllJobHiveModels()).thenAnswer(
        (_) async => [cachedHiveModel], // Return the specific model instance
      );
      when(
        mockLocalDataSource.getLastFetchTime(),
      ).thenAnswer((_) async => DateTime.now());

      // Act
      final result = await repository.getJobs();

      // Assert
      // 1. Check the result using dartz Either equality (which respects Equatable)
      result.fold(
        (failure) => fail('Expected Right (cached jobs), got Left: $failure'),
        (jobs) => expect(jobs, [cachedJob]), // Compare with the mapped entity
      );
      // 2. Verify local get WAS called
      verify(mockLocalDataSource.getAllJobHiveModels()).called(1);
      // 3. Verify getLastFetchTime was called
      verify(mockLocalDataSource.getLastFetchTime()).called(1);
      // 4. Verify remote fetch was NOT called
      verifyNever(mockRemoteDataSource.fetchJobs());
      // 5. Verify local save was NOT called
      verifyNever(mockLocalDataSource.saveJobHiveModels(any));
      // 6. Verify no other interactions occurred
      verifyNoMoreInteractions(mockRemoteDataSource);
    });

    test(
      'should fetch from remote when local cache read throws CacheException',
      () async {
        // Arrange
        // 1. Stub local get to throw CacheException
        when(
          mockLocalDataSource.getAllJobHiveModels(),
        ).thenThrow(CacheException('Hive died'));
        // No need to stub getLastFetchTime here as the first read fails
        // 2. Stub remote fetch to succeed
        when(mockRemoteDataSource.fetchJobs()).thenAnswer((_) async => tJobs);
        // *** ADDED: Stub getSyncedJobHiveModels for deletion check (return empty) ***
        when(
          mockLocalDataSource.getSyncedJobHiveModels(),
        ).thenAnswer((_) async => []);
        // 3. Stub local save to succeed
        when(
          mockLocalDataSource.saveJobHiveModels(any),
        ).thenAnswer((_) async => true); // Return true for successful save

        // Act
        final result = await repository.getJobs();

        // Assert
        // 1. Check the result is success (Right(tJobs))
        result.fold(
          (failure) => fail('Expected Right (remote data), got Left: $failure'),
          (jobs) => expect(jobs, tJobs),
        );
        // 2. Verify local get was called
        verify(mockLocalDataSource.getAllJobHiveModels()).called(1);
        // 3. Verify remote fetch was called
        verify(mockRemoteDataSource.fetchJobs()).called(1);
        // 4. Verify local save was called
        verify(mockLocalDataSource.saveJobHiveModels(any)).called(1);
        // *** ADDED: Verify getSyncedJobHiveModels was called for deletion check ***
        verify(mockLocalDataSource.getSyncedJobHiveModels()).called(1);
        // 5. Verify saveLastFetchTime was called
        verify(mockLocalDataSource.saveLastFetchTime(any)).called(1);
        // 6. Verify no other interactions occurred
        verifyNoMoreInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return remote data successfully even if local cache save fails',
      () async {
        // Arrange
        // Cache miss scenario
        when(
          mockLocalDataSource.getAllJobHiveModels(),
        ).thenAnswer((_) async => []);
        when(
          mockLocalDataSource.getLastFetchTime(),
        ).thenAnswer((_) async => null);
        // Remote fetch succeeds
        when(mockRemoteDataSource.fetchJobs()).thenAnswer((_) async => tJobs);
        // *** ADDED: Stub getSyncedJobHiveModels for deletion check (return empty) ***
        when(
          mockLocalDataSource.getSyncedJobHiveModels(),
        ).thenAnswer((_) async => []);
        // Local save fails
        when(
          mockLocalDataSource.saveJobHiveModels(any),
        ).thenThrow(CacheException('Disk full'));
        // *** MODIFIED: Stub saveLastFetchTime to SUCCEED (repo logic changed) ***
        when(mockLocalDataSource.saveLastFetchTime(any)).thenAnswer(
          (_) async => Future.value(),
        ); // Should succeed even if saveJobHiveModels fails

        // Act
        final result = await repository.getJobs();

        // Assert
        // 1. Check the result is success (Right(tJobs)) despite cache save error
        result.fold(
          (failure) => fail('Expected Right (remote data), got Left: $failure'),
          (jobs) => expect(jobs, tJobs),
        );
        // 2. Verify local get was called
        verify(mockLocalDataSource.getAllJobHiveModels()).called(1);
        // 3. Verify remote fetch was called
        verify(mockRemoteDataSource.fetchJobs()).called(1);
        // 4. Verify local save was called (even though it threw)
        verify(mockLocalDataSource.saveJobHiveModels(any)).called(1);
        // 5. Verify saveLastFetchTime was called (even though saveJobHiveModels failed)
        verify(mockLocalDataSource.saveLastFetchTime(any)).called(1);
        // 6. Verify no other interactions occurred
        verifyNoMoreInteractions(mockRemoteDataSource);
      },
    );

    test('should fetch from remote when local cache is stale', () async {
      // Arrange
      final staleTime = DateTime.now().subtract(const Duration(hours: 2));
      // 1. Stub local get to return non-empty list - Use the CORRECT type!
      final tExistingHiveModels = JobMapper.toHiveModelList(
        tJobs,
      ); // Map Job list to Hive list
      when(mockLocalDataSource.getAllJobHiveModels()).thenAnswer(
        (_) async => tExistingHiveModels,
      ); // Return List<JobHiveModel>
      // 2. Stub getLastFetchTime to return a stale time
      when(
        mockLocalDataSource.getLastFetchTime(),
      ).thenAnswer((_) async => staleTime);
      // 3. Stub remote fetch to succeed (return same jobs for simplicity)
      when(mockRemoteDataSource.fetchJobs()).thenAnswer((_) async => tJobs);
      // *** ADDED: Stub getSyncedJobHiveModels for deletion check (return empty) ***
      when(
        mockLocalDataSource.getSyncedJobHiveModels(),
      ).thenAnswer((_) async => []);
      // 4. Stub local save to succeed
      when(
        mockLocalDataSource.saveJobHiveModels(any),
      ).thenAnswer((_) async => true);
      // 5. Stub saveLastFetchTime to succeed
      when(
        mockLocalDataSource.saveLastFetchTime(any),
      ).thenAnswer((_) async => Future.value());

      // Act
      final result = await repository.getJobs();

      // Assert
      // 1. Check result is success (Right(tJobs) from remote)
      result.fold(
        (failure) => fail('Expected Right (remote data), got Left: $failure'),
        (jobs) => expect(jobs, tJobs),
      );
      // 2. Verify local get was called
      verify(mockLocalDataSource.getAllJobHiveModels()).called(1);
      // 3. Verify getLastFetchTime was called
      verify(mockLocalDataSource.getLastFetchTime()).called(1);
      // 4. Verify remote fetch was called
      verify(mockRemoteDataSource.fetchJobs()).called(1);
      // 5. Verify local save was called
      verify(mockLocalDataSource.saveJobHiveModels(any)).called(1);
      // 6. Verify saveLastFetchTime was called
      verify(mockLocalDataSource.saveLastFetchTime(any)).called(1);
      // 7. Verify no other interactions occurred
      verifyNoMoreInteractions(mockRemoteDataSource);
    });

    // --- Tests for Server-Side Deletion Detection --- START

    test(
      'getJobs should delete locally synced jobs not present on server and their files',
      () async {
        // Arrange
        final tLocalJobToDeleteHive = JobHiveModel(
          localId: 'local-to-delete-id',
          serverId: 'server-deleted-id',
          userId: 'user1',
          status: JobStatus.completed.index,
          syncStatus: SyncStatus.synced.index, // Must be synced
          audioFilePath: '/path/to/deleted.mp3',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );

        final tLocalJobToKeepHive = JobHiveModel(
          localId: 'local-to-keep-id',
          serverId: 'server-keep-id',
          userId: 'user1',
          status: JobStatus.completed.index,
          syncStatus: SyncStatus.synced.index, // Must be synced
          audioFilePath: '/path/to/keep.mp3',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );

        // Server only returns the job to keep
        final tServerJobToKeepEntity = Job(
          localId: 'server-provided-local-id-for-keep', // Mapper handles this
          serverId: 'server-keep-id', // Match the one to keep
          userId: 'user1',
          status: JobStatus.completed,
          syncStatus: SyncStatus.synced,
          displayTitle: 'Updated Title from Server', // Server data might differ
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(
          mockLocalDataSource.getAllJobHiveModels(),
        ).thenAnswer((_) async => [tLocalJobToDeleteHive, tLocalJobToKeepHive]);
        when(mockLocalDataSource.getLastFetchTime()).thenAnswer(
          (_) async =>
              DateTime.now().subtract(const Duration(days: 1)), // Force refresh
        );
        when(mockRemoteDataSource.fetchJobs()).thenAnswer(
          (_) async => [tServerJobToKeepEntity], // Only return the one to keep
        );
        when(mockLocalDataSource.getSyncedJobHiveModels()).thenAnswer(
          (_) async => [tLocalJobToDeleteHive, tLocalJobToKeepHive],
        ); // Return both initially for comparison
        when(
          mockLocalDataSource.deleteJobHiveModel(tLocalJobToDeleteHive.localId),
        ).thenAnswer((_) async => true);
        when(
          mockFileSystem.deleteFile(tLocalJobToDeleteHive.audioFilePath!),
        ).thenAnswer((_) async => true);
        when(
          mockLocalDataSource.saveJobHiveModels(any),
        ).thenAnswer((_) async => true);
        when(
          mockLocalDataSource.saveLastFetchTime(any),
        ).thenAnswer((_) async => Future.value());

        // Act
        final result = await repository.getJobs();

        // Assert
        result.fold(
          (failure) => fail('Expected Success, got $failure'),
          (jobs) => expect(jobs, [
            tServerJobToKeepEntity,
          ]), // Should return server list
        );

        verify(mockLocalDataSource.getLastFetchTime()).called(1);
        verify(mockRemoteDataSource.fetchJobs()).called(1);
        verify(mockLocalDataSource.getSyncedJobHiveModels()).called(1);
        // Verify deletion was called for the correct job
        verify(
          mockLocalDataSource.deleteJobHiveModel('local-to-delete-id'),
        ).called(1);
        // Verify file deletion was called for the correct file
        verify(mockFileSystem.deleteFile('/path/to/deleted.mp3')).called(1);
        // Verify save was called ONLY with the job from the server
        verify(
          mockLocalDataSource.saveJobHiveModels(
            any,
          ), // Capture arg later if needed
        ).called(1);
        verify(mockLocalDataSource.saveLastFetchTime(any)).called(1);

        // Verify these were NOT called for the kept job
        verifyNever(
          mockLocalDataSource.deleteJobHiveModel(tLocalJobToKeepHive.localId),
        );
        verifyNever(
          mockFileSystem.deleteFile(tLocalJobToKeepHive.audioFilePath!),
        );

        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockFileSystem);
      },
    );

    test(
      'getJobs should ignore pending jobs during server-side deletion check',
      () async {
        // Arrange
        final tLocalPendingJobHive = JobHiveModel(
          localId: 'local-pending-id',
          serverId: null, // Not synced yet
          userId: 'user1',
          status: JobStatus.created.index,
          syncStatus: SyncStatus.pending.index, // Must be pending
          audioFilePath: '/path/to/pending.mp3',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );

        final tLocalSyncedJobHive = JobHiveModel(
          localId: 'local-synced-id',
          serverId: 'server-synced-id',
          userId: 'user1',
          status: JobStatus.completed.index,
          syncStatus: SyncStatus.synced.index, // Must be synced
          audioFilePath: '/path/to/synced.mp3',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );

        // Server only returns the synced job
        final tServerSyncedJobEntity = Job(
          localId: 'ignore-local-id', // Server doesn't know localId
          serverId: 'server-synced-id',
          userId: 'user1',
          status: JobStatus.completed,
          syncStatus: SyncStatus.synced,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(
          mockLocalDataSource.getAllJobHiveModels(),
        ).thenAnswer((_) async => [tLocalPendingJobHive, tLocalSyncedJobHive]);
        when(mockLocalDataSource.getLastFetchTime()).thenAnswer(
          (_) async =>
              DateTime.now().subtract(const Duration(days: 1)), // Force refresh
        );
        when(mockRemoteDataSource.fetchJobs()).thenAnswer(
          (_) async => [tServerSyncedJobEntity], // Server knows only synced one
        );
        // CRITICAL: getSyncedJobHiveModels should ONLY return the synced one
        when(
          mockLocalDataSource.getSyncedJobHiveModels(),
        ).thenAnswer((_) async => [tLocalSyncedJobHive]);
        when(
          mockLocalDataSource.saveJobHiveModels(any),
        ).thenAnswer((_) async => true);
        when(
          mockLocalDataSource.saveLastFetchTime(any),
        ).thenAnswer((_) async => Future.value());

        // Act
        final result = await repository.getJobs();

        // Assert
        result.fold(
          (failure) => fail('Expected Success, got $failure'),
          (jobs) => expect(jobs, [
            tServerSyncedJobEntity,
          ]), // Should return server list
        );

        // FIXED: Verify the initial getAllJobHiveModels call
        verify(mockLocalDataSource.getAllJobHiveModels()).called(1);
        verify(mockLocalDataSource.getLastFetchTime()).called(1);
        verify(mockRemoteDataSource.fetchJobs()).called(1);
        verify(mockLocalDataSource.getSyncedJobHiveModels()).called(1);
        verify(mockLocalDataSource.saveJobHiveModels(any)).called(1);
        verify(mockLocalDataSource.saveLastFetchTime(any)).called(1);

        // Verify deletion was NEVER called for the pending job
        verifyNever(mockLocalDataSource.deleteJobHiveModel(any));
        verifyNever(mockFileSystem.deleteFile(any));

        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockFileSystem);
      },
    );

    test(
      'getJobs should proceed with sync even if file deletion fails during server-side check',
      () async {
        // Arrange: Similar setup to the deletion test, but mock file deletion to throw
        final tLocalJobToDeleteHive = JobHiveModel(
          localId: 'local-to-delete-id',
          serverId: 'server-deleted-id',
          userId: 'user1',
          status: JobStatus.completed.index,
          syncStatus: SyncStatus.synced.index,
          audioFilePath: '/path/to/deleted-error.mp3', // Specific path
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );

        // Server returns nothing (as the job was deleted there)
        final List<Job> tServerJobs = [];

        when(mockLocalDataSource.getAllJobHiveModels()).thenAnswer(
          (_) async => [tLocalJobToDeleteHive], // Only the one to be deleted
        );
        when(mockLocalDataSource.getLastFetchTime()).thenAnswer(
          (_) async =>
              DateTime.now().subtract(const Duration(days: 1)), // Force refresh
        );
        when(
          mockRemoteDataSource.fetchJobs(),
        ).thenAnswer((_) async => tServerJobs);
        when(
          mockLocalDataSource.getSyncedJobHiveModels(),
        ).thenAnswer((_) async => [tLocalJobToDeleteHive]);
        when(
          mockLocalDataSource.deleteJobHiveModel(tLocalJobToDeleteHive.localId),
        ).thenAnswer((_) async => true); // DB deletion succeeds
        // CRITICAL: File deletion fails
        when(
          mockFileSystem.deleteFile('/path/to/deleted-error.mp3'),
        ).thenThrow(Exception('Disk full or something'));
        when(
          mockLocalDataSource.saveJobHiveModels(
            any,
          ), // Save empty list or whatever the repo does now
        ).thenAnswer((_) async => true);
        when(
          mockLocalDataSource.saveLastFetchTime(any),
        ).thenAnswer((_) async => Future.value());

        // Act
        final result = await repository.getJobs();

        // Assert
        // Should still succeed, returning the (empty) server list
        result.fold(
          (failure) =>
              fail('Expected Success despite file error, got $failure'),
          (jobs) => expect(jobs, tServerJobs),
        );

        verify(mockLocalDataSource.getLastFetchTime()).called(1);
        verify(mockRemoteDataSource.fetchJobs()).called(1);
        verify(mockLocalDataSource.getSyncedJobHiveModels()).called(1);
        // Verify DB deletion WAS called
        verify(
          mockLocalDataSource.deleteJobHiveModel('local-to-delete-id'),
        ).called(1);
        // Verify file deletion WAS called (even though it failed)
        verify(
          mockFileSystem.deleteFile('/path/to/deleted-error.mp3'),
        ).called(1);
        // Verify save WAS called with the (empty) server list
        verify(mockLocalDataSource.saveJobHiveModels(any)).called(1);
        verify(mockLocalDataSource.saveLastFetchTime(any)).called(1);

        // *** ADDED: Verify initial cache check was called ***
        verify(mockLocalDataSource.getAllJobHiveModels()).called(1);

        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockFileSystem);
      },
    );

    // --- Tests for Server-Side Deletion Detection --- END

    // Test for fetching from remote when cache is stale (This was duplicated, already included above)
    // test(
    //   'should fetch from remote when local cache is considered stale',
    //   () async { ... }
    // );

    // TODO: Add test case for handling known network unavailability (offline first behavior)
    // TODO: Add test case for returning stale data as fallback when remote fetch fails
    // TODO: Add test cases for network/API failure scenarios
    // TODO: Add test case for server-side deletion detection (This comment seems redundant as tests exist)
  }); // End of getJobs group
} // End of main
