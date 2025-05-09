// Import dartz with prefix to avoid conflicts with flutter's State
import 'dart:async';
import 'package:dartz/dartz.dart' as dartz;
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/delete_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_jobs_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/mappers/job_view_model_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Create a logger for test diagnostics
final Logger _testLogger = LoggerFactory.getLogger("CubitLifecycleTest");
final String _tag = logTag("CubitLifecycleTest");

// Using Mockito manually since this is a simple test
class MockWatchJobsUseCase extends Mock implements WatchJobsUseCase {
  @override
  Stream<dartz.Either<Failure, List<Job>>> call(NoParams params) {
    _testLogger.d(
      '$_tag MockWatchJobsUseCase.call() - returning empty stream with right value',
    );
    // Return an empty Right value stream to avoid errors
    return Stream.value(const dartz.Right<Failure, List<Job>>([]));
  }
}

class MockCreateJobUseCase extends Mock implements CreateJobUseCase {}

class MockJobViewModelMapper extends Mock implements JobViewModelMapper {}

// Manual mock for DeleteJobUseCase (no need for generated mock here)
class MockDeleteJobUseCase extends Mock implements DeleteJobUseCase {}

// Helper to track cubit creation
class CubitCreationTracker {
  static int creationCount = 0;
  static JobListCubit? lastCreatedCubit;

  static void reset() {
    _testLogger.i('$_tag Resetting tracker');
    creationCount = 0;
    lastCreatedCubit = null;
  }

  static JobListCubit trackCreation(JobListCubit cubit) {
    creationCount++;
    lastCreatedCubit = cubit;
    _testLogger.i('$_tag Created cubit #$creationCount: ${cubit.hashCode}');
    return cubit;
  }
}

// This widget now directly creates the cubit in its build method
// simulating the problematic pattern
class ProblematicCubitCreationWidget extends StatelessWidget {
  final JobListCubit Function() createCubit;

  const ProblematicCubitCreationWidget({required this.createCubit, super.key});

  @override
  Widget build(BuildContext context) {
    _testLogger.i(
      '$_tag ProblematicCubitCreationWidget.build() called (hashCode: $hashCode)',
    );
    // Directly create the cubit here, potentially on every build
    _testLogger.i(
      '$_tag Calling createCubit from ProblematicCubitCreationWidget.build',
    );
    final cubit = CubitCreationTracker.trackCreation(createCubit());
    _testLogger.i(
      '$_tag Cubit created in ProblematicCubitCreationWidget.build, hash: ${cubit.hashCode}',
    );

    // Use the cubit in a dummy way just to consume it
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Cubit hash: ${cubit.hashCode}'),
            const Text('JobListPage Content'),
          ],
        ),
      ),
    );
  }
}

// Simple wrapper to force a rebuild, now builds its child dynamically
class RebuildWrapper extends StatefulWidget {
  final Widget Function(int) childBuilder;
  final VoidCallback onRebuild;

  const RebuildWrapper({
    required this.childBuilder,
    required this.onRebuild,
    super.key,
  });

  @override
  State<RebuildWrapper> createState() => _RebuildWrapperState();
}

class _RebuildWrapperState extends State<RebuildWrapper> {
  int counter = 0;

  void incrementCounter() {
    _testLogger.i('$_tag RebuildWrapper: incrementCounter called');
    setState(() {
      _testLogger.i('$_tag RebuildWrapper: setState called');
      counter++;
    });
    _testLogger.i('$_tag RebuildWrapper: calling onRebuild callback');
    widget.onRebuild();
  }

  @override
  Widget build(BuildContext context) {
    _testLogger.d(
      '$_tag Building RebuildWrapper (State: $hashCode) with counter: $counter',
    );
    // Build the child dynamically based on the counter
    final child = widget.childBuilder(counter);
    _testLogger.d(
      '$_tag RebuildWrapper: Child built dynamically, hash: ${child.hashCode}',
    );

    return Column(
      children: [
        ElevatedButton(
          onPressed: incrementCounter,
          child: const Text('Rebuild'),
        ),
        Text('Counter: $counter'),
        Expanded(child: child),
      ],
    );
  }
}

// Helper function to create a test app with all required dependencies
Widget createTestApp({
  required WatchJobsUseCase watchJobsUseCase,
  required JobViewModelMapper mapper,
  required CreateJobUseCase createJobUseCase,
  required DeleteJobUseCase deleteJobUseCase,
}) {
  _testLogger.i('$_tag Creating test app with provided dependencies');
  return ProviderScope(
    child: MaterialApp(
      home: BlocProvider<JobListCubit>(
        create:
            (_) => JobListCubit(
              watchJobsUseCase: watchJobsUseCase,
              mapper: mapper,
              createJobUseCase: createJobUseCase,
              deleteJobUseCase: deleteJobUseCase,
            ),
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    ),
  );
}

void main() {
  group('JobListPage Cubit Lifecycle', () {
    late MockWatchJobsUseCase mockWatchJobsUseCase;
    late MockCreateJobUseCase mockCreateJobUseCase;
    late MockJobViewModelMapper mockMapper;
    late MockDeleteJobUseCase mockDeleteJobUseCase;

    setUp(() {
      _testLogger.i('$_tag Test setup starting');
      // Reset tracker before each test
      CubitCreationTracker.reset();

      // Create mocks
      mockWatchJobsUseCase = MockWatchJobsUseCase();
      mockCreateJobUseCase = MockCreateJobUseCase();
      mockMapper = MockJobViewModelMapper();
      mockDeleteJobUseCase = MockDeleteJobUseCase();

      _testLogger.i('$_tag Test setup complete');
    });

    testWidgets('Cubit is recreated on every rebuild', (
      WidgetTester tester,
    ) async {
      _testLogger.i('$_tag Starting test');

      // Create our cubit factory function
      JobListCubit createTestCubit() {
        _testLogger.i('$_tag Factory function createTestCubit() called');
        return JobListCubit(
          watchJobsUseCase: mockWatchJobsUseCase,
          mapper: mockMapper,
          createJobUseCase: mockCreateJobUseCase,
          deleteJobUseCase: mockDeleteJobUseCase,
        );
      }

      bool rebuildTriggered = false;

      // Build our test app using the childBuilder
      _testLogger.i('$_tag Pumping initial widget using childBuilder');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RebuildWrapper(
              onRebuild: () {
                _testLogger.i('$_tag Rebuild callback executed');
                rebuildTriggered = true;
              },
              // Pass the builder function for the child
              childBuilder: (counter) {
                _testLogger.i(
                  '$_tag RebuildWrapper childBuilder called (counter: $counter)',
                );
                return ProblematicCubitCreationWidget(
                  createCubit: createTestCubit,
                );
              },
            ),
          ),
        ),
      );
      _testLogger.i('$_tag Initial widget pumped');

      // Verify initial cubit creation
      _testLogger.i('$_tag Verifying initial cubit creation');
      expect(
        CubitCreationTracker.creationCount,
        1,
        reason: 'Should create cubit once for initial build',
      );
      final initialCubit = CubitCreationTracker.lastCreatedCubit;
      expect(initialCubit, isNotNull);
      _testLogger.i('$_tag Initial cubit verification complete');

      // Force a rebuild by tapping the button
      _testLogger.i('$_tag Tapping rebuild button');
      await tester.tap(find.text('Rebuild'));
      _testLogger.i('$_tag Pumping after tap');
      await tester.pump();
      _testLogger.i('$_tag Pump after tap complete');

      // Verify the rebuild triggered
      _testLogger.i('$_tag Verifying rebuild was triggered');
      expect(
        rebuildTriggered,
        isTrue,
        reason: 'Rebuild should have been triggered',
      );
      _testLogger.i('$_tag Rebuild verification complete');

      // Check if a new cubit was created
      _testLogger.i(
        '$_tag Checking if new cubit was created (Current count: ${CubitCreationTracker.creationCount})',
      );
      expect(
        CubitCreationTracker.creationCount,
        2,
        reason: 'Should create a new cubit on rebuild',
      );
      _testLogger.i('$_tag Cubit count verification complete');

      // Verify it's a different instance
      _testLogger.i('$_tag Verifying cubit instances are different');
      final secondCubit = CubitCreationTracker.lastCreatedCubit;
      expect(
        identical(initialCubit, secondCubit),
        isFalse,
        reason: 'Should not be the same cubit instance after rebuild',
      );
      _testLogger.i('$_tag Cubit instance verification complete');
      _testLogger.i('$_tag Test completed successfully');

      // Properly clean up resources
      _testLogger.i('$_tag Closing cubits');
      await initialCubit?.close();
      await secondCubit?.close();
      _testLogger.i('$_tag Cubits closed');
    });

    // TODO: Fix this test - it has issues with the mock setup
    /*testWidgets(
       'JobListCubit initializes correctly with Loading state and listens to job stream',
       (tester) async {
         final mockWatchStreamController =
             StreamController<dartz.Either<Failure, List<Job>>>();

         // Set up mock behavior - MockWatchJobsUseCase already has its own implementation
         // that returns a mock stream, so we don't need to use when()
         // Just create the widget and pump it

         // Build our app and trigger a frame
         await tester.pumpWidget(createTestApp(
           watchJobsUseCase: mockWatchJobsUseCase,
           mapper: mockMapper,
           createJobUseCase: mockCreateJobUseCase,
           deleteJobUseCase: mockDeleteJobUseCase,
         ));

         // Verify initial state is Loading
         expect(find.byType(CircularProgressIndicator), findsOneWidget);

         // Verify appropriate mocks were called
         verify(mockWatchJobsUseCase.call(NoParams())).called(1);
         // ... rest of the test ...
       },
     );*/
  });
}
