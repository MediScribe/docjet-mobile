import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
// import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart'; // Unused
// import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart'; // Unused
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_api_dto.dart'; // Add import for JobApiDTO
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';

// Generate mocks for the dependencies including JobDeleterService and NetworkInfo
@GenerateMocks([
  JobLocalDataSource,
  JobRemoteDataSource,
  JobDeleterService,
  NetworkInfo,
])
import 'job_reader_service_test.mocks.dart';

void main() {
  late JobReaderService service;
  late MockJobLocalDataSource mockLocalDataSource;
  late MockJobRemoteDataSource mockRemoteDataSource;
  late MockJobDeleterService mockDeleterService;
  late MockNetworkInfo mockNetworkInfo;

  setUp(() {
    mockLocalDataSource = MockJobLocalDataSource();
    mockRemoteDataSource = MockJobRemoteDataSource();
    mockDeleterService = MockJobDeleterService();
    mockNetworkInfo = MockNetworkInfo();
    service = JobReaderService(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
      deleterService: mockDeleterService,
      networkInfo: mockNetworkInfo,
    );

    // Default stub for network info (online) - tests can override this
    when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
    // Default stub for saveJob (success) - tests can override if failure needed
    when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async => unit);
    // Default stub for deleteJob (success) - tests can override if failure needed
    when(
      mockDeleterService.permanentlyDeleteJob(any),
    ).thenAnswer((_) async => const Right(unit));
    // Default stub for getJobsByStatus (empty list) - tests should override
    when(mockLocalDataSource.getJobsByStatus(any)).thenAnswer((_) async => []);
    // Default stub for getJobs (empty list) - tests should override
    when(mockLocalDataSource.getJobs()).thenAnswer((_) async => []);
  });

  // --- Test Data Setup ---
  final tJobSynced = Job(
    localId: 'synced-local-id',
    serverId: 'synced-server-id',
    userId: 'test-user-id',
    status: JobStatus.completed,
    syncStatus: SyncStatus.synced, // Crucial
    displayTitle: 'Synced Job Title',
    audioFilePath: '/path/to/synced.mp3',
    createdAt: DateTime(2023, 1, 1, 10, 0, 0),
    updatedAt: DateTime(2023, 1, 1, 11, 0, 0),
    displayText: 'Synced display text',
    text: 'Synced text',
  );
  final tJobPending = Job(
    localId: 'pending-local-id',
    serverId: null,
    userId: 'test-user-id',
    status: JobStatus.created,
    syncStatus: SyncStatus.pending, // Crucial
    displayTitle: 'Pending Job Title',
    audioFilePath: '/path/to/pending.mp3',
    createdAt: DateTime(2023, 1, 2, 10, 0, 0),
    updatedAt: DateTime(2023, 1, 2, 11, 0, 0),
    displayText: 'Pending display text',
    text: 'Pending text',
  );
  final tJobsListSyncedOnly = [tJobSynced];
  final tJobsListPendingOnly = [tJobPending];
  final tJobsListAll = [tJobSynced, tJobPending]; // Entities

  // Create DTOs matching the Jobs
  final tJobSyncedDto = JobApiDTO(
    id: 'synced-server-id',
    userId: 'test-user-id',
    jobStatus: 'completed',
    createdAt: DateTime(2023, 1, 1, 10, 0, 0),
    updatedAt: DateTime(2023, 1, 1, 11, 0, 0),
    displayTitle: 'Synced Job Title',
    displayText: 'Synced display text',
    text: 'Synced text',
  );

  final tJobPendingDto = JobApiDTO(
    id: 'pending-server-id', // Note: for remote DTOs, even pending jobs would have IDs
    userId: 'test-user-id',
    jobStatus: 'created',
    createdAt: DateTime(2023, 1, 2, 10, 0, 0),
    updatedAt: DateTime(2023, 1, 2, 11, 0, 0),
    displayTitle: 'Pending Job Title',
    displayText: 'Pending display text',
    text: 'Pending text',
  );

  final tJobsDtoListSyncedOnly = [tJobSyncedDto];
  final tJobsDtoListPendingOnly = [tJobPendingDto];

  // Helper function for verifying no more interactions
  void verifyNoMoreInteractionsAll() {
    verifyNoMoreInteractions(mockLocalDataSource);
    verifyNoMoreInteractions(mockRemoteDataSource);
    verifyNoMoreInteractions(mockDeleterService);
    verifyNoMoreInteractions(mockNetworkInfo);
  }

  // Helper function for verifying zero interactions on remoteDataSource, deleterService, and networkInfo
  void verifyZeroInteractionsAll() {
    verifyZeroInteractions(mockRemoteDataSource);
    verifyZeroInteractions(mockDeleterService);
    verifyZeroInteractions(mockNetworkInfo);
  }
  // --- End Test Data Setup ---

  group('JobReaderService', () {
    group('getJobs', () {
      test('should return local jobs immediately if offline', () async {
        // Arrange
        when(
          mockNetworkInfo.isConnected,
        ).thenAnswer((_) async => false); // OFFLINE
        // Stub the entity-based method
        when(mockLocalDataSource.getJobs()).thenAnswer(
          (_) async => tJobsListAll, // Return local data
        );
        // Act
        final result = await service.getJobs();
        // Assert
        expect(result, isA<Right<Failure, List<Job>>>());
        expect(result.getOrElse(() => []), tJobsListAll); // Expect local data
        verify(mockNetworkInfo.isConnected).called(1);
        // Verify the correct entity-based method was called
        verify(mockLocalDataSource.getJobs()).called(1);
        // Crucially, no remote or delete calls when offline
        verifyZeroInteractions(mockRemoteDataSource);
        verifyZeroInteractions(mockDeleterService);
        // Should not attempt to save jobs when offline
        verifyNever(mockLocalDataSource.saveJob(any));
        verifyNoMoreInteractions(mockLocalDataSource); // Only getJobs
        verifyNoMoreInteractions(mockNetworkInfo); // Only isConnected
      });

      test(
        'should return mapped jobs, save them locally, and not delete when online and local synced is empty',
        () async {
          // Arrange
          when(
            mockNetworkInfo.isConnected,
          ).thenAnswer((_) async => true); // ONLINE
          // Stub getJobsByStatus to return empty for synced jobs
          when(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).thenAnswer(
            (_) async => [], // Local synced is empty
          );
          when(mockRemoteDataSource.fetchJobs()).thenAnswer(
            (_) async =>
                tJobsDtoListSyncedOnly, // Remote returns one synced DTO
          );

          // Act
          final result = await service.getJobs();

          // Assert
          expect(result, isA<Right<Failure, List<Job>>>());
          // We expect jobs that match our test Jobs, but the localIds might be different
          // since they were generated in the mapper. So we just check the serverId.
          final resultJobs = result.getOrElse(() => []);
          expect(resultJobs.length, 1);
          expect(resultJobs[0].serverId, tJobSynced.serverId);

          verify(mockNetworkInfo.isConnected).called(1);
          // Verify getJobsByStatus was checked for synced jobs
          verify(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).called(1);
          verify(mockRemoteDataSource.fetchJobs()).called(1); // Fetched remote
          // Verify saveJob was called - note that the exact Job object can't be verified
          // since it may have a generated localId
          verify(mockLocalDataSource.saveJob(any)).called(1);
          verifyZeroInteractions(mockDeleterService); // No deletions expected
          verifyNoMoreInteractionsAll();
        },
      );

      test(
        'should detect server deletions, trigger local deletion, and return mapped jobs when online',
        () async {
          // Arrange
          when(
            mockNetworkInfo.isConnected,
          ).thenAnswer((_) async => true); // ONLINE
          // 1. Remote source returns ONLY the pending job DTO (synced one was deleted on server)
          when(
            mockRemoteDataSource.fetchJobs(),
          ).thenAnswer((_) async => tJobsDtoListPendingOnly);
          // 2. Local source returns the synced job when asked for synced jobs
          when(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).thenAnswer(
            (_) async => tJobsListSyncedOnly, // Contains the job to be deleted
          );

          // Act
          final result = await service.getJobs();

          // Assert
          // 1. We expect jobs that match our test Jobs for pending, but the localIds might be different
          // since they were generated in the mapper. So we just check length and serverId.
          final resultJobs = result.getOrElse(() => []);
          expect(resultJobs.length, 1);
          expect(resultJobs[0].serverId, tJobPendingDto.id);

          // 2. Verify interactions
          verify(mockNetworkInfo.isConnected).called(1);
          // Verify getJobsByStatus was checked for synced jobs
          verify(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).called(1);
          verify(mockRemoteDataSource.fetchJobs()).called(1); // Fetch remote
          // 3. Verify saveJob was called - can't verify exact Job
          verify(mockLocalDataSource.saveJob(any)).called(1);
          // 4. Crucially, verify the deleter service was called for the synced job
          verify(
            mockDeleterService.permanentlyDeleteJob(tJobSynced.localId),
          ).called(1);
          verifyNoMoreInteractionsAll();
        },
      );

      test(
        'should return CacheFailure when the call to local getJobsByStatus fails',
        () async {
          // Arrange
          when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
          // Mock the local data source method to throw
          when(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).thenThrow(CacheException('Failed to fetch jobs'));

          // Act
          final result = await service.getJobs();

          // Assert
          expect(result, const Left(CacheFailure('Failed to fetch jobs')));
          verify(mockNetworkInfo.isConnected).called(1);
          // Verify the failing method was called
          verify(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).called(1);
          verifyZeroInteractions(
            mockRemoteDataSource,
          ); // Should not be called if local fails
          verifyZeroInteractions(mockDeleterService);
          // saveJob should not be called if initial check fails
          verifyNever(mockLocalDataSource.saveJob(any));
          verifyNoMoreInteractionsAll();
        },
      );

      test(
        'should return ServerFailure when the call to remote data source fails (after checking local)',
        () async {
          // Arrange
          when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
          // Mock local source to return empty for synced jobs
          when(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).thenAnswer((_) async => []);
          // Mock remote source to throw an exception
          when(
            mockRemoteDataSource.fetchJobs(),
          ).thenThrow(ApiException(message: 'API Error', statusCode: 500));

          // Act
          final result = await service.getJobs();

          // Assert & Verify
          // Verify the local check happened *before* asserting the final result
          verify(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).called(1);
          // Assert the expected failure
          expect(
            result,
            const Left(ServerFailure(message: 'API Error', statusCode: 500)),
          );
          // Verify other interactions
          verify(mockNetworkInfo.isConnected).called(1);
          verify(
            mockRemoteDataSource.fetchJobs(),
          ).called(1); // Attempted remote
          verifyZeroInteractions(
            mockDeleterService,
          ); // Deletion shouldn't happen on API error
          verifyNever(mockLocalDataSource.saveJob(any));
          verifyNoMoreInteractionsAll();
        },
      );

      test(
        'should delete local jobs missing from server using serverId comparison',
        () async {
          // Arrange
          when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

          // Local synced jobs - we'll set up one that exists on server and one missing from server
          final localJobExistsOnServer = Job(
            localId: 'local-id-1',
            serverId: 'server-id-1', // This ID exists on server
            userId: 'test-user-id',
            status: JobStatus.completed,
            syncStatus: SyncStatus.synced,
            createdAt: DateTime(2023, 1, 1),
            updatedAt: DateTime(2023, 1, 1),
          );

          final localJobDeletedOnServer = Job(
            localId: 'local-id-2',
            serverId: 'server-id-2', // This ID missing from server
            userId: 'test-user-id',
            status: JobStatus.completed,
            syncStatus: SyncStatus.synced,
            createdAt: DateTime(2023, 1, 1),
            updatedAt: DateTime(2023, 1, 1),
          );

          final localSyncedJobs = [
            localJobExistsOnServer,
            localJobDeletedOnServer,
          ];

          // Remote data - only contains one of the server IDs
          final remoteDto = JobApiDTO(
            id: 'server-id-1', // Only this one exists on server
            userId: 'test-user-id',
            jobStatus: 'completed',
            createdAt: DateTime(2023, 1, 1),
            updatedAt: DateTime(2023, 1, 1),
          );

          // Setup mocks
          when(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).thenAnswer((_) async => localSyncedJobs);
          when(
            mockRemoteDataSource.fetchJobs(),
          ).thenAnswer((_) async => [remoteDto]);

          // Act
          await service.getJobs();

          // Assert
          // Verify that permanentlyDeleteJob was called ONLY for the job missing from server
          verify(
            mockDeleterService.permanentlyDeleteJob('local-id-2'),
          ).called(1);

          // Also verify we DIDN'T try to delete the job that exists on server
          verifyNever(mockDeleterService.permanentlyDeleteJob('local-id-1'));

          // Verify other expected interactions
          verify(mockNetworkInfo.isConnected).called(1);
          verify(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).called(1);
          verify(mockRemoteDataSource.fetchJobs()).called(1);
          verify(
            mockLocalDataSource.saveJob(any),
          ).called(1); // Should save the mapped job
        },
      );

      test('should save all mapped remote jobs to local storage', () async {
        // Arrange
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

        // Remote DTOs representing multiple jobs from server
        final remoteDto1 = JobApiDTO(
          id: 'server-id-1',
          userId: 'test-user-id',
          jobStatus: 'completed',
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
        );

        final remoteDto2 = JobApiDTO(
          id: 'server-id-2',
          userId: 'test-user-id',
          jobStatus: 'created',
          createdAt: DateTime(2023, 1, 2),
          updatedAt: DateTime(2023, 1, 2),
        );

        final remoteDto3 = JobApiDTO(
          id: 'server-id-3',
          userId: 'test-user-id',
          jobStatus: 'error',
          createdAt: DateTime(2023, 1, 3),
          updatedAt: DateTime(2023, 1, 3),
        );

        // Local jobs for ID mapping
        final localJob1 = Job(
          localId: 'local-id-1',
          serverId: 'server-id-1',
          userId: 'test-user-id',
          status: JobStatus.completed,
          syncStatus: SyncStatus.synced,
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
        );

        // Setup mocks
        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
        ).thenAnswer((_) async => [localJob1]);
        when(
          mockRemoteDataSource.fetchJobs(),
        ).thenAnswer((_) async => [remoteDto1, remoteDto2, remoteDto3]);

        // We need to capture the jobs being saved to verify them
        final savedJobs = <Job>[];
        when(mockLocalDataSource.saveJob(any)).thenAnswer((invocation) {
          savedJobs.add(invocation.positionalArguments[0] as Job);
          return Future.value(unit);
        });

        // Act
        final result = await service.getJobs();

        // Assert
        // Verify saveJob was called exactly 3 times (once for each remote job)
        verify(mockLocalDataSource.saveJob(any)).called(3);

        // Verify the contents of the saved jobs
        expect(savedJobs.length, 3);

        // First job should have the mapped local ID
        expect(savedJobs[0].localId, 'local-id-1');
        expect(savedJobs[0].serverId, 'server-id-1');

        // Other jobs should have generated UUIDs but correct server IDs
        expect(savedJobs[1].localId, isNotEmpty);
        expect(savedJobs[1].serverId, 'server-id-2');

        expect(savedJobs[2].localId, isNotEmpty);
        expect(savedJobs[2].serverId, 'server-id-3');

        // All jobs should be marked as synced
        for (final job in savedJobs) {
          expect(job.syncStatus, SyncStatus.synced);
        }

        // The result should return the same jobs
        final resultJobs = result.getOrElse(() => []);
        expect(resultJobs.length, 3);
        expect(resultJobs.map((j) => j.serverId).toList()..sort(), [
          'server-id-1',
          'server-id-2',
          'server-id-3',
        ]);
      });

      test(
        'should use correct serverId set from DTOs for server deletion detection',
        () async {
          // Arrange
          when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

          // Create several local synced jobs
          final localJobs = [
            Job(
              localId: 'local-id-1',
              serverId: 'server-id-1',
              userId: 'test-user-id',
              status: JobStatus.completed,
              syncStatus: SyncStatus.synced,
              createdAt: DateTime(2023, 1, 1),
              updatedAt: DateTime(2023, 1, 1),
            ),
            Job(
              localId: 'local-id-2',
              serverId: 'server-id-2',
              userId: 'test-user-id',
              status: JobStatus.completed,
              syncStatus: SyncStatus.synced,
              createdAt: DateTime(2023, 1, 1),
              updatedAt: DateTime(2023, 1, 1),
            ),
            Job(
              localId: 'local-id-3',
              serverId: 'server-id-3',
              userId: 'test-user-id',
              status: JobStatus.error,
              syncStatus: SyncStatus.synced,
              createdAt: DateTime(2023, 1, 1),
              updatedAt: DateTime(2023, 1, 1),
            ),
          ];

          // Only return some IDs from the server (to simulate deletions)
          final remoteDtos = [
            JobApiDTO(
              id: 'server-id-1',
              userId: 'test-user-id',
              jobStatus: 'completed',
              createdAt: DateTime(2023, 1, 1),
              updatedAt: DateTime(2023, 1, 1),
            ),
            // server-id-2 is "deleted" on server
            JobApiDTO(
              id: 'server-id-3',
              userId: 'test-user-id',
              jobStatus: 'completed',
              createdAt: DateTime(2023, 1, 1),
              updatedAt: DateTime(2023, 1, 1),
            ),
            // Add a completely new ID from server
            JobApiDTO(
              id: 'server-id-4',
              userId: 'test-user-id',
              jobStatus: 'created',
              createdAt: DateTime(2023, 1, 1),
              updatedAt: DateTime(2023, 1, 1),
            ),
          ];

          // Setup mocks
          when(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).thenAnswer((_) async => localJobs);
          when(
            mockRemoteDataSource.fetchJobs(),
          ).thenAnswer((_) async => remoteDtos);

          // Act
          await service.getJobs();

          // Assert
          // Verify deletion was called only for the missing server ID
          verify(
            mockDeleterService.permanentlyDeleteJob('local-id-2'),
          ).called(1);

          // Verify the others were NOT deleted
          verifyNever(mockDeleterService.permanentlyDeleteJob('local-id-1'));
          verifyNever(mockDeleterService.permanentlyDeleteJob('local-id-3'));

          // Verify the service saved ALL remote jobs (including the new one)
          verify(mockLocalDataSource.saveJob(any)).called(3);
        },
      );
    });

    group('getJobById', () {
      const tLocalId = 'test-local-id';

      test(
        'should return Job entity when local data source finds the job',
        () async {
          // Arrange
          // Stub the entity-based method
          when(
            mockLocalDataSource.getJobById(tLocalId),
          ).thenAnswer((_) async => tJobSynced);
          // Act
          final result = await service.getJobById(tLocalId);
          // Assert
          expect(result, isA<Right<Failure, Job>>());
          expect(result.getOrElse(() => throw 'Test failed'), tJobSynced);
          // Verify the correct entity-based method was called
          verify(mockLocalDataSource.getJobById(tLocalId));

          // Use helper function for verification
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractionsAll(); // Use the helper function
        },
      );

      test(
        'should return CacheFailure when local data source throws CacheException (JobNotFound)',
        () async {
          // Arrange
          final exception = CacheException('Job with ID $tLocalId not found');
          // Stub the entity-based method to throw
          when(mockLocalDataSource.getJobById(tLocalId)).thenThrow(exception);
          // Act
          final result = await service.getJobById(tLocalId);
          // Assert
          // FIX: Provide default message for CacheFailure
          expect(
            result,
            Left(CacheFailure(exception.message ?? 'Local cache error')),
          );
          // Verify the correct entity-based method was called
          verify(mockLocalDataSource.getJobById(tLocalId));

          // Use helper function for verification
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractionsAll(); // Use the helper function
        },
      );

      test(
        'should return CacheFailure when local data source throws other CacheException',
        () async {
          // Arrange
          final exception = CacheException('DB Error');
          // Stub the entity-based method to throw
          when(mockLocalDataSource.getJobById(tLocalId)).thenThrow(exception);
          // Act
          final result = await service.getJobById(tLocalId);
          // Assert
          // FIX: Provide default message for CacheFailure
          expect(
            result,
            Left(CacheFailure(exception.message ?? 'Local cache error')),
          );
          verify(mockLocalDataSource.getJobById(tLocalId));

          // Use helper function for verification
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractionsAll(); // Use the helper function
        },
      );
    });

    group('getJobsByStatus', () {
      test('should return only jobs with the specified SyncStatus', () async {
        // Arrange
        // Stub the entity-based method to return only the pending job
        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).thenAnswer((_) async => tJobsListPendingOnly);
        // Act
        final result = await service.getJobsByStatus(SyncStatus.pending);
        // Assert
        expect(result, isA<Right<Failure, List<Job>>>());
        expect(result.getOrElse(() => []), tJobsListPendingOnly);
        // Verify the correct entity-based method was called
        verify(mockLocalDataSource.getJobsByStatus(SyncStatus.pending));

        // Use helper function for verification
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractionsAll(); // Use the helper function
      });

      test('should return empty list if no jobs match the status', () async {
        // Arrange
        // Stub the entity-based method to return empty
        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).thenAnswer((_) async => []); // No pending
        // Act
        final result = await service.getJobsByStatus(SyncStatus.pending);
        // Assert
        expect(result, isA<Right<Failure, List<Job>>>());
        expect(result.getOrElse(() => []), isEmpty);
        // Verify the correct entity-based method was called
        verify(mockLocalDataSource.getJobsByStatus(SyncStatus.pending));

        // Use helper function for verification
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractionsAll(); // Use the helper function
      });

      test(
        'should return CacheFailure when the call to local data source throws CacheException',
        () async {
          // Arrange
          final exception = CacheException('DB Error');
          // Stub the entity-based method to throw
          when(
            mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
          ).thenThrow(exception);
          // Act
          final result = await service.getJobsByStatus(SyncStatus.pending);
          // Assert
          // FIX: Provide default message for CacheFailure
          expect(
            result,
            Left(CacheFailure(exception.message ?? 'Local cache error')),
          );
          // Verify the correct entity-based method was called
          verify(mockLocalDataSource.getJobsByStatus(SyncStatus.pending));

          // Use helper function for verification
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractionsAll(); // Use the helper function
        },
      );
    });
  });
}
