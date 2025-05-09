import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_trigger_service.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:flutter/material.dart'; // Combined Widgets/Material import is fine
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Import the mock file that will be generated in this directory
import 'job_sync_trigger_service_test.mocks.dart';

// Mock Timer class
class MockTimer extends Mock implements Timer {
  @override
  bool get isActive => super.noSuchMethod(
    Invocation.getter(#isActive),
    returnValue: false,
    returnValueForMissingStub: false,
  );

  @override
  void cancel() => super.noSuchMethod(Invocation.method(#cancel, []));
}

// Add the annotation to generate the correct mock
@GenerateMocks([JobRepository])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Remove orchestrator mock variable
  // late MockJobSyncOrchestratorService mockOrchestratorService;
  late JobSyncTriggerService service;
  late MockJobRepository mockJobRepository;
  late MockTimer mockTimer; // Mock timer instance
  late Function(Timer) capturedCallback; // Make nullable
  late TimerFactory mockTimerFactory; // Mock factory function
  const syncInterval = Duration(seconds: 15);

  setUp(() {
    // Remove orchestrator mock setup
    // mockOrchestratorService = MockJobSyncOrchestratorService();
    mockJobRepository = MockJobRepository();
    mockTimer = MockTimer();

    // Set up logging to capture logs
    LoggerFactory.clearLogs();
    LoggerFactory.setLogLevel(JobSyncTriggerService, Level.debug);

    // Define the mock factory WITHOUT the expect inside
    mockTimerFactory = (Duration duration, Function(Timer) callback) {
      capturedCallback = callback;
      // DO NOT expect() here - causes issues with test framework timing
      return mockTimer;
    };

    // Instantiate service correctly
    service = JobSyncTriggerService(
      jobRepository: mockJobRepository,
      syncInterval: syncInterval,
      timerFactory: mockTimerFactory, // Inject the mock factory
    );

    // Ensure repository mock setup uses thenAnswer for async
    when(
      mockJobRepository.syncPendingJobs(),
    ).thenAnswer((_) async => const Right(unit));

    // NEW: Mock the reconcileJobsWithServer method
    when(
      mockJobRepository.reconcileJobsWithServer(),
    ).thenAnswer((_) async => const Right(unit));

    // Default stub for mock timer
    when(mockTimer.cancel()).thenReturn(null);
    when(mockTimer.isActive).thenReturn(false);
  });

  tearDown(() {
    service.dispose();
  });

  // --- Group: Lifecycle Tests ---
  group('Lifecycle Tests', () {
    test('init should add observer and set initialization flag', () {
      // Act
      service.init();

      // Assert - Check logs to confirm observer added
      expect(
        LoggerFactory.containsLog('Initializing and adding observer'),
        isTrue,
      );
    });

    test('init should not add observer if already initialized', () {
      // Arrange
      service.init();
      LoggerFactory.clearLogs();

      // Act
      service.init();

      // Assert - No new logs for initialization
      expect(
        LoggerFactory.containsLog('Initializing and adding observer'),
        isFalse,
      );
    });

    test(
      'didChangeAppLifecycleState should trigger both sync methods on resumed IN ORDER',
      () async {
        // Arrange
        service.init();
        LoggerFactory.clearLogs();

        // Preconditions: mark first frame & authentication
        service.onFirstFrameDisplayed();
        service.onAuthenticated();

        // Clear previous interactions before we trigger the lifecycle event
        clearInteractions(mockJobRepository);

        // Act
        service.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future.delayed(
          Duration.zero,
        ); // Allow async operations to complete

        // Assert
        // Verify calls happen in the correct order
        verifyInOrder([
          mockJobRepository.syncPendingJobs(),
          mockJobRepository.reconcileJobsWithServer(),
        ]);
        expect(
          LoggerFactory.containsLog(
            'App resumed – attempting to (re)start timer',
          ),
          isTrue,
        );
      },
    );

    test('didChangeAppLifecycleState should stop timer on paused', () {
      // Arrange
      service.init();
      service.startTimer(); // Ensure _timer is assigned
      when(mockTimer.isActive).thenReturn(true); // Now set the state

      // Act
      LoggerFactory.clearLogs(); // Clear logs RIGHT BEFORE the action
      service.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Assert
      verify(mockTimer.cancel()).called(1); // Verify the core logic first
      // Check the specific log AFTER the action
      expect(
        LoggerFactory.containsLog(
          'App not resumed (AppLifecycleState.paused). Stopping sync timer',
        ),
        isTrue,
        reason: 'Expected log message for paused state not found after action.',
      );
    });

    test('didChangeAppLifecycleState should do nothing if not initialized', () {
      // Act - Call without initializing
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Assert
      verifyNever(mockJobRepository.syncPendingJobs());
    });
  });

  // --- Group: Timer Control ---
  group('Timer Control', () {
    setUp(() {
      // Initialize service before timer tests
      service.init();
      LoggerFactory.clearLogs();
    });

    test('startTimer should stop existing timer and create new one', () {
      // Arrange
      // Simulate an existing timer being active FIRST
      service.startTimer(); // Assigns the first mockTimer to _timer
      when(mockTimer.isActive).thenReturn(true); // Make it active
      clearInteractions(
        mockTimer,
      ); // Clear interactions from the first startTimer call

      // Create a new mock timer for the *second* call
      final newMockTimer = MockTimer();
      when(
        newMockTimer.isActive,
      ).thenReturn(false); // The new timer isn't active initially
      when(newMockTimer.cancel()).thenReturn(null);

      // Adjust the factory to return the *new* timer on the next call
      mockTimerFactory = (duration, callback) {
        capturedCallback = callback;
        return newMockTimer; // Return the *second* timer instance
      };
      // Re-inject the updated factory (or rebuild the service if easier, but this works)
      // No need to rebuild service if factory is mutable like this, but keep in mind for complex cases.

      // Act
      service
          .startTimer(); // This should now call stopTimer (on the *first* mockTimer) then create the new one

      // Assert
      // Verify cancel was called on the *original* mockTimer
      verify(mockTimer.cancel()).called(1);
      expect(
        LoggerFactory.containsLog('Starting sync timer with interval'),
        isTrue,
      );
      // Optionally verify the new timer wasn't cancelled
      verifyNever(newMockTimer.cancel());
    });

    test('stopTimer should cancel timer if active', () {
      // Arrange
      service.startTimer(); // Ensure _timer is assigned
      when(mockTimer.isActive).thenReturn(true); // Make it active

      // Act
      service.stopTimer();

      // Assert
      verify(mockTimer.cancel()).called(1);
      expect(LoggerFactory.containsLog('Stopping sync timer'), isTrue);
    });

    test('stopTimer should do nothing if timer not active', () {
      // Arrange
      when(mockTimer.isActive).thenReturn(false);

      // Act
      service.stopTimer();

      // Assert
      verifyNever(mockTimer.cancel());
    });

    test('timer callback should trigger both sync methods IN ORDER', () async {
      // Arrange - Start timer and capture callback
      service.startTimer();
      LoggerFactory.clearLogs();

      // Act - Simulate timer firing
      capturedCallback(mockTimer);
      await Future.delayed(Duration.zero); // Allow async operations

      // Assert
      // Verify calls happen in the correct order
      verifyInOrder([
        mockJobRepository.syncPendingJobs(),
        mockJobRepository.reconcileJobsWithServer(),
      ]);
    });

    test('timer callback should handle reconcile errors gracefully', () async {
      // Arrange
      when(
        mockJobRepository.reconcileJobsWithServer(),
      ).thenAnswer((_) => Future.error(Exception('Test reconcile error')));
      service.startTimer();
      LoggerFactory.clearLogs();

      // Act - Simulate timer firing with error
      capturedCallback(mockTimer);
      await Future.delayed(Duration.zero); // Allow async operations

      // Assert - Should log error but not crash
      expect(LoggerFactory.containsLog('Sync-Pull FAILURE:'), isTrue);
    });

    // NEW Test Case for Push Failure
    test(
      '_triggerSync should handle syncPendingJobs failure and still call reconcileJobsWithServer',
      () async {
        // Arrange
        when(
          mockJobRepository.syncPendingJobs(),
        ).thenThrow(Exception('Push error'));
        service.init();

        // Act - this would normally throw if not handled
        service.startTimer();
        capturedCallback(mockTimer);
        await Future.delayed(Duration.zero); // Let async complete

        // Assert - verify both methods were called despite the first one throwing
        verify(mockJobRepository.syncPendingJobs()).called(1);
        verify(mockJobRepository.reconcileJobsWithServer()).called(1);
        expect(LoggerFactory.containsLog('Sync-Push FAILURE:'), isTrue);
      },
    );

    test(
      '_triggerSync should handle reconcileJobsWithServer failure after successful push',
      () async {
        // Arrange
        when(
          mockJobRepository.syncPendingJobs(),
        ).thenAnswer((_) async => const Right(unit));
        when(
          mockJobRepository.reconcileJobsWithServer(),
        ).thenAnswer((_) async => Left(ServerFailure()));
        service.init();

        // Act
        service.startTimer();
        capturedCallback(mockTimer);
        await Future.delayed(Duration.zero); // Let async complete

        // Assert
        // Verify the methods were called in order
        verifyInOrder([
          mockJobRepository.syncPendingJobs(),
          mockJobRepository.reconcileJobsWithServer(),
        ]);

        // Verify push success and pull failure logs
        expect(LoggerFactory.containsLog('Sync-Push OK'), isTrue);
        expect(LoggerFactory.containsLog('Sync-Pull FAILURE:'), isTrue);
      },
    );
  });

  // --- Group: Dispose Tests ---
  group('Dispose', () {
    test('dispose should remove observer and stop timer', () {
      // Arrange
      service.startTimer(); // Ensure _timer is assigned
      when(mockTimer.isActive).thenReturn(true); // Make it active

      // Act
      service.dispose();

      // Assert
      verify(mockTimer.cancel()).called(1);
      expect(LoggerFactory.containsLog('Disposing'), isTrue);
    });

    test('dispose should not cancel timer if not active', () {
      // Arrange
      service.startTimer(); // Ensure _timer is assigned
      when(mockTimer.isActive).thenReturn(false); // Ensure it's not active

      // Act
      service.dispose(); // This calls stopTimer internally

      // Assert
      verifyNever(mockTimer.cancel());
    });
  });
}

// Remove definitions for Right and unit if they come from dartz package
// class Right<R> { ... }
// const unit = null;
