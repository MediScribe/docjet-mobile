import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for all dependencies including the AuthEventBus
@GenerateMocks([
  JobLocalDataSource,
  NetworkInfo,
  JobSyncProcessorService,
  AuthEventBus,
])
import 'job_sync_orchestrator_service_auth_events_test.mocks.dart';

// Logger setup for tests
final _logger = LoggerFactory.getLogger(
  'JobSyncOrchestratorServiceAuthEventsTest',
);
final _tag = logTag('JobSyncOrchestratorServiceAuthEventsTest');

void main() {
  late MockJobLocalDataSource mockLocalDataSource;
  late MockNetworkInfo mockNetworkInfo;
  late MockJobSyncProcessorService mockProcessorService;
  late MockAuthEventBus mockAuthEventBus;
  late JobSyncOrchestratorService service;
  late StreamController<AuthEvent> eventController;

  setUp(() {
    _logger.d('$_tag Setting up auth events test...');
    mockLocalDataSource = MockJobLocalDataSource();
    mockNetworkInfo = MockNetworkInfo();
    mockProcessorService = MockJobSyncProcessorService();
    mockAuthEventBus = MockAuthEventBus();

    // Create a stream controller to simulate auth events
    eventController = StreamController<AuthEvent>.broadcast();

    // Mock stream from auth event bus
    when(mockAuthEventBus.stream).thenAnswer((_) => eventController.stream);

    // Default network is online
    when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

    // Default empty job lists
    when(mockLocalDataSource.getJobsByStatus(any)).thenAnswer((_) async => []);
    when(
      mockLocalDataSource.getJobsToRetry(any, any),
    ).thenAnswer((_) async => []);

    // Default success response for processor
    when(
      mockProcessorService.processJobSync(any),
    ).thenAnswer((_) async => const Right(unit));
    when(
      mockProcessorService.processJobDeletion(any),
    ).thenAnswer((_) async => const Right(unit));

    // Create service with mocked dependencies including the auth event bus
    service = JobSyncOrchestratorService(
      localDataSource: mockLocalDataSource,
      networkInfo: mockNetworkInfo,
      processorService: mockProcessorService,
      authEventBus: mockAuthEventBus, // Add auth event bus
    );

    _logger.d('$_tag Test setup complete.');
  });

  tearDown(() {
    _logger.d('$_tag Tearing down auth events test...');
    eventController.close();
  });

  group('Auth Event Bus subscription', () {
    test('should subscribe to auth event bus when created', () {
      // Assert
      verify(mockAuthEventBus.stream).called(1);
    });

    test('should dispose subscription when dispose is called', () {
      // Act
      service.dispose();

      // No direct way to verify subscription cancelled,
      // but we can verify disposal cleanup was called
      // This is primarily testing that dispose() doesn't throw
    });
  });

  group('Offline/Online auth events', () {
    test('should not sync when receiving offlineDetected event', () async {
      // Arrange - ensure all is set up for a normal sync
      when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

      // Act - emit offline event
      eventController.add(AuthEvent.offlineDetected);

      // Wait for event processing
      await Future.delayed(Duration.zero);

      // Try to trigger a sync
      await service.syncPendingJobs();

      // Assert - should skip network check and data fetching because it knows we're offline
      verifyNever(mockNetworkInfo.isConnected);
      verifyNever(mockLocalDataSource.getJobsByStatus(any));
      verifyNever(mockLocalDataSource.getJobsToRetry(any, any));
      verifyNever(mockProcessorService.processJobSync(any));
      verifyNever(mockProcessorService.processJobDeletion(any));
    });

    test(
      'should trigger immediate sync when receiving onlineRestored event',
      () async {
        // Arrange - setup verification
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

        // Reset interaction counters
        clearInteractions(mockNetworkInfo);
        clearInteractions(mockLocalDataSource);

        // Act - emit online event
        eventController.add(AuthEvent.onlineRestored);

        // Wait for event processing and immediate sync
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero); // Extra delay for async operations

        // Assert - should have triggered a sync
        verify(mockNetworkInfo.isConnected).called(1);

        // Use matchers that don't rely on specific counts, just verify they're called
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).called(1);
        verify(mockLocalDataSource.getJobsToRetry(any, any)).called(1);
      },
    );

    test('should skip sync when offline state is persistent', () async {
      // Arrange - set up offline state and trigger event
      eventController.add(AuthEvent.offlineDetected);
      await Future.delayed(Duration.zero);

      // Act - attempt multiple syncs
      await service.syncPendingJobs();
      await service.syncPendingJobs();

      // Assert - still no sync attempted
      verifyNever(mockNetworkInfo.isConnected);
      verifyNever(mockLocalDataSource.getJobsByStatus(any));
      verifyNever(mockProcessorService.processJobSync(any));
    });

    test(
      'should resume normal sync operation after online is restored',
      () async {
        // Arrange - set up offline state and then restore online
        eventController.add(AuthEvent.offlineDetected);
        await Future.delayed(Duration.zero);

        // First sync attempt - should be skipped
        await service.syncPendingJobs();

        // Reset network mock verification count
        clearInteractions(mockNetworkInfo);
        clearInteractions(mockLocalDataSource);

        // Act - restore online and try sync again
        eventController.add(AuthEvent.onlineRestored);
        await Future.delayed(Duration.zero);

        // Reset interaction counts since immediate sync already runs after online restored
        clearInteractions(mockNetworkInfo);
        clearInteractions(mockLocalDataSource);

        // Trigger explicit sync - this should now proceed
        await service.syncPendingJobs();

        // Assert - verify normal sync proceeds
        verify(mockNetworkInfo.isConnected).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).called(1);
        verify(mockLocalDataSource.getJobsToRetry(any, any)).called(1);
      },
    );
  });

  group('Logout event handling', () {
    test(
      'should cancel in-progress sync when receiving loggedOut event',
      () async {
        // We need some way to simulate an in-progress sync
        // For this test, we'd ideally have a spy on syncPendingJobs or
        // a way to check if the mutex is locked.

        // For now, let's verify sync doesn't proceed after logout

        // Act - emit logged out event
        eventController.add(AuthEvent.loggedOut);
        await Future.delayed(Duration.zero);

        // Try to trigger a sync
        await service.syncPendingJobs();

        // Assert - should skip sync entirely
        verifyNever(mockNetworkInfo.isConnected);
        verifyNever(mockLocalDataSource.getJobsByStatus(any));
        verifyNever(mockProcessorService.processJobSync(any));
      },
    );

    test('should resume sync after login (loggedIn event)', () async {
      // Arrange - first logout
      eventController.add(AuthEvent.loggedOut);
      await Future.delayed(Duration.zero);

      // First sync attempt - should be skipped
      await service.syncPendingJobs();

      // Reset verification
      clearInteractions(mockNetworkInfo);
      clearInteractions(mockLocalDataSource);

      // Act - login and try sync
      eventController.add(AuthEvent.loggedIn);
      await Future.delayed(Duration.zero);

      // Trigger explicit sync - should now proceed
      await service.syncPendingJobs();

      // Assert - verify normal sync proceeds
      verify(mockNetworkInfo.isConnected).called(1);
      verify(mockLocalDataSource.getJobsByStatus(SyncStatus.pending)).called(1);
      verify(
        mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
      ).called(1);
      verify(mockLocalDataSource.getJobsToRetry(any, any)).called(1);
    });
  });

  group('In-flight cancellation', () {
    test(
      'should abort in-flight sync jobs when offlineDetected event is received',
      () async {
        // Arrange - setup multiple jobs that need syncing
        final jobList = List.generate(
          5,
          (index) => Job(
            localId: 'job-$index',
            userId: 'user1',
            text: 'text-$index',
            audioFilePath: 'path-$index',
            syncStatus: SyncStatus.pending,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: JobStatus.created,
          ),
        );

        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).thenAnswer((_) async => jobList);

        // Make processor service calls delay a bit to simulate work
        when(mockProcessorService.processJobSync(any)).thenAnswer((_) async {
          // Short delay to simulate work
          await Future.delayed(const Duration(milliseconds: 10));
          return const Right(unit);
        });

        // Act - start sync and then trigger offline event during sync
        final syncFuture = service.syncPendingJobs();

        // Give sync time to start but not finish
        await Future.delayed(const Duration(milliseconds: 5));

        // Trigger offline during sync
        eventController.add(AuthEvent.offlineDetected);

        // Let sync complete
        await syncFuture;

        // Assert - verify that not all jobs were processed
        verify(mockProcessorService.processJobSync(any)).called(lessThan(5));
      },
    );

    test(
      'should abort in-flight deletion jobs when loggedOut event is received',
      () async {
        // Arrange - setup multiple jobs for deletion
        final deletionJobList = List.generate(
          5,
          (index) => Job(
            localId: 'deletion-$index',
            userId: 'user1',
            text: 'text-$index',
            audioFilePath: 'path-$index',
            syncStatus: SyncStatus.pendingDeletion,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: JobStatus.pendingDeletion,
          ),
        );

        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).thenAnswer((_) async => deletionJobList);

        // Make processor service calls delay a bit to simulate work
        when(mockProcessorService.processJobDeletion(any)).thenAnswer((
          _,
        ) async {
          // Short delay to simulate work
          await Future.delayed(const Duration(milliseconds: 10));
          return const Right(unit);
        });

        // Act - start sync and then trigger logout event during sync
        final syncFuture = service.syncPendingJobs();

        // Give sync time to start but not finish
        await Future.delayed(const Duration(milliseconds: 5));

        // Trigger logout during sync
        eventController.add(AuthEvent.loggedOut);

        // Let sync complete
        await syncFuture;

        // Assert - verify that not all jobs were processed
        verify(
          mockProcessorService.processJobDeletion(any),
        ).called(lessThan(5));
      },
    );
  });
}
