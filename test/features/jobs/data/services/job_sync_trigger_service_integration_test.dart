import 'dart:async';

import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_auth_gate.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_trigger_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_async/fake_async.dart';

@GenerateMocks([JobSyncTriggerService])
import 'job_sync_trigger_service_integration_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JobSyncAuthGate Integration', () {
    test(
      'cold-start unauthenticated then login triggers single timer start',
      () {
        fakeAsync((async) {
          final authController = StreamController<AuthEvent>.broadcast();
          final mockSyncService = MockJobSyncTriggerService();

          when(mockSyncService.init()).thenReturn(null);
          when(mockSyncService.startTimer()).thenReturn(null);

          final gate = JobSyncAuthGate(
            syncService: mockSyncService,
            authStream: authController.stream,
          );
          gate.markDiReady();

          // Simulate cold start where user is unauthenticated
          authController.add(AuthEvent.loggedOut);
          async.elapse(const Duration(milliseconds: 10));

          verifyNever(mockSyncService.startTimer());

          // Now user logs in
          authController.add(AuthEvent.loggedIn);
          async.elapse(const Duration(milliseconds: 10));

          verify(mockSyncService.startTimer()).called(1);
          verify(mockSyncService.init()).called(1);

          // Clean up
          gate.dispose();
          authController.close();
        });
      },
    );
  });
}
