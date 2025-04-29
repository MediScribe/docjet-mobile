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

  // Helper function for verifying no more interactions
  void verifyNoMoreInteractionsAll() {
    verifyNoMoreInteractions(mockLocalDataSource);
    verifyNoMoreInteractions(mockRemoteDataSource);
    verifyNoMoreInteractions(mockDeleterService);
    verifyNoMoreInteractions(mockNetworkInfo);
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
        'should return remote jobs, save them locally, and not delete when online and local synced is empty',
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
            (_) async => tJobsListSyncedOnly, // Remote returns one synced job
          );

          // Act
          final result = await service.getJobs();

          // Assert
          expect(result, isA<Right<Failure, List<Job>>>());
          expect(
            result.getOrElse(() => []),
            tJobsListSyncedOnly,
          ); // Expect remote data
          verify(mockNetworkInfo.isConnected).called(1);
          // Verify getJobsByStatus was checked for synced jobs
          verify(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).called(1);
          verify(mockRemoteDataSource.fetchJobs()).called(1); // Fetched remote
          // Verify saveJob was called correctly for the fetched job
          verify(mockLocalDataSource.saveJob(tJobSynced)).called(1);
          verifyZeroInteractions(mockDeleterService); // No deletions expected
          verifyNoMoreInteractionsAll();
        },
      );

      test(
        'should return remote jobs, save them locally, detect server deletions, trigger local deletion, and return remote jobs when online',
        () async {
          // Arrange
          when(
            mockNetworkInfo.isConnected,
          ).thenAnswer((_) async => true); // ONLINE
          // 1. Remote source returns ONLY the pending job (synced one was deleted on server)
          when(
            mockRemoteDataSource.fetchJobs(),
          ).thenAnswer((_) async => tJobsListPendingOnly);
          // 2. Local source returns the synced job when asked for synced jobs
          when(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).thenAnswer(
            (_) async => tJobsListSyncedOnly, // Contains the job to be deleted
          );

          // Act
          final result = await service.getJobs();

          // Assert
          // 1. Result should be the list from the remote source (pending only)
          expect(result, isA<Right<Failure, List<Job>>>());
          expect(result.getOrElse(() => []), tJobsListPendingOnly);
          // 2. Verify interactions
          verify(mockNetworkInfo.isConnected).called(1);
          // Verify getJobsByStatus was checked for synced jobs
          verify(
            mockLocalDataSource.getJobsByStatus(SyncStatus.synced),
          ).called(1);
          verify(mockRemoteDataSource.fetchJobs()).called(1); // Fetch remote
          // 3. Verify saveJob was called for the remotely fetched data (pending job)
          verify(mockLocalDataSource.saveJob(tJobPending)).called(1);
          // 4. Crucially, verify the deleter service was called for the synced job
          verify(
            mockDeleterService.permanentlyDeleteJob(tJobSynced.localId),
          ).called(1);
          // 5. Ensure deleter was NOT called for the pending job (it was in the remote list)
          verifyNever(
            mockDeleterService.permanentlyDeleteJob(tJobPending.localId),
          );
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
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractions(mockRemoteDataSource);
          verifyZeroInteractions(mockDeleterService);
          verifyZeroInteractions(
            mockNetworkInfo,
          ); // No network check needed for getById
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
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractions(mockRemoteDataSource);
          verifyZeroInteractions(mockDeleterService);
          verifyZeroInteractions(mockNetworkInfo);
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
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractions(mockRemoteDataSource);
          verifyZeroInteractions(mockDeleterService);
          verifyZeroInteractions(mockNetworkInfo);
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
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractions(mockRemoteDataSource);
        verifyZeroInteractions(mockDeleterService);
        verifyZeroInteractions(
          mockNetworkInfo,
        ); // No network check needed for getByStatus
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
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractions(mockRemoteDataSource);
        verifyZeroInteractions(mockDeleterService);
        verifyZeroInteractions(mockNetworkInfo);
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
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractions(mockRemoteDataSource);
          verifyZeroInteractions(mockDeleterService);
          verifyZeroInteractions(mockNetworkInfo);
        },
      );
    });
  });
}
