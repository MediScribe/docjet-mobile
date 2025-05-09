import 'dart:async';

import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_auth_gate.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_trigger_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate a mock for JobSyncTriggerService
@GenerateMocks([JobSyncTriggerService])
import 'job_sync_trigger_service_auth_gate_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<AuthEvent> authController;
  late MockJobSyncTriggerService mockSyncService;
  late JobSyncAuthGate authGate;

  setUp(() {
    authController = StreamController<AuthEvent>.broadcast();
    mockSyncService = MockJobSyncTriggerService();

    // Stub methods we expect to call / not call
    when(mockSyncService.init()).thenReturn(null);
    when(mockSyncService.startTimer()).thenReturn(null);
    when(mockSyncService.dispose()).thenReturn(null);

    authGate = JobSyncAuthGate(
      authStream: authController.stream,
      syncService: mockSyncService,
    );
    // Simulate DI ready immediately for unit tests
    authGate.markDiReady();
  });

  tearDown(() async {
    await authGate.dispose();
    await authController.close();
  });

  group('JobSyncAuthGate', () {
    test('does not initialize or start timer before loggedIn', () async {
      // No auth events yet -> gate should stay dormant
      await Future.delayed(Duration.zero);

      verifyNever(mockSyncService.init());
      verifyNever(mockSyncService.startTimer());
    });

    test('initializes and starts timer on loggedIn/authenticated', () async {
      // Emit loggedIn event
      authController.add(AuthEvent.loggedIn);
      await Future.delayed(Duration.zero);

      verify(mockSyncService.init()).called(1);
      verify(mockSyncService.startTimer()).called(1);
    });

    test('disposes sync service on loggedOut event', () async {
      // Emit loggedIn first to initialize service
      authController.add(AuthEvent.loggedIn);
      await Future.delayed(Duration.zero);
      clearInteractions(mockSyncService);

      // Emit loggedOut
      authController.add(AuthEvent.loggedOut);
      await Future.delayed(Duration.zero);

      verify(mockSyncService.dispose()).called(1);
    });

    test('queued loggedIn before DI ready starts after ready', () async {
      // Use a fresh stream controller to avoid interference from setUp gate.
      final localController = StreamController<AuthEvent>.broadcast();
      final gate = JobSyncAuthGate(
        authStream: localController.stream,
        syncService: mockSyncService,
      );

      // Emit loggedIn BEFORE DI ready
      localController.add(AuthEvent.loggedIn);
      await Future.delayed(Duration.zero);

      // Should not start yet
      verifyNever(mockSyncService.startTimer());

      // Now mark DI ready
      gate.markDiReady();
      await Future.delayed(Duration.zero);

      verify(mockSyncService.startTimer()).called(1);

      await localController.close();
    });
  });
}
