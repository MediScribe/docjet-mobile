import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_trigger_service.dart'; // This import will fail initially
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart'; // Import fake_async

import 'job_sync_trigger_service_test.mocks.dart';

@GenerateMocks([JobSyncOrchestratorService])
void main() {
  // Initialize binding for tests involving WidgetsBindingObserver
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJobSyncOrchestratorService mockOrchestratorService;
  late JobSyncTriggerService service; // This will fail initially

  setUp(() {
    mockOrchestratorService = MockJobSyncOrchestratorService();
    // Service instantiation will fail until the class exists
    // service = JobSyncTriggerService(orchestratorService: mockOrchestratorService);
  });

  test(
    'didChangeAppLifecycleState should trigger sync when state is resumed',
    () async {
      // Arrange
      // Ensure orchestrator setup for verification with CORRECT return type
      when(mockOrchestratorService.syncPendingJobs()).thenAnswer(
        (_) async => const Right(unit),
      ); // Return Future<Either<Failure, Unit>>

      // TODO: Instantiate the service once it exists
      service = JobSyncTriggerService(
        orchestratorService: mockOrchestratorService,
      );

      // Act
      // Simulate the lifecycle change - we'll assume a method like this exists
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Assert
      // Use verify Mocks correctly: Use verify(...) not verifyMocks(...)
      verify(mockOrchestratorService.syncPendingJobs()).called(1);
    },
  );

  test(
    'didChangeAppLifecycleState should NOT trigger sync when state is paused',
    () async {
      // Arrange
      // No need to setup 'when' for syncPendingJobs as we expect it NOT to be called.
      service = JobSyncTriggerService(
        orchestratorService: mockOrchestratorService,
      );

      // Act
      service.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Assert
      verifyNever(mockOrchestratorService.syncPendingJobs());
    },
  );

  // Add more tests later for inactive, detached, timer, etc.

  test('startTimer should trigger sync periodically', () {
    // Use fake_async to control time
    fakeAsync((async) {
      // Arrange
      const timerDuration = Duration(seconds: 15); // Define sync interval
      when(
        mockOrchestratorService.syncPendingJobs(),
      ).thenAnswer((_) async => const Right(unit));

      service = JobSyncTriggerService(
        orchestratorService: mockOrchestratorService,
        // Explicitly pass the duration used in this test
        syncInterval: timerDuration,
      );

      // Act
      service.startTimer();

      // Act: Advance time twice
      async.elapse(timerDuration);
      async.flushMicrotasks(); // Flush after first elapse
      async.elapse(timerDuration);
      async.flushMicrotasks(); // Flush after second elapse

      // Assert: Should have been called exactly twice after two intervals
      verify(mockOrchestratorService.syncPendingJobs()).called(2);

      // Cleanup (important with fake_async)
      service.stopTimer(); // Or dispose, ensure timer is cancelled
    });
  });

  test('stopTimer should cancel the periodic timer', () {
    fakeAsync((async) {
      // Arrange
      const timerDuration = Duration(seconds: 15);
      when(
        mockOrchestratorService.syncPendingJobs(),
      ).thenAnswer((_) async => const Right(unit));

      service = JobSyncTriggerService(
        orchestratorService: mockOrchestratorService,
        syncInterval: timerDuration,
      );

      // Act
      service.startTimer();
      // Elapse some time, but less than the interval
      async.elapse(timerDuration ~/ 2);
      // Stop the timer before it fires
      service.stopTimer();
      // Elapse well past the original interval
      async.elapse(timerDuration * 2);
      // Flush any potential microtasks (though none should be scheduled)
      async.flushMicrotasks();

      // Assert
      // Verify sync was never called because timer was stopped
      verifyNever(mockOrchestratorService.syncPendingJobs());
    });
  });

  test('dispose should cancel the periodic timer', () {
    fakeAsync((async) {
      // Arrange
      const timerDuration = Duration(seconds: 15);
      when(
        mockOrchestratorService.syncPendingJobs(),
      ).thenAnswer((_) async => const Right(unit));

      service = JobSyncTriggerService(
        orchestratorService: mockOrchestratorService,
        syncInterval: timerDuration,
      );

      // Act
      service.startTimer();
      // Elapse some time, but less than the interval
      async.elapse(timerDuration ~/ 2);
      // Dispose the service before timer fires
      service.dispose();
      // Elapse well past the original interval
      async.elapse(timerDuration * 2);
      // Flush any potential microtasks
      async.flushMicrotasks();

      // Assert
      // Verify sync was never called because service was disposed
      verifyNever(mockOrchestratorService.syncPendingJobs());
    });
  });
}
