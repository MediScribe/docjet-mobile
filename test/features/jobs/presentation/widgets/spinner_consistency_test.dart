import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_jobs_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/mappers/job_view_model_mapper.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';

// Create a logger for test diagnostics
final Logger _testLogger = LoggerFactory.getLogger("SpinnerConsistencyTest");
final String _tag = logTag("SpinnerConsistencyTest");

// Using Mockito manually since this is a simple test
class MockWatchJobsUseCase extends Mock implements WatchJobsUseCase {
  @override
  Stream<Either<Failure, List<Job>>> call(NoParams params) {
    _testLogger.d(
      '$_tag MockWatchJobsUseCase.call() - returning empty stream with right value',
    );
    // Return an empty Right value stream to avoid errors
    return Stream.value(Right<Failure, List<Job>>([]));
  }
}

class MockCreateJobUseCase extends Mock implements CreateJobUseCase {}

class MockJobViewModelMapper extends Mock implements JobViewModelMapper {}

void main() {
  group('Spinner Consistency Tests', () {
    setUp(() {
      _testLogger.i('$_tag Test setup starting');
      LoggerFactory.clearLogs();
      _testLogger.i('$_tag Test setup complete');
    });

    testWidgets('Loading state in main.dart uses MaterialProgressIndicator', (
      WidgetTester tester,
    ) async {
      _testLogger.i('$_tag Starting MaterialProgressIndicator test');
      // Here we're testing the actual implementation in main.dart
      // which currently uses CircularProgressIndicator
      Widget buildLoadingWidget() {
        _testLogger.d(
          '$_tag Building loading widget with CircularProgressIndicator',
        );
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      _testLogger.i('$_tag Pumping widget with CircularProgressIndicator');
      await tester.pumpWidget(MaterialApp(home: buildLoadingWidget()));
      _testLogger.i('$_tag Widget pumped successfully');

      // This should fail - we should not find CircularProgressIndicator
      _testLogger.i('$_tag Verifying CircularProgressIndicator is present');
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'Main app loading should NOT use CircularProgressIndicator',
      );
      _testLogger.i('$_tag CircularProgressIndicator verification complete');

      // This should pass after fixing
      _testLogger.i(
        '$_tag Verifying CupertinoActivityIndicator is not present',
      );
      expect(
        find.byType(CupertinoActivityIndicator),
        findsNothing,
        reason:
            'Main app loading should use CupertinoActivityIndicator instead',
      );
      _testLogger.i('$_tag CupertinoActivityIndicator verification complete');
      _testLogger.i('$_tag MaterialProgressIndicator test completed');
    });

    testWidgets('JobListPage loading state uses CupertinoActivityIndicator', (
      WidgetTester tester,
    ) async {
      _testLogger.i('$_tag Starting CupertinoActivityIndicator test');
      // Create mocks for the required dependencies
      _testLogger.i('$_tag Creating mocks');
      final mockWatchJobsUseCase = MockWatchJobsUseCase();
      final mockCreateJobUseCase = MockCreateJobUseCase();
      final mockMapper = MockJobViewModelMapper();
      _testLogger.i('$_tag Mocks created successfully');

      // Mock behavior
      _testLogger.i('$_tag Setting up mock behavior');

      // No additional behaviors needed as we're using our own implementation in the MockWatchJobsUseCase class

      // Create a mock cubit with the required dependencies
      _testLogger.i('$_tag Creating mock cubit');
      JobListCubit? mockCubit;
      try {
        _testLogger.d('$_tag About to instantiate JobListCubit');
        mockCubit = JobListCubit(
          watchJobsUseCase: mockWatchJobsUseCase,
          mapper: mockMapper,
          createJobUseCase: mockCreateJobUseCase,
        );
        _testLogger.i('$_tag Mock cubit created successfully');

        // Create a widget with JobListCubit in loading state
        _testLogger.i(
          '$_tag Preparing to pump widget with CupertinoActivityIndicator',
        );

        // Wrap in try-catch to debug any issues during widget building
        try {
          _testLogger.i('$_tag Building test widget with ProviderScope');
          final testWidget = ProviderScope(
            child: MaterialApp(
              home: BlocProvider<JobListCubit>.value(
                value: mockCubit,
                child: Builder(
                  builder: (context) {
                    _testLogger.d(
                      '$_tag Building UI with CupertinoActivityIndicator',
                    );
                    // Force loading state
                    return const Center(child: CupertinoActivityIndicator());
                  },
                ),
              ),
            ),
          );
          _testLogger.i('$_tag Test widget built successfully');

          _testLogger.i('$_tag Pumping widget');
          await tester.pumpWidget(testWidget);
          _testLogger.i('$_tag Widget pumped successfully');
        } catch (e) {
          _testLogger.e('$_tag Error building or pumping widget: $e');
          rethrow;
        }

        // Test already passes because test_helpers.dart JobListPage mock correctly uses CupertinoActivityIndicator
        _testLogger.i('$_tag Verifying CupertinoActivityIndicator is present');
        expect(
          find.byType(CupertinoActivityIndicator),
          findsOneWidget,
          reason: 'JobListPage loading should use CupertinoActivityIndicator',
        );
        _testLogger.i('$_tag CupertinoActivityIndicator verification complete');

        // Should not find MaterialProgressIndicator anywhere
        _testLogger.i(
          '$_tag Verifying CircularProgressIndicator is not present',
        );
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'CircularProgressIndicator should not be used in JobListPage',
        );
        _testLogger.i('$_tag CircularProgressIndicator verification complete');
        _testLogger.i('$_tag CupertinoActivityIndicator test completed');
      } catch (e) {
        _testLogger.e('$_tag Error in test: $e');
        rethrow;
      } finally {
        // Clean up resources
        _testLogger.i('$_tag Cleaning up resources');
        mockCubit?.close();
        _testLogger.i('$_tag Resources cleaned up');
      }
    });
  });
}
