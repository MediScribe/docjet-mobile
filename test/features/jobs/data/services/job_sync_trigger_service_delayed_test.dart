import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_trigger_service.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_async/fake_async.dart';

// Generate mock for JobRepository to avoid hitting real implementation
@GenerateMocks([JobRepository])
import 'job_sync_trigger_service_delayed_test.mocks.dart';

class _StubTimer implements Timer {
  final void Function() _onCancel;
  bool _active = true;
  _StubTimer(this._onCancel);
  @override
  bool get isActive => _active;
  @override
  void cancel() {
    _active = false;
    _onCancel();
  }

  @override
  int get tick => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJobRepository mockRepo;
  late List<_StubTimer> createdTimers;
  late TimerFactory timerFactory;

  setUp(() {
    mockRepo = MockJobRepository();
    createdTimers = [];

    // Stub repository methods so they complete instantly
    when(mockRepo.syncPendingJobs()).thenAnswer((_) async => const Right(unit));
    when(
      mockRepo.reconcileJobsWithServer(),
    ).thenAnswer((_) async => const Right(unit));

    // Fake timer factory that records every created timer
    timerFactory = (duration, cb) {
      final t = _StubTimer(() {});
      createdTimers.add(t);
      return t;
    };
  });

  group('Deferred start logic', () {
    test(
      'should not start timer until both firstFrame and authenticated flags set',
      () {
        fakeAsync((async) {
          final service = JobSyncTriggerService(
            jobRepository: mockRepo,
            timerFactory: timerFactory,
          );
          service.init();

          // Only authenticated -> should NOT start timer
          service.onAuthenticated();
          async.elapse(const Duration(seconds: 60));
          expect(createdTimers.isEmpty, isTrue);

          // Only firstFrame -> still should NOT start timer
          service.onLoggedOut(); // reset auth
          service.onFirstFrameDisplayed();
          async.elapse(const Duration(seconds: 60));
          expect(createdTimers.isEmpty, isTrue);

          // Now set both flags -> timer should start exactly once
          service.onAuthenticated();
          async.elapse(const Duration(seconds: 1));
          expect(createdTimers.length, 1);
        });
      },
    );

    test(
      'initial sync is queued and executed once after both flags set',
      () async {
        fakeAsync((async) {
          final service = JobSyncTriggerService(
            jobRepository: mockRepo,
            timerFactory: timerFactory,
          );
          service.init();

          // Provide both flags
          service.onFirstFrameDisplayed();
          service.onAuthenticated();
          async.elapse(const Duration(milliseconds: 10));

          // Verify repository methods called exactly once during initial trigger
          verify(mockRepo.syncPendingJobs()).called(1);
          verify(mockRepo.reconcileJobsWithServer()).called(1);
        });
      },
    );
  });
}
