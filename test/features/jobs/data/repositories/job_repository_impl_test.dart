import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart';
// Import the now-existing implementation
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for the dependencies (JobMapper removed)
@GenerateMocks([JobRemoteDataSource, JobLocalDataSource])
import 'job_repository_impl_test.mocks.dart';

void main() {
  late JobRepositoryImpl repository;
  late MockJobRemoteDataSource mockRemoteDataSource;
  late MockJobLocalDataSource mockLocalDataSource;
  // late MockJobMapper mockMapper; // REMOVED

  setUp(() {
    mockRemoteDataSource = MockJobRemoteDataSource();
    mockLocalDataSource = MockJobLocalDataSource();
    // mockMapper = MockJobMapper(); // REMOVED
    // Instantiate the repository without the mapper
    repository = JobRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
      // mapper: mockMapper, // REMOVED
    );
  });

  // Sample data for testing
  final tJob = Job(
    id: 'job1',
    userId: 'user123',
    status: 'completed', // Consider using enum later as per REFACTOR note
    displayTitle: 'Test Job 1',
    audioFilePath: '/path/to/test.mp3', // Example local path
    createdAt: DateTime.parse('2023-01-01T10:00:00Z'),
    updatedAt: DateTime.parse('2023-01-01T11:00:00Z'),
  );
  final tJobs = [tJob];

  // Use the static mapper method directly to create the expected hive models for assertion
  final tJobHiveModels = JobMapper.toHiveModelList(tJobs);

  group('getJobs', () {
    test(
      'should fetch jobs from remote source, map them (statically), save locally, and return entities',
      () async {
        // Arrange
        // *** ADDED: Simulate cache miss ***
        when(
          mockLocalDataSource.getAllJobHiveModels(),
        ).thenAnswer((_) async => []);
        // 1. Stub remote fetch
        when(
          mockRemoteDataSource.fetchJobs(),
        ).thenAnswer((_) async => tJobs); // Remote returns List<Job>
        // 2. Stub mapping - REMOVED (uses static mapper)
        // when(mockMapper.toHiveModelList(tJobs)).thenReturn(tJobHiveModels);
        // 3. Stub local save (accepts Hive Models) - Use the statically generated tJobHiveModels
        when(mockLocalDataSource.saveJobHiveModels(tJobHiveModels)).thenAnswer(
          (_) async => Future.value(),
        ); // Assuming save returns Future<void>
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
        verifyNoMoreInteractions(mockLocalDataSource);
        // verifyNoMoreInteractions(mockMapper); // REMOVED
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
      // 1. Stub local fetch to return some cached data (JobHiveModel list)
      when(mockLocalDataSource.getAllJobHiveModels()).thenAnswer(
        (_) async => tJobHiveModels,
      ); // Use the pre-defined hive models
      // *** ADDED: Stub getLastFetchTime to return a recent timestamp (cache is fresh) ***
      when(
        mockLocalDataSource.getLastFetchTime(),
      ).thenAnswer((_) async => DateTime.now());
      // 2. NO need to stub remote or local save for this path

      // Act
      final result = await repository.getJobs();

      // Assert
      // 1. Check the result using dartz Either equality (which respects Equatable)
      result.fold(
        (failure) => fail('Expected Right (cached jobs), got Left: $failure'),
        (jobs) => expect(jobs, tJobs), // Compare the list content
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
        // 2. Stub remote fetch to succeed
        when(mockRemoteDataSource.fetchJobs()).thenAnswer((_) async => tJobs);
        // 3. Stub local save to succeed (as remote fetch will try to save)
        when(
          mockLocalDataSource.saveJobHiveModels(any),
        ).thenAnswer((_) async => Future.value());

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
        // 5. Verify saveLastFetchTime was called
        verify(mockLocalDataSource.saveLastFetchTime(any)).called(1);
        // 6. Verify no other interactions occurred
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalDataSource);
      },
    );

    test(
      'should return remote data successfully even if local cache save fails',
      () async {
        // Arrange
        // 1. Stub local get to return empty (cache miss)
        when(
          mockLocalDataSource.getAllJobHiveModels(),
        ).thenAnswer((_) async => []);
        // 2. Stub remote fetch to succeed
        when(mockRemoteDataSource.fetchJobs()).thenAnswer((_) async => tJobs);
        // 3. Stub local save to throw CacheException
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
        verifyNoMoreInteractions(mockLocalDataSource);
      },
    );

    test('should fetch from remote when local cache is stale', () async {
      // Arrange
      final staleTime = DateTime.now().subtract(const Duration(hours: 2));
      // 1. Stub local get to return non-empty list
      when(
        mockLocalDataSource.getAllJobHiveModels(),
      ).thenAnswer((_) async => tJobHiveModels);
      // 2. Stub getLastFetchTime to return a stale time
      when(
        mockLocalDataSource.getLastFetchTime(),
      ).thenAnswer((_) async => staleTime);
      // 3. Stub remote fetch to succeed (return same jobs for simplicity)
      when(mockRemoteDataSource.fetchJobs()).thenAnswer((_) async => tJobs);
      // 4. Stub local save to succeed
      when(
        mockLocalDataSource.saveJobHiveModels(any),
      ).thenAnswer((_) async => Future.value());
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
      verifyNoMoreInteractions(mockLocalDataSource);
    });

    // TODO: Add test case for local cache save error when returning remote data successfully (already covered?) -> Verify behavior clarity
    // TODO: Add test case for handling known network unavailability (offline first behavior)
    // TODO: Add test case for returning stale data as fallback when remote fetch fails
  });

  // Add groups for other methods like getJobById, createJob etc. later
}
