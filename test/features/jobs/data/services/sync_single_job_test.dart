import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/data/config/job_sync_config.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logging utilities
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'job_sync_service_test_helpers.dart';
import 'job_sync_service_test.mocks.dart'; // Assuming mocks are generated here

// Create a logger instance for test debugging
final _logger = LoggerFactory.getLogger('SyncSingleJobTest');
final _tag = logTag('SyncSingleJobTest');

@GenerateMocks([
  JobLocalDataSource,
  JobRemoteDataSource,
  // No NetworkInfo or FileSystem needed for syncSingleJob tests
])
void main() {
  _logger.i('$_tag Starting syncSingleJob tests...');

  late MockJobLocalDataSource mockLocalDataSource;
  late MockJobRemoteDataSource mockRemoteDataSource;
  late JobSyncService service;

  setUp(() {
    _logger.d('$_tag Setting up test...');
    mockLocalDataSource = MockJobLocalDataSource();
    mockRemoteDataSource = MockJobRemoteDataSource();

    // Note: We don't need NetworkInfo or FileSystem mocks here
    service = JobSyncService(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
      networkInfo:
          MockNetworkInfo(), // Provide dummy mocks if constructor requires non-null
      fileSystem: MockFileSystem(),
    );

    // Default mocks for saveJob (can be overridden)
    when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async {
      _logger.d('$_tag Mock saveJob called, returning unit');
      return unit;
    });

    _logger.d('$_tag Test setup complete');
  });

  group('syncSingleJob - Success Cases', () {
    test(
      'should call remote createJob and save returned job when serverId is null',
      () async {
        _logger.i('$_tag Starting test: should call remote createJob...');

        // Arrange
        _logger.d('$_tag Arranging mocks...');
        when(
          mockRemoteDataSource.createJob(
            userId: tPendingJobNew.userId,
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        ).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock createJob called, returning tSyncedJobFromServer',
          );
          return tSyncedJobFromServer;
        });

        _logger.d('$_tag Test arranged, starting action...');

        // Act
        _logger.d('$_tag Calling service.syncSingleJob...');
        final result = await service.syncSingleJob(tPendingJobNew);
        _logger.d('$_tag service.syncSingleJob completed with result: $result');

        // Assert
        _logger.d('$_tag Starting assertions');
        expect(result, equals(Right(tSyncedJobFromServer)));
        verify(
          mockRemoteDataSource.createJob(
            userId: tPendingJobNew.userId,
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        ).called(1);
        verify(mockLocalDataSource.saveJob(tSyncedJobFromServer)).called(1);
        verifyNever(
          mockRemoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        );
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalDataSource);
        _logger.i('$_tag Test completed successfully');
      },
    );

    test(
      'should call remote updateJob and save returned job when serverId is NOT null',
      () async {
        _logger.i('$_tag Starting test: should call remote updateJob...');

        // Arrange
        _logger.d('$_tag Arranging mocks...');
        when(
          mockRemoteDataSource.updateJob(
            jobId: tExistingJobPendingUpdate.serverId!,
            updates: anyNamed('updates'),
          ),
        ).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock updateJob called, returning tUpdatedJobFromServer',
          );
          return tUpdatedJobFromServer;
        });

        _logger.d('$_tag Test arranged, starting action...');

        // Act
        _logger.d('$_tag Calling service.syncSingleJob...');
        final result = await service.syncSingleJob(tExistingJobPendingUpdate);
        _logger.d('$_tag service.syncSingleJob completed with result: $result');

        // Assert
        _logger.d('$_tag Starting assertions');
        expect(result, equals(Right(tUpdatedJobFromServer)));
        verify(
          mockRemoteDataSource.updateJob(
            jobId: tExistingJobPendingUpdate.serverId!,
            updates: anyNamed('updates'),
          ),
        ).called(1);
        verify(mockLocalDataSource.saveJob(tUpdatedJobFromServer)).called(1);
        verifyNever(
          mockRemoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        );
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalDataSource);
        _logger.i('$_tag Test completed successfully');
      },
    );
  });

  group('syncSingleJob - Error Handling & Retries', () {
    test(
      'when remote createJob fails and retries remain, should return Left, update status to error, increment count, save locally',
      () async {
        _logger.i(
          '$_tag Starting test: remote createJob fails with retries remaining',
        );

        // Arrange
        final initialJob = tPendingJobNew; // New job, first sync attempt
        final serverException = ServerException('Create failed');
        final now = DateTime.now(); // Capture time for comparison
        _logger.d('$_tag Arranging mocks for failure scenario');

        when(
          mockRemoteDataSource.createJob(
            userId: initialJob.userId,
            audioFilePath: initialJob.audioFilePath!,
            text: initialJob.text,
            additionalText: initialJob.additionalText,
          ),
        ).thenThrow(serverException);

        _logger.d('$_tag Throwing configured, now starting action');

        // Act - directly await the result
        _logger.d(
          '$_tag Calling service.syncSingleJob and expecting exception handling',
        );
        final result = await service.syncSingleJob(initialJob);
        _logger.d('$_tag syncSingleJob completed with result: $result');

        // Assert
        _logger.d('$_tag Starting assertions');
        expect(result.isLeft(), isTrue);

        // Extract the failure using fold and verify it
        final extractedFailure = result.fold(
          (failure) => failure,
          (_) => throw StateError('Should be Left, not Right'),
        );
        expect(extractedFailure, isA<ServerFailure>());
        expect(
          (extractedFailure as ServerFailure).message,
          contains(
            'Failed to sync job ${initialJob.localId} (retries remain): ${serverException.toString()}',
          ),
        );

        // Verify saveJob was called with the correct error state
        final verification = verify(mockLocalDataSource.saveJob(captureAny));
        verification.called(1);
        final savedJob = verification.captured.single as Job;
        _logger.d(
          '$_tag Captured job in saveJob: syncStatus=${savedJob.syncStatus}, retryCount=${savedJob.retryCount}',
        );

        expect(savedJob.syncStatus, SyncStatus.error);
        expect(savedJob.retryCount, initialJob.retryCount + 1);
        expect(savedJob.lastSyncAttemptAt, isNotNull);
        // Use tolerance for DateTime comparison due to potential microsecond differences
        expect(
          savedJob.lastSyncAttemptAt!.isAfter(
            now.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(
          savedJob.lastSyncAttemptAt!.isBefore(
            now.add(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(savedJob.localId, initialJob.localId);

        verifyNever(
          mockRemoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        );

        _logger.i('$_tag Test completed successfully');
      },
    );

    test(
      'when remote createJob fails and max retries reached, should return Left, update status to failed, increment count, save locally',
      () async {
        _logger.i(
          '$_tag Starting test: remote createJob fails with max retries reached',
        );

        // Arrange
        final initialJob = tPendingJobNew.copyWith(
          retryCount: maxRetryAttempts - 1,
        );
        final serverException = ServerException('Create failed again');
        final now = DateTime.now();
        _logger.d('$_tag Arranging mocks for failure scenario');

        when(
          mockRemoteDataSource.createJob(
            userId: initialJob.userId,
            audioFilePath: initialJob.audioFilePath!,
            text: initialJob.text,
            additionalText: initialJob.additionalText,
          ),
        ).thenThrow(serverException);

        _logger.d('$_tag Throwing configured, now starting action');

        // Act
        _logger.d(
          '$_tag Calling service.syncSingleJob and expecting exception handling',
        );
        final result = await service.syncSingleJob(initialJob);
        _logger.d('$_tag syncSingleJob completed with result: $result');

        // Assert
        _logger.d('$_tag Starting assertions');
        expect(result.isLeft(), isTrue);

        // Extract the failure using fold and verify it
        final extractedFailure = result.fold(
          (failure) => failure,
          (_) => throw StateError('Should be Left, not Right'),
        );
        expect(extractedFailure, isA<ServerFailure>());
        expect(
          (extractedFailure as ServerFailure).message,
          contains(
            'Failed to sync job ${initialJob.localId} after max retries: ${serverException.toString()}',
          ),
        );

        final verification = verify(mockLocalDataSource.saveJob(captureAny));
        verification.called(1);
        final savedJob = verification.captured.single as Job;
        _logger.d(
          '$_tag Captured job in saveJob: syncStatus=${savedJob.syncStatus}, retryCount=${savedJob.retryCount}',
        );

        expect(savedJob.syncStatus, SyncStatus.failed); // Status becomes failed
        expect(savedJob.retryCount, maxRetryAttempts); // Incremented to max
        expect(savedJob.lastSyncAttemptAt, isNotNull);
        expect(
          savedJob.lastSyncAttemptAt!.isAfter(
            now.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(
          savedJob.lastSyncAttemptAt!.isBefore(
            now.add(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(savedJob.localId, initialJob.localId);

        verifyNever(
          mockRemoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        );

        _logger.i('$_tag Test completed successfully');
      },
    );

    test(
      'when remote updateJob fails and retries remain, should return Left, update status to error, increment count, save locally',
      () async {
        _logger.i(
          '$_tag Starting test: remote updateJob fails with retries remaining',
        );

        // Arrange
        final initialJob = tExistingJobPendingUpdate.copyWith(retryCount: 1);
        final serverException = ServerException('Update failed');
        final now = DateTime.now();
        _logger.d('$_tag Arranging mocks for failure scenario');

        when(
          mockRemoteDataSource.updateJob(
            jobId: initialJob.serverId!,
            updates: anyNamed('updates'),
          ),
        ).thenThrow(serverException);

        _logger.d('$_tag Throwing configured, now starting action');

        // Act
        _logger.d(
          '$_tag Calling service.syncSingleJob and expecting exception handling',
        );
        final result = await service.syncSingleJob(initialJob);
        _logger.d('$_tag syncSingleJob completed with result: $result');

        // Assert
        _logger.d('$_tag Starting assertions');
        expect(result.isLeft(), isTrue);

        // Extract the failure using fold and verify it
        final extractedFailure = result.fold(
          (failure) => failure,
          (_) => throw StateError('Should be Left, not Right'),
        );
        expect(extractedFailure, isA<ServerFailure>());
        expect(
          (extractedFailure as ServerFailure).message,
          contains(
            'Failed to sync job ${initialJob.localId} (retries remain): ${serverException.toString()}',
          ),
        );

        final verification = verify(mockLocalDataSource.saveJob(captureAny));
        verification.called(1);
        final savedJob = verification.captured.single as Job;
        _logger.d(
          '$_tag Captured job in saveJob: syncStatus=${savedJob.syncStatus}, retryCount=${savedJob.retryCount}',
        );

        expect(savedJob.syncStatus, SyncStatus.error);
        expect(savedJob.retryCount, initialJob.retryCount + 1);
        expect(savedJob.lastSyncAttemptAt, isNotNull);
        expect(
          savedJob.lastSyncAttemptAt!.isAfter(
            now.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(
          savedJob.lastSyncAttemptAt!.isBefore(
            now.add(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(savedJob.localId, initialJob.localId);

        verifyNever(
          mockRemoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        );

        _logger.i('$_tag Test completed successfully');
      },
    );

    test(
      'when remote updateJob fails and max retries reached, should return Left, update status to failed, increment count, save locally',
      () async {
        _logger.i(
          '$_tag Starting test: remote updateJob fails with max retries reached',
        );

        // Arrange
        final initialJob = tExistingJobPendingUpdate.copyWith(
          retryCount: maxRetryAttempts - 1,
        );
        final serverException = ServerException('Update failed finally');
        final now = DateTime.now();
        _logger.d('$_tag Arranging mocks for failure scenario');

        when(
          mockRemoteDataSource.updateJob(
            jobId: initialJob.serverId!,
            updates: anyNamed('updates'),
          ),
        ).thenThrow(serverException);

        _logger.d('$_tag Throwing configured, now starting action');

        // Act
        _logger.d(
          '$_tag Calling service.syncSingleJob and expecting exception handling',
        );
        final result = await service.syncSingleJob(initialJob);
        _logger.d('$_tag syncSingleJob completed with result: $result');

        // Assert
        _logger.d('$_tag Starting assertions');
        expect(result.isLeft(), isTrue);

        // Extract the failure using fold and verify it
        final extractedFailure = result.fold(
          (failure) => failure,
          (_) => throw StateError('Should be Left, not Right'),
        );
        expect(extractedFailure, isA<ServerFailure>());
        expect(
          (extractedFailure as ServerFailure).message,
          contains(
            'Failed to sync job ${initialJob.localId} after max retries: ${serverException.toString()}',
          ),
        );

        final verification = verify(mockLocalDataSource.saveJob(captureAny));
        verification.called(1);
        final savedJob = verification.captured.single as Job;
        _logger.d(
          '$_tag Captured job in saveJob: syncStatus=${savedJob.syncStatus}, retryCount=${savedJob.retryCount}',
        );

        expect(savedJob.syncStatus, SyncStatus.failed);
        expect(savedJob.retryCount, maxRetryAttempts);
        expect(savedJob.lastSyncAttemptAt, isNotNull);
        expect(
          savedJob.lastSyncAttemptAt!.isAfter(
            now.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(
          savedJob.lastSyncAttemptAt!.isBefore(
            now.add(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(savedJob.localId, initialJob.localId);

        verifyNever(
          mockRemoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        );

        _logger.i('$_tag Test completed successfully');
      },
    );

    test(
      'should return Left(CacheFailure) if local saveJob fails after successful remote create',
      () async {
        _logger.i(
          '$_tag Starting test: saveJob fails after successful remote create',
        );

        // Arrange
        final cacheException = CacheException();
        _logger.d(
          '$_tag Arranging mocks for create success, save failure scenario',
        );

        when(
          mockRemoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock createJob called, returning tSyncedJobFromServer',
          );
          return tSyncedJobFromServer;
        }); // Remote succeeds

        when(
          mockLocalDataSource.saveJob(tSyncedJobFromServer),
        ).thenThrow(cacheException); // Local save fails

        _logger.d('$_tag Mocks arranged, now starting action');

        // Act
        _logger.d(
          '$_tag Calling service.syncSingleJob with expected failure on save',
        );
        final result = await service.syncSingleJob(tPendingJobNew);
        _logger.d('$_tag syncSingleJob completed with result: $result');

        // Assert
        _logger.d('$_tag Starting assertions');
        expect(result.isLeft(), isTrue);
        final extractedFailure = result.fold(
          (failure) => failure,
          (_) => throw StateError('Should be Left, not Right'),
        );
        expect(extractedFailure, isA<CacheFailure>());

        verify(
          mockRemoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).called(1);
        verify(mockLocalDataSource.saveJob(tSyncedJobFromServer)).called(1);

        _logger.i('$_tag Test completed successfully');
      },
    );

    test(
      'should return Left(CacheFailure) if local saveJob fails after successful remote update',
      () async {
        _logger.i(
          '$_tag Starting test: saveJob fails after successful remote update',
        );

        // Arrange
        final cacheException = CacheException();
        _logger.d(
          '$_tag Arranging mocks for update success, save failure scenario',
        );

        when(
          mockRemoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        ).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock updateJob called, returning tUpdatedJobFromServer',
          );
          return tUpdatedJobFromServer;
        }); // Remote succeeds

        when(
          mockLocalDataSource.saveJob(tUpdatedJobFromServer),
        ).thenThrow(cacheException); // Local save fails

        _logger.d('$_tag Mocks arranged, now starting action');

        // Act
        _logger.d(
          '$_tag Calling service.syncSingleJob with expected failure on save',
        );
        final result = await service.syncSingleJob(tExistingJobPendingUpdate);
        _logger.d('$_tag syncSingleJob completed with result: $result');

        // Assert
        _logger.d('$_tag Starting assertions');
        expect(result.isLeft(), isTrue);
        final extractedFailure = result.fold(
          (failure) => failure,
          (_) => throw StateError('Should be Left, not Right'),
        );
        expect(extractedFailure, isA<CacheFailure>());

        verify(
          mockRemoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        ).called(1);
        verify(mockLocalDataSource.saveJob(tUpdatedJobFromServer)).called(1);

        _logger.i('$_tag Test completed successfully');
      },
    );

    test(
      'should return Left(CacheFailure) if local saveJob fails when saving error status after remote create failure',
      () async {
        _logger.i('$_tag Starting test: saveJob fails when saving error state');

        // Arrange
        final serverException = ServerException('Create failed');
        final cacheException = CacheException();
        final initialJob = tPendingJobNew;
        _logger.d(
          '$_tag Arranging mocks for double failure scenario (remote then local)',
        );

        when(
          mockRemoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenThrow(serverException);

        when(
          mockLocalDataSource.saveJob(any),
        ).thenThrow(cacheException); // Local save fails

        _logger.d('$_tag Mocks arranged, now starting action');

        // Act
        _logger.d('$_tag Calling service.syncSingleJob with expected failures');
        final result = await service.syncSingleJob(initialJob);
        _logger.d('$_tag syncSingleJob completed with result: $result');

        // Assert
        _logger.d('$_tag Starting assertions');

        // The primary failure returned should be the one from the remote source
        expect(result.isLeft(), isTrue);
        final extractedFailure = result.fold(
          (failure) => failure,
          (_) => throw StateError('Should be Left, not Right'),
        );
        expect(extractedFailure, isA<CacheFailure>());
        expect(
          (extractedFailure as CacheFailure).message,
          equals('Failed to save error state'),
        );

        // Verify saveJob was attempted with an error job
        verify(
          mockLocalDataSource.saveJob(
            argThat(
              predicate<Job>(
                (job) =>
                    job.localId == initialJob.localId &&
                    job.syncStatus == SyncStatus.error &&
                    job.retryCount == initialJob.retryCount + 1 &&
                    job.lastSyncAttemptAt != null,
              ),
            ),
          ),
        ).called(1);

        _logger.i('$_tag Test completed successfully');
      },
    );
  });
}
